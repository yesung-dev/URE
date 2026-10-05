import Foundation
import XCTest
@testable import URE

final class RenameFlowTests: XCTestCase {
    private var root: URL!
    private let scanner = FileScanner()
    private let renamer = RenameManager()

    override func setUpWithError() throws {
        try super.setUpWithError()
        root = FileManager.default.temporaryDirectory.appendingPathComponent(
            "URETests-\(UUID().uuidString)",
            isDirectory: true
        )
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let root {
            try? FileManager.default.removeItem(at: root)
        }
        root = nil
        try super.tearDownWithError()
    }

    func testNestedFoldersAreRenamedDeepestFirst() throws {
        let parent = "부모".decomposed()
        let child = "자식".decomposed()
        let file = "메모".decomposed() + ".txt"
        let parentURL = root.appendingPathComponent(parent, isDirectory: true)
        let childURL = parentURL.appendingPathComponent(child, isDirectory: true)
        try FileManager.default.createDirectory(at: childURL, withIntermediateDirectories: true)
        let contents = Data("nested".utf8)
        try contents.write(to: childURL.appendingPathComponent(file))

        let outcome = scanner.scan(roots: [root])
        let batch = renamer.perform(items: outcome.items)
        XCTAssertEqual(batch.operations.count, 3)
        XCTAssertTrue(batch.results.filter { $0.status == .renamed }.count == 3)

        let renamedParent = try XCTUnwrap(storedNames(in: root).first { $0.unicodeScalars.elementsEqual("부모".precomposed().unicodeScalars) })
        let renamedChildDir = root.appendingPathComponent(renamedParent, isDirectory: true)
        let renamedChild = try XCTUnwrap(storedNames(in: renamedChildDir).first { $0.unicodeScalars.elementsEqual("자식".precomposed().unicodeScalars) })
        let fileDir = renamedChildDir.appendingPathComponent(renamedChild, isDirectory: true)
        let renamedFile = try XCTUnwrap(storedNames(in: fileDir).first { $0.hasSuffix(".txt") })
        XCTAssertTrue(renamedFile.unicodeScalars.elementsEqual(("메모".precomposed() + ".txt").unicodeScalars))
        XCTAssertEqual(try Data(contentsOf: fileDir.appendingPathComponent(renamedFile)), contents)

        let undone = renamer.undo(operations: batch.operations)
        XCTAssertNil(undone.failure)
        XCTAssertEqual(undone.undoneCount, 3)
        let restoredParent = try XCTUnwrap(storedNames(in: root).first { $0.unicodeScalars.elementsEqual(parent.unicodeScalars) })
        let restoredChildDir = root.appendingPathComponent(restoredParent, isDirectory: true)
        let restoredChild = try XCTUnwrap(storedNames(in: restoredChildDir).first { $0.unicodeScalars.elementsEqual(child.unicodeScalars) })
        let restoredFileDir = restoredChildDir.appendingPathComponent(restoredChild, isDirectory: true)
        let restoredFile = try XCTUnwrap(storedNames(in: restoredFileDir).first)
        XCTAssertTrue(restoredFile.unicodeScalars.elementsEqual(file.unicodeScalars))
        XCTAssertEqual(try Data(contentsOf: restoredFileDir.appendingPathComponent(restoredFile)), contents)
    }

    func testAppBundleContentsAreNotModified() throws {
        let bundleName = "응용".decomposed() + ".app"
        let inside = "안내".decomposed() + ".txt"
        let contents = root.appendingPathComponent(bundleName).appendingPathComponent("Contents", isDirectory: true)
        try FileManager.default.createDirectory(at: contents, withIntermediateDirectories: true)
        try Data("bundle".utf8).write(to: contents.appendingPathComponent(inside))

        let outcome = scanner.scan(roots: [root])
        XCTAssertEqual(outcome.appBundleCount, 1)
        XCTAssertFalse(outcome.items.contains { $0.originalName.unicodeScalars.elementsEqual(inside.unicodeScalars) })

        let batch = renamer.perform(items: outcome.items)
        XCTAssertEqual(batch.operations.count, 1)
        let renamedBundle = try XCTUnwrap(storedNames(in: root).first { $0.hasSuffix(".app") })
        XCTAssertTrue(renamedBundle.unicodeScalars.elementsEqual(("응용".precomposed() + ".app").unicodeScalars))

        let storedInside = try XCTUnwrap(
            storedNames(in: root.appendingPathComponent(renamedBundle).appendingPathComponent("Contents")).first
        )
        XCTAssertTrue(storedInside.unicodeScalars.elementsEqual(inside.unicodeScalars))
    }

    func testSymbolicLinksAreSkippedAndTargetsStayUntouched() throws {
        let outside = root.appendingPathComponent("outside", isDirectory: true)
        try FileManager.default.createDirectory(at: outside, withIntermediateDirectories: true)
        let outsideName = "외부".decomposed() + ".txt"
        let outsideFile = outside.appendingPathComponent(outsideName)
        try Data("keep".utf8).write(to: outsideFile)

        let folder = root.appendingPathComponent("inbox", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let link = folder.appendingPathComponent("link-to-outside")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: outside)

        let linkedDirectory = outside.appendingPathComponent("linked-dir", isDirectory: true)
        try FileManager.default.createDirectory(at: linkedDirectory, withIntermediateDirectories: true)
        try Data("secret".utf8).write(to: linkedDirectory.appendingPathComponent("숨김".decomposed() + ".txt"))
        try FileManager.default.createSymbolicLink(
            at: folder.appendingPathComponent("dir-link"),
            withDestinationURL: linkedDirectory
        )

        let outcome = scanner.scan(roots: [folder])
        XCTAssertEqual(outcome.items.filter { $0.kind == .symlink }.count, 2)
        XCTAssertFalse(outcome.items.contains { $0.relativePath.contains("숨김") || $0.originalName.hasPrefix("숨김") })

        let batch = renamer.perform(items: outcome.items)
        XCTAssertTrue(batch.operations.isEmpty)
        XCTAssertEqual(batch.results.filter { $0.status == .skippedSymlink }.count, 2)
        let stillOutside = try XCTUnwrap(storedNames(in: outside).first { $0.hasSuffix(".txt") })
        XCTAssertTrue(stillOutside.unicodeScalars.elementsEqual(outsideName.unicodeScalars))
        XCTAssertEqual(try String(contentsOf: outsideFile, encoding: .utf8), "keep")
    }

    func testNameCollisionDoesNotOverwrite() throws {
        let directory = root.appendingPathComponent("box", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data("KEEP".utf8).write(to: directory.appendingPathComponent("taken.txt"))
        try Data("SOURCE".utf8).write(to: directory.appendingPathComponent("other.txt"))
        let sourceInode = try inode(of: directory.appendingPathComponent("other.txt"))

        let item = ScanItem(
            parentPath: directory.path,
            originalName: "other.txt",
            proposedName: "taken.txt",
            relativePath: "other.txt",
            kind: .file,
            needsNormalization: true,
            depth: 2
        )
        let batch = renamer.perform(items: [item])
        XCTAssertEqual(batch.results.first?.status, .failed(.collision))
        XCTAssertTrue(batch.operations.isEmpty)
        XCTAssertEqual(try String(contentsOf: directory.appendingPathComponent("taken.txt"), encoding: .utf8), "KEEP")
        XCTAssertEqual(try String(contentsOf: directory.appendingPathComponent("other.txt"), encoding: .utf8), "SOURCE")
        XCTAssertEqual(try inode(of: directory.appendingPathComponent("other.txt")), sourceInode)
    }

    func testTwoStepRenameRollsBackWhenDestinationExists() throws {
        let directory = root.appendingPathComponent("rollback", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data("KEEP".utf8).write(to: directory.appendingPathComponent("taken.txt"))
        try Data("SOURCE".utf8).write(to: directory.appendingPathComponent("other.txt"))

        XCTAssertThrowsError(
            try renamer.performExclusiveTwoStepRename(
                parentPath: directory.path,
                from: "other.txt",
                to: "taken.txt"
            )
        ) { error in
            XCTAssertEqual(error as? RenameFailure, .collision)
        }

        XCTAssertEqual(try String(contentsOf: directory.appendingPathComponent("taken.txt"), encoding: .utf8), "KEEP")
        XCTAssertEqual(try String(contentsOf: directory.appendingPathComponent("other.txt"), encoding: .utf8), "SOURCE")
        XCTAssertFalse(storedNames(in: directory).contains { $0.hasPrefix(".ure-temp-") })
    }

    func testMixedFilesOnlyRenameWhatNeedsNFC() throws {
        let folder = root.appendingPathComponent("mixed", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let nfd = "그림".decomposed() + ".png"
        try Data("image".utf8).write(to: folder.appendingPathComponent(nfd))
        try Data("plain".utf8).write(to: folder.appendingPathComponent("readme.txt"))
        try Data("digits".utf8).write(to: folder.appendingPathComponent("01-notes.txt"))

        let outcome = scanner.scan(roots: [folder])
        let batch = renamer.perform(items: outcome.items)
        XCTAssertEqual(batch.operations.count, 1)
        XCTAssertEqual(batch.results.filter { $0.status == .unchanged }.count, 3)
        XCTAssertEqual(batch.results.filter { $0.status == .renamed }.count, 1)

        let names = storedNames(in: folder)
        XCTAssertTrue(names.contains { $0.unicodeScalars.elementsEqual(("그림".precomposed() + ".png").unicodeScalars) })
        XCTAssertTrue(names.contains("readme.txt"))
        XCTAssertTrue(names.contains("01-notes.txt"))
        XCTAssertEqual(try String(contentsOf: folder.appendingPathComponent("그림".precomposed() + ".png"), encoding: .utf8), "image")
    }

    func testRenameFailureLeavesTheFileInPlace() throws {
        let locked = root.appendingPathComponent("locked", isDirectory: true)
        try FileManager.default.createDirectory(at: locked, withIntermediateDirectories: true)
        let nfd = "잠금".decomposed() + ".txt"
        try Data("safe".utf8).write(to: locked.appendingPathComponent(nfd))
        try FileManager.default.setAttributes([.posixPermissions: 0o555], ofItemAtPath: locked.path)
        defer {
            try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: locked.path)
        }

        let outcome = scanner.scan(roots: [locked])
        let batch = renamer.perform(items: outcome.items.filter { $0.originalName != "locked" && $0.kind == .file })
        XCTAssertEqual(batch.results.first?.status, .failed(.permission))
        XCTAssertTrue(batch.operations.isEmpty)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: locked.path)
        let remaining = try XCTUnwrap(storedNames(in: locked).first)
        XCTAssertTrue(remaining.unicodeScalars.elementsEqual(nfd.unicodeScalars))
        XCTAssertEqual(try String(contentsOf: locked.appendingPathComponent(remaining), encoding: .utf8), "safe")
    }

    func testUndoRestoresOriginalBytesWithoutOverwritingAConflict() throws {
        let folder = root.appendingPathComponent("undo", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let nfd = "복원".decomposed() + ".txt"
        try Data("body".utf8).write(to: folder.appendingPathComponent(nfd))
        let before = try inode(of: folder.appendingPathComponent(nfd))

        let outcome = scanner.scan(roots: [folder])
        let batch = renamer.perform(items: outcome.items)
        XCTAssertEqual(batch.operations.count, 1)
        let nfc = "복원".precomposed() + ".txt"
        XCTAssertTrue(storedNames(in: folder).contains { $0.unicodeScalars.elementsEqual(nfc.unicodeScalars) })
        XCTAssertEqual(try inode(of: folder.appendingPathComponent(nfc)), before)

        let undone = renamer.undo(operations: batch.operations)
        XCTAssertNil(undone.failure)
        XCTAssertEqual(undone.undoneCount, 1)
        XCTAssertTrue(undone.remaining.isEmpty)
        let restored = try XCTUnwrap(storedNames(in: folder).first)
        XCTAssertTrue(restored.unicodeScalars.elementsEqual(nfd.unicodeScalars))
        XCTAssertEqual(try String(contentsOf: folder.appendingPathComponent(restored), encoding: .utf8), "body")
        XCTAssertEqual(try inode(of: folder.appendingPathComponent(restored)), before)

        try Data("KEEP".utf8).write(to: folder.appendingPathComponent("current.txt"))
        try Data("BLOCK".utf8).write(to: folder.appendingPathComponent("original.txt"))
        let blocked = renamer.undo(
            operations: [
                RenameOperation(parentPath: folder.path, originalName: "original.txt", renamedName: "current.txt")
            ]
        )
        XCTAssertEqual(blocked.failure, .collision)
        XCTAssertEqual(blocked.undoneCount, 0)
        XCTAssertEqual(try String(contentsOf: folder.appendingPathComponent("original.txt"), encoding: .utf8), "BLOCK")
        XCTAssertEqual(try String(contentsOf: folder.appendingPathComponent("current.txt"), encoding: .utf8), "KEEP")
    }
}

private extension String {
    func decomposed() -> String {
        decomposedStringWithCanonicalMapping
    }

    func precomposed() -> String {
        precomposedStringWithCanonicalMapping
    }
}

private func storedNames(in directory: URL) -> [String] {
    let urls = (try? FileManager.default.contentsOfDirectory(
        at: directory,
        includingPropertiesForKeys: [.nameKey],
        options: []
    )) ?? []
    return urls.compactMap { url in
        try? url.resourceValues(forKeys: [.nameKey]).name
    }
}

private func inode(of url: URL) throws -> UInt64 {
    guard case .found(let identity) = POSIXFileSystem.lookup(url.path) else {
        struct MissingFile: Error {}
        throw MissingFile()
    }
    return identity.inode
}

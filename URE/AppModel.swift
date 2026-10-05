import AppKit
import Foundation
import Observation
import os

@MainActor
@Observable
final class AppModel {
    enum Phase: Equatable {
        case ready
        case scanning
        case preview
        case renaming
        case undoing
        case result
    }

    private(set) var phase: Phase = .ready
    private(set) var items: [ScanItem] = []
    private(set) var results: [RenameResult] = []
    private(set) var operations: [RenameOperation] = []
    private(set) var progressCompleted = 0
    private(set) var progressTotal = 0
    private(set) var isDropTargeted = false
    private(set) var appBundleCount = 0
    private(set) var banner: String?
    private(set) var undoFailure: String?

    @ObservationIgnored private var accessedURLs: [URL] = []
    @ObservationIgnored private var workTask: Task<Void, Never>?
    @ObservationIgnored private var cancelFlag = CancelFlag()
    @ObservationIgnored private var generation = 0
    @ObservationIgnored private let scanner = FileScanner()
    @ObservationIgnored private let renamer = RenameManager()

    var pendingCount: Int {
        items.filter(\.willRename).count
    }

    var canUndo: Bool {
        phase == .result && !operations.isEmpty
    }

    var renamedCount: Int {
        results.filter { if case .renamed = $0.status { return true }; return false }.count
    }

    var unchangedCount: Int {
        results.filter { if case .unchanged = $0.status { return true }; return false }.count
    }

    var skippedCount: Int {
        results.filter { if case .skippedSymlink = $0.status { return true }; return false }.count
    }

    var failedCount: Int {
        results.filter(\.status.isFailure).count
    }

    var showsPermissionHint: Bool {
        results.contains { result in
            if case .failed(let failure) = result.status {
                return failure.isPermission
            }
            return false
        }
    }

    func setDropTargeted(_ targeted: Bool) {
        isDropTargeted = targeted
    }

    func chooseFiles() {
        guard acceptsFiles else { return }
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.canCreateDirectories = false
        panel.resolvesAliases = false
        panel.prompt = "선택"
        panel.message = "정규화할 파일 또는 폴더를 선택하세요."
        panel.begin { [weak self] response in
            guard response == .OK else { return }
            let urls = panel.urls
            let deliver = {
                self?.ingest(urls)
            }
            if Thread.isMainThread {
                MainActor.assumeIsolated(deliver)
            } else {
                DispatchQueue.main.sync {
                    MainActor.assumeIsolated(deliver)
                }
            }
        }
    }

    func ingest(_ urls: [URL]) {
        guard acceptsFiles else { return }
        let roots = unique(urls)
        guard !roots.isEmpty else { return }

        cancelFlag.cancel()
        workTask?.cancel()
        cancelFlag = CancelFlag()
        generation += 1
        let generation = generation
        endAccess()
        beginAccess(roots)

        items = []
        results = []
        operations = []
        banner = nil
        undoFailure = nil
        appBundleCount = 0
        progressCompleted = 0
        progressTotal = 0
        phase = .scanning

        let flag = cancelFlag
        workTask = Task { [scanner] in
            let outcome = await Task.detached(priority: .userInitiated) {
                scanner.scan(roots: roots, isCancelled: { flag.isCancelled }) { count in
                    Task { @MainActor in
                        guard generation == self.generation else { return }
                        self.progressCompleted = count
                    }
                }
            }.value
            guard !Task.isCancelled, !flag.isCancelled, generation == self.generation else {
                return
            }
            self.items = outcome.items
            self.appBundleCount = outcome.appBundleCount
            self.progressCompleted = outcome.items.count
            self.phase = .preview
        }
    }

    func renameSelected() {
        guard phase == .preview, pendingCount > 0 else { return }
        let snapshot = items
        phase = .renaming
        progressCompleted = 0
        progressTotal = snapshot.filter(\.willRename).count
        banner = nil
        generation += 1
        let generation = generation
        let flag = cancelFlag
        workTask = Task { [renamer] in
            var batch = await Self.perform(renamer, items: snapshot, flag: flag) { done, total in
                guard generation == self.generation else { return }
                self.progressCompleted = done
                self.progressTotal = total
            }
            guard generation == self.generation else { return }

            let attempted = Set(snapshot.filter(\.willRename).map(\.id))
            let denied = batch.results.filter { result in
                attempted.contains(result.id) && result.isPermissionFailure
            }
            if !denied.isEmpty, !flag.isCancelled {
                let parents = Array(Set(denied.map(\.parentPath)))
                let granted = self.grantFolders(parents)
                if !granted.isEmpty {
                    self.beginAccess(granted, reset: false)
                    let retryItems = denied.map { $0.retryItem() }
                    let retried = await Self.perform(renamer, items: retryItems, flag: flag) { done, total in
                        guard generation == self.generation else { return }
                        self.progressCompleted = done
                        self.progressTotal = total
                    }
                    guard generation == self.generation else { return }
                    batch = batch.merging(retried)
                }
            }

            self.results = batch.results
            self.operations = batch.operations
            if flag.isCancelled {
                self.banner = "작업을 멈췄습니다. 이미 변경된 항목은 실행 취소할 수 있습니다."
            }
            self.phase = .result
        }
    }

    func undoLastRun() {
        guard canUndo else { return }
        let snapshot = operations
        phase = .undoing
        progressCompleted = 0
        progressTotal = snapshot.count
        undoFailure = nil
        generation += 1
        let generation = generation
        let flag = cancelFlag
        workTask = Task { [renamer] in
            let batch = await Task.detached(priority: .userInitiated) {
                renamer.undo(operations: snapshot, isCancelled: { flag.isCancelled }) { done, total in
                    Task { @MainActor in
                        guard generation == self.generation else { return }
                        self.progressCompleted = done
                        self.progressTotal = total
                    }
                }
            }.value
            guard generation == self.generation else { return }
            self.operations = batch.remaining
            if let failure = batch.failure {
                self.undoFailure = failure.message
                self.banner = "실행 취소를 멈췄습니다. \(failure.message)"
            } else if batch.remaining.isEmpty {
                self.banner = "실행 취소가 완료되었습니다."
                self.markUndone()
            } else {
                self.banner = "실행 취소를 멈췄습니다."
            }
            self.phase = .result
        }
    }

    func cancel() {
        switch phase {
        case .scanning:
            cancelFlag.cancel()
            workTask?.cancel()
            returnToReady()
        case .preview:
            returnToReady()
        case .renaming, .undoing:
            cancelFlag.cancel()
        case .ready, .result:
            break
        }
    }

    func returnToReady() {
        generation += 1
        workTask?.cancel()
        cancelFlag.cancel()
        endAccess()
        items = []
        results = []
        operations = []
        banner = nil
        undoFailure = nil
        appBundleCount = 0
        progressCompleted = 0
        progressTotal = 0
        phase = .ready
        isDropTargeted = false
    }

    var acceptsFiles: Bool {
        switch phase {
        case .ready, .preview, .result:
            true
        case .scanning, .renaming, .undoing:
            false
        }
    }

    private func markUndone() {
        results = results.map { result in
            guard case .renamed = result.status else { return result }
            return RenameResult(
                id: result.id,
                originalName: result.originalName,
                proposedName: result.proposedName,
                relativePath: result.relativePath,
                fullPath: result.fullPath,
                kind: result.kind,
                status: .unchanged,
                note: "실행 취소됨"
            )
        }
    }

    private func unique(_ urls: [URL]) -> [URL] {
        var seen = Set<[UInt8]>()
        var roots: [URL] = []
        for url in urls {
            let key = Array(url.path.utf8)
            if seen.insert(key).inserted {
                roots.append(url)
            }
        }
        return roots
    }

    /// Keeps user-selected files reachable through rename, including the parent folder.
    /// Rename has to create a temporary name beside the original, so file-only access is not enough.
    private func beginAccess(_ urls: [URL], reset: Bool = true) {
        if reset {
            endAccess()
        }
        var seen = Set<[UInt8]>()
        for url in urls {
            grant(url, seen: &seen)
            let parent = url.deletingLastPathComponent()
            if parent.path != url.path {
                grant(parent, seen: &seen)
            }
        }
    }

    private func grant(_ url: URL, seen: inout Set<[UInt8]>) {
        let key = Array(url.path.utf8)
        guard seen.insert(key).inserted else { return }
        if url.startAccessingSecurityScopedResource() {
            accessedURLs.append(url)
        }
        guard let bookmark = try? url.bookmarkData(
            options: .withSecurityScope,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        ) else { return }
        var stale = false
        guard let resolved = try? URL(
            resolvingBookmarkData: bookmark,
            options: .withSecurityScope,
            relativeTo: nil,
            bookmarkDataIsStale: &stale
        ) else { return }
        if resolved.startAccessingSecurityScopedResource() {
            accessedURLs.append(resolved)
        }
    }

    private func grantFolders(_ parents: [String]) -> [URL] {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        panel.canCreateDirectories = false
        panel.prompt = "허용"
        panel.message = "파일 이름을 바꾸려면 그 파일이 들어 있는 폴더 접근을 허용해야 합니다."
        if let first = parents.first {
            panel.directoryURL = URL(fileURLWithPath: first, isDirectory: true)
        }
        guard panel.runModal() == .OK else { return [] }
        return panel.urls
    }

    private func endAccess() {
        for url in accessedURLs {
            url.stopAccessingSecurityScopedResource()
        }
        accessedURLs.removeAll()
    }

    private static func perform(
        _ renamer: RenameManager,
        items: [ScanItem],
        flag: CancelFlag,
        progress: @escaping @MainActor (Int, Int) -> Void
    ) async -> RenameBatch {
        await Task.detached(priority: .userInitiated) {
            renamer.perform(items: items, isCancelled: { flag.isCancelled }) { done, total in
                Task { @MainActor in
                    progress(done, total)
                }
            }
        }.value
    }
}

nonisolated final class CancelFlag: @unchecked Sendable {
    private let lock = OSAllocatedUnfairLock(initialState: false)

    func cancel() {
        lock.withLock { $0 = true }
    }

    var isCancelled: Bool {
        lock.withLock { $0 }
    }
}

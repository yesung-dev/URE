import Foundation

nonisolated struct RenameBatch: Sendable, Equatable {
    var results: [RenameResult]
    var operations: [RenameOperation]
}

nonisolated struct UndoBatch: Sendable, Equatable {
    var undoneCount: Int
    var failure: RenameFailure?
    var remaining: [RenameOperation]
}

/// Renames filenames only. File contents are never opened for writing, and nothing is deleted.
nonisolated struct RenameManager: Sendable {
    private let maximumNameBytes = 255

    func perform(
        items: [ScanItem],
        isCancelled: @escaping @Sendable () -> Bool = { false },
        progress: @escaping @Sendable (Int, Int) -> Void = { _, _ in }
    ) -> RenameBatch {
        var results: [UUID: RenameResult] = [:]
        var operations: [RenameOperation] = []

        for item in items where !item.willRename {
            results[item.id] = result(for: item, status: statusForSkipped(item), note: item.listingWarning)
        }

        let pending = items
            .filter(\.willRename)
            .sorted { lhs, rhs in
                if lhs.depth != rhs.depth {
                    return lhs.depth > rhs.depth
                }
                return lhs.fullPath.utf8.lexicographicallyPrecedes(rhs.fullPath.utf8) == false
            }

        var claimed = Set<ClaimKey>()
        progress(0, pending.count)

        for (index, item) in pending.enumerated() {
            if isCancelled() {
                results[item.id] = result(for: item, status: .cancelled, note: item.listingWarning)
                for later in pending.dropFirst(index + 1) {
                    results[later.id] = result(for: later, status: .cancelled, note: later.listingWarning)
                }
                break
            }

            let claim = ClaimKey(parent: item.parentPath, name: item.proposedName)
            if claimed.contains(claim) {
                results[item.id] = result(for: item, status: .failed(.collision), note: item.listingWarning)
                progress(index + 1, pending.count)
                continue
            }
            claimed.insert(claim)

            do {
                try rename(parentPath: item.parentPath, from: item.originalName, to: item.proposedName)
                operations.append(
                    RenameOperation(
                        parentPath: item.parentPath,
                        originalName: item.originalName,
                        renamedName: item.proposedName
                    )
                )
                results[item.id] = result(for: item, status: .renamed, note: item.listingWarning)
            } catch let failure as RenameFailure {
                results[item.id] = result(for: item, status: .failed(failure), note: nil)
            } catch {
                results[item.id] = result(for: item, status: .failed(.other("변경하지 못했습니다.")), note: nil)
            }
            progress(index + 1, pending.count)
        }

        let ordered = items.map { item in
            results[item.id] ?? result(for: item, status: .failed(.other("변경하지 못했습니다.")), note: nil)
        }
        return RenameBatch(results: ordered, operations: operations)
    }

    func undo(
        operations: [RenameOperation],
        isCancelled: @escaping @Sendable () -> Bool = { false },
        progress: @escaping @Sendable (Int, Int) -> Void = { _, _ in }
    ) -> UndoBatch {
        var remaining = operations
        var undone = 0
        let total = operations.count
        progress(0, total)

        while let operation = remaining.last {
            if isCancelled() {
                break
            }
            do {
                try rename(
                    parentPath: operation.parentPath,
                    from: operation.renamedName,
                    to: operation.originalName
                )
                remaining.removeLast()
                undone += 1
                progress(undone, total)
            } catch let failure as RenameFailure {
                return UndoBatch(undoneCount: undone, failure: failure, remaining: remaining)
            } catch {
                return UndoBatch(
                    undoneCount: undone,
                    failure: .other("실행 취소에 실패했습니다."),
                    remaining: remaining
                )
            }
        }

        progress(undone, total)
        return UndoBatch(undoneCount: undone, failure: nil, remaining: remaining)
    }

    /// Two-step rename used by tests that need to observe rollback without the preflight short-circuit.
    func performExclusiveTwoStepRename(parentPath: String, from original: String, to proposed: String) throws {
        try commit(parentPath: parentPath, from: original, to: proposed)
    }

    private func rename(parentPath: String, from original: String, to proposed: String) throws {
        try preflight(parentPath: parentPath, from: original, to: proposed)
        try commit(parentPath: parentPath, from: original, to: proposed)
    }

    private func preflight(parentPath: String, from original: String, to proposed: String) throws {
        guard isSafeFileName(proposed) else {
            throw RenameFailure.invalidName
        }
        let source = PathJoiner.join(parentPath, original)
        let destination = PathJoiner.join(parentPath, proposed)

        let sourceIdentity: FileIdentity
        switch POSIXFileSystem.lookup(source) {
        case .found(let identity):
            if identity.isSymbolicLink {
                throw RenameFailure.other("심볼릭 링크는 변경하지 않습니다.")
            }
            sourceIdentity = identity
        case .missing:
            throw RenameFailure.missing
        case .failed(let code):
            throw POSIXFileSystem.failure(for: code)
        }

        switch POSIXFileSystem.lookup(destination) {
        case .missing:
            return
        case .failed(let code):
            throw POSIXFileSystem.failure(for: code)
        case .found(let destinationIdentity):
            let sameItem = destinationIdentity.device == sourceIdentity.device
                && destinationIdentity.inode == sourceIdentity.inode
            if !sameItem {
                throw RenameFailure.collision
            }
        }
    }

    private func commit(parentPath: String, from original: String, to proposed: String) throws {
        let source = PathJoiner.join(parentPath, original)
        let destination = PathJoiner.join(parentPath, proposed)
        let temporaryName = ".ure-temp-\(UUID().uuidString)"
        let temporary = PathJoiner.join(parentPath, temporaryName)

        if case .found = POSIXFileSystem.lookup(temporary) {
            throw RenameFailure.collision
        }

        do {
            try POSIXFileSystem.renameExclusively(from: source, to: temporary)
        } catch let error as POSIXRenameError {
            throw POSIXFileSystem.failure(for: error.code)
        }

        do {
            try POSIXFileSystem.renameExclusively(from: temporary, to: destination)
        } catch let error as POSIXRenameError {
            let mapped = POSIXFileSystem.failure(for: error.code)
            do {
                try POSIXFileSystem.renameExclusively(from: temporary, to: source)
            } catch {
                throw RenameFailure.stranded(path: temporary)
            }
            throw mapped
        }
    }

    private func isSafeFileName(_ name: String) -> Bool {
        !name.isEmpty
            && name != "."
            && name != ".."
            && !name.contains("/")
            && !name.contains("\0")
            && name.utf8.count <= maximumNameBytes
    }

    private func statusForSkipped(_ item: ScanItem) -> RenameStatus {
        if let accessError = item.accessError {
            return .failed(accessError)
        }
        if item.kind == .symlink {
            return .skippedSymlink
        }
        return .unchanged
    }

    private func result(for item: ScanItem, status: RenameStatus, note: String?) -> RenameResult {
        RenameResult(
            id: item.id,
            originalName: item.originalName,
            proposedName: item.proposedName,
            relativePath: item.relativePath,
            fullPath: item.fullPath,
            kind: item.kind,
            status: status,
            note: note
        )
    }
}

private nonisolated struct ClaimKey: Hashable {
    var parent: [UInt8]
    var name: [UInt8]

    init(parent: String, name: String) {
        self.parent = Array(parent.utf8)
        self.name = Array(name.utf8)
    }
}

import Foundation

/// Walks dropped files and folders without following symbolic links or entering `.app` bundles.
nonisolated struct FileScanner: Sendable {
    private let normalizer = FilenameNormalizer()

    func scan(
        roots: [URL],
        isCancelled: @escaping @Sendable () -> Bool = { false },
        progress: @escaping @Sendable (Int) -> Void = { _ in }
    ) -> ScanOutcome {
        var items: [ScanItem] = []
        var seen = Set<DirectoryEntryKey>()
        var appBundleCount = 0
        var discovered = 0

        for root in roots {
            if isCancelled() {
                break
            }
            scan(
                url: root,
                relativePath: nil,
                items: &items,
                seen: &seen,
                appBundleCount: &appBundleCount,
                discovered: &discovered,
                isCancelled: isCancelled,
                progress: progress
            )
        }

        progress(discovered)
        return ScanOutcome(items: items, appBundleCount: appBundleCount)
    }

    private func scan(
        url: URL,
        relativePath: String?,
        items: inout [ScanItem],
        seen: inout Set<DirectoryEntryKey>,
        appBundleCount: inout Int,
        discovered: inout Int,
        isCancelled: () -> Bool,
        progress: (Int) -> Void
    ) {
        if isCancelled() {
            return
        }

        let name = POSIXFileSystem.exactName(of: url)
        let parentPath = url.deletingLastPathComponent().path
        let fullPath = PathJoiner.join(parentPath, name)
        let depth = fullPath.split(separator: "/", omittingEmptySubsequences: true).count
        let relative = relativePath ?? name

        switch POSIXFileSystem.lookup(fullPath) {
        case .failed(let code):
            let failure = POSIXFileSystem.failure(for: code)
            let item = makeItem(
                parentPath: parentPath,
                originalName: name,
                relativePath: relative,
                kind: .file,
                depth: depth,
                accessError: failure == .missing ? .unreadable : failure
            )
            if insert(item, seen: &seen) {
                items.append(item)
                noteDiscovery(&discovered, progress: progress)
            }
            return
        case .missing:
            let item = makeItem(
                parentPath: parentPath,
                originalName: name,
                relativePath: relative,
                kind: .file,
                depth: depth,
                accessError: .missing
            )
            if insert(item, seen: &seen) {
                items.append(item)
                noteDiscovery(&discovered, progress: progress)
            }
            return
        case .found(let identity):
            if identity.isSymbolicLink {
                let item = makeItem(
                    parentPath: parentPath,
                    originalName: name,
                    relativePath: relative,
                    kind: .symlink,
                    depth: depth
                )
                if insert(item, identity: identity, parentPath: parentPath, seen: &seen) {
                    items.append(item)
                    noteDiscovery(&discovered, progress: progress)
                }
                return
            }

            let isAppBundle = identity.isDirectory && POSIXFileSystem.isAppBundleName(name)
            let kind: EntryKind = isAppBundle ? .appBundle : (identity.isDirectory ? .directory : .file)
            var listingWarning: String?
            var children: [URL] = []

            if identity.isDirectory && !isAppBundle {
                do {
                    children = try autoreleasepool {
                        try FileManager.default.contentsOfDirectory(
                            at: url,
                            includingPropertiesForKeys: [.nameKey],
                            options: []
                        )
                    }
                } catch {
                    listingWarning = "하위 항목을 읽지 못했습니다."
                }
            }

            let item = makeItem(
                parentPath: parentPath,
                originalName: name,
                relativePath: relative,
                kind: kind,
                depth: depth,
                listingWarning: listingWarning
            )
            let inserted = insert(item, identity: identity, parentPath: parentPath, seen: &seen)
            if inserted {
                items.append(item)
                noteDiscovery(&discovered, progress: progress)
                if isAppBundle {
                    appBundleCount += 1
                }
            }

            guard inserted, identity.isDirectory, !isAppBundle else {
                return
            }

            let ordered = children.sorted { lhs, rhs in
                POSIXFileSystem.exactName(of: lhs).utf8.lexicographicallyPrecedes(
                    POSIXFileSystem.exactName(of: rhs).utf8
                )
            }
            for child in ordered {
                if isCancelled() {
                    return
                }
                let childName = POSIXFileSystem.exactName(of: child)
                scan(
                    url: child,
                    relativePath: relative + "/" + childName,
                    items: &items,
                    seen: &seen,
                    appBundleCount: &appBundleCount,
                    discovered: &discovered,
                    isCancelled: isCancelled,
                    progress: progress
                )
            }
        }
    }

    private func makeItem(
        parentPath: String,
        originalName: String,
        relativePath: String,
        kind: EntryKind,
        depth: Int,
        listingWarning: String? = nil,
        accessError: RenameFailure? = nil
    ) -> ScanItem {
        ScanItem(
            parentPath: parentPath,
            originalName: originalName,
            proposedName: normalizer.normalizedFilename(originalName),
            relativePath: relativePath,
            kind: kind,
            needsNormalization: accessError == nil && kind != .symlink && normalizer.needsNormalization(originalName),
            depth: depth,
            listingWarning: listingWarning,
            accessError: accessError
        )
    }

    private func insert(
        _ item: ScanItem,
        identity: FileIdentity? = nil,
        parentPath: String? = nil,
        seen: inout Set<DirectoryEntryKey>
    ) -> Bool {
        let key: DirectoryEntryKey
        if let identity, let parentPath, case .found(let parent) = POSIXFileSystem.lookup(parentPath) {
            key = DirectoryEntryKey(
                device: parent.device,
                inode: parent.inode,
                childDevice: identity.device,
                childInode: identity.inode,
                name: Array(item.originalName.utf8)
            )
        } else {
            key = DirectoryEntryKey(
                device: 0,
                inode: 0,
                childDevice: 0,
                childInode: 0,
                name: Array(item.fullPath.utf8)
            )
        }
        return seen.insert(key).inserted
    }

    private func noteDiscovery(_ discovered: inout Int, progress: (Int) -> Void) {
        discovered += 1
        if discovered % 40 == 0 {
            progress(discovered)
        }
    }
}

private nonisolated struct DirectoryEntryKey: Hashable {
    var device: UInt64
    var inode: UInt64
    var childDevice: UInt64
    var childInode: UInt64
    var name: [UInt8]
}

import Foundation

nonisolated struct ScanItem: Identifiable, Sendable, Equatable {
    let id: UUID
    let parentPath: String
    let originalName: String
    let proposedName: String
    let relativePath: String
    let kind: EntryKind
    let needsNormalization: Bool
    let depth: Int
    var listingWarning: String?
    var accessError: RenameFailure?

    init(
        id: UUID = UUID(),
        parentPath: String,
        originalName: String,
        proposedName: String,
        relativePath: String,
        kind: EntryKind,
        needsNormalization: Bool,
        depth: Int,
        listingWarning: String? = nil,
        accessError: RenameFailure? = nil
    ) {
        self.id = id
        self.parentPath = parentPath
        self.originalName = originalName
        self.proposedName = proposedName
        self.relativePath = relativePath
        self.kind = kind
        self.needsNormalization = needsNormalization
        self.depth = depth
        self.listingWarning = listingWarning
        self.accessError = accessError
    }

    var fullPath: String {
        PathJoiner.join(parentPath, originalName)
    }

    var willRename: Bool {
        needsNormalization && accessError == nil && kind != .symlink
    }

    var previewStatus: String {
        if let accessError {
            return accessError.message
        }
        if kind == .symlink {
            return "심볼릭 링크 (제외)"
        }
        if needsNormalization {
            if let listingWarning {
                return "변경 예정 · \(listingWarning)"
            }
            return "변경 예정"
        }
        if let listingWarning {
            return "변경 필요 없음 · \(listingWarning)"
        }
        return "변경 필요 없음"
    }
}

nonisolated struct ScanOutcome: Sendable, Equatable {
    var items: [ScanItem]
    var appBundleCount: Int
}

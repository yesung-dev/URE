import Foundation

/// One completed rename, stored so it can be reversed without reconstructing paths.
nonisolated struct RenameOperation: Identifiable, Sendable, Equatable {
    let id: UUID
    /// Parent directory as it existed when this item was renamed.
    /// Ancestors are restored first, so this path is valid again during undo.
    let parentPath: String
    let originalName: String
    let renamedName: String

    init(
        id: UUID = UUID(),
        parentPath: String,
        originalName: String,
        renamedName: String
    ) {
        self.id = id
        self.parentPath = parentPath
        self.originalName = originalName
        self.renamedName = renamedName
    }

    var originalPath: String {
        PathJoiner.join(parentPath, originalName)
    }

    var renamedPath: String {
        PathJoiner.join(parentPath, renamedName)
    }
}

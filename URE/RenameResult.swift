import Foundation

nonisolated enum EntryKind: Sendable, Equatable {
    case file
    case directory
    case symlink
    case appBundle

    var label: String {
        switch self {
        case .file:
            "파일"
        case .directory:
            "폴더"
        case .symlink:
            "심볼릭 링크"
        case .appBundle:
            "앱"
        }
    }
}

nonisolated enum RenameFailure: Error, Sendable, Equatable {
    case collision
    case permission
    case missing
    case invalidName
    case stranded(path: String)
    case unreadable
    case other(String)

    var message: String {
        switch self {
        case .collision:
            "이름 충돌로 변경하지 않았습니다."
        case .permission:
            "권한이 없어 변경하지 못했습니다."
        case .missing:
            "파일을 찾을 수 없어 변경하지 못했습니다."
        case .invalidName:
            "사용할 수 없는 파일명입니다."
        case .stranded(let path):
            "임시 이름으로 옮긴 뒤 되돌리지 못했습니다. \(path)"
        case .unreadable:
            "권한이 없어 읽지 못했습니다."
        case .other(let message):
            message
        }
    }

    var isPermission: Bool {
        switch self {
        case .permission, .unreadable:
            true
        default:
            false
        }
    }
}

nonisolated enum RenameStatus: Sendable, Equatable {
    case renamed
    case unchanged
    case skippedSymlink
    case cancelled
    case failed(RenameFailure)

    var label: String {
        switch self {
        case .renamed:
            "성공"
        case .unchanged:
            "변경할 필요 없음"
        case .skippedSymlink:
            "심볼릭 링크"
        case .cancelled:
            "취소됨"
        case .failed(let failure):
            failure.message
        }
    }

    var isFailure: Bool {
        if case .failed = self { return true }
        return false
    }
}

nonisolated struct RenameResult: Identifiable, Sendable, Equatable {
    let id: UUID
    let originalName: String
    let proposedName: String
    let relativePath: String
    let fullPath: String
    let kind: EntryKind
    let status: RenameStatus
    var note: String?

    var statusText: String {
        if let note, !status.isFailure {
            return "\(status.label) · \(note)"
        }
        return status.label
    }

    var isPermissionFailure: Bool {
        if case .failed(let failure) = status {
            return failure.isPermission
        }
        return false
    }

    var parentPath: String {
        (fullPath as NSString).deletingLastPathComponent
    }

    func retryItem() -> ScanItem {
        ScanItem(
            id: id,
            parentPath: parentPath,
            originalName: originalName,
            proposedName: proposedName,
            relativePath: relativePath,
            kind: kind,
            needsNormalization: true,
            depth: fullPath.split(separator: "/", omittingEmptySubsequences: true).count
        )
    }
}

nonisolated extension RenameBatch {
    func merging(_ retry: RenameBatch) -> RenameBatch {
        let replacements = Dictionary(uniqueKeysWithValues: retry.results.map { ($0.id, $0) })
        return RenameBatch(
            results: results.map { replacements[$0.id] ?? $0 },
            operations: operations + retry.operations
        )
    }
}

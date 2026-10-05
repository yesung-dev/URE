import Darwin
import Foundation

nonisolated struct POSIXRenameError: Error, Equatable {
    var code: Int32
}

nonisolated enum FileLookup: Equatable {
    case found(FileIdentity)
    case missing
    case failed(Int32)
}

nonisolated struct FileIdentity: Equatable, Sendable {
    var device: UInt64
    var inode: UInt64
    var isSymbolicLink: Bool
    var isDirectory: Bool
}

nonisolated enum PathJoiner {
    static func join(_ parent: String, _ name: String) -> String {
        if parent == "/" {
            return "/" + name
        }
        if parent.hasSuffix("/") {
            return parent + name
        }
        return parent + "/" + name
    }
}

nonisolated enum POSIXFileSystem {
    static func lookup(_ path: String) -> FileLookup {
        var info = stat()
        let result = path.withCString { lstat($0, &info) }
        if result != 0 {
            let code = errno
            if code == ENOENT {
                return .missing
            }
            return .failed(code)
        }
        let mode = info.st_mode & S_IFMT
        return .found(
            FileIdentity(
                device: UInt64(info.st_dev),
                inode: UInt64(info.st_ino),
                isSymbolicLink: mode == S_IFLNK,
                isDirectory: mode == S_IFDIR
            )
        )
    }

    /// Renames without Foundation path conversion.
    /// `FileManager.moveItem` rewrites the destination into NFD, so NFC would not stick.
    /// `RENAME_EXCL` makes the call fail when the destination is a different existing item.
    static func renameExclusively(from source: String, to destination: String) throws {
        var captured: Int32 = 0
        let result: Int32 = source.withCString { sourcePointer in
            destination.withCString { destinationPointer in
                let status = renamex_np(sourcePointer, destinationPointer, UInt32(RENAME_EXCL))
                if status != 0 {
                    captured = errno
                }
                return status
            }
        }
        if result != 0 {
            throw POSIXRenameError(code: captured == 0 ? errno : captured)
        }
    }

    static func exactName(of url: URL) -> String {
        if let name = try? url.resourceValues(forKeys: [.nameKey]).name, !name.isEmpty {
            return name
        }
        return url.lastPathComponent
    }

    static func isAppBundleName(_ name: String) -> Bool {
        (name as NSString).pathExtension.compare("app", options: [.caseInsensitive]) == .orderedSame
    }

    static func failure(for code: Int32) -> RenameFailure {
        switch code {
        case EEXIST:
            return .collision
        case EACCES, EPERM:
            return .permission
        case ENOENT:
            return .missing
        case ENAMETOOLONG, EINVAL:
            return .invalidName
        default:
            return .other("변경하지 못했습니다. (오류 \(code))")
        }
    }
}

import Foundation

/// Canonical composition (NFC). Compatibility forms such as NFKC are intentionally unused.
nonisolated struct FilenameNormalizer: Sendable {
    func normalizedFilename(_ filename: String) -> String {
        filename.precomposedStringWithCanonicalMapping
    }

    /// Swift `String` equality is canonically equivalent, so it cannot detect NFD versus NFC.
    func needsNormalization(_ filename: String) -> Bool {
        let normalized = normalizedFilename(filename)
        return !filename.unicodeScalars.elementsEqual(normalized.unicodeScalars)
    }
}

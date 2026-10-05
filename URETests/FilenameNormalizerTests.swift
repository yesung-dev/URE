import XCTest
@testable import URE

final class FilenameNormalizerTests: XCTestCase {
    private let normalizer = FilenameNormalizer()

    func testNFCStringStaysNFC() {
        let name = "한글.txt"
        let normalized = normalizer.normalizedFilename(name)
        XCTAssertTrue(normalized.unicodeScalars.elementsEqual(name.unicodeScalars))
        XCTAssertFalse(normalizer.needsNormalization(name))
    }

    func testNFDStringBecomesNFC() {
        let nfd = "한글".decomposedStringWithCanonicalMapping
        let nfc = "한글".precomposedStringWithCanonicalMapping
        XCTAssertFalse(nfd.unicodeScalars.elementsEqual(nfc.unicodeScalars))
        let normalized = normalizer.normalizedFilename(nfd)
        XCTAssertTrue(normalized.unicodeScalars.elementsEqual(nfc.unicodeScalars))
        XCTAssertTrue(normalizer.needsNormalization(nfd))
        XCTAssertFalse(normalizer.needsNormalization(nfc))
    }

    func testKoreanFilenameKeepsExtension() {
        let nfd = "한글".decomposedStringWithCanonicalMapping + ".tar.gz"
        let normalized = normalizer.normalizedFilename(nfd)
        XCTAssertTrue(normalized.hasSuffix(".tar.gz"))
        XCTAssertTrue(
            normalized.unicodeScalars.elementsEqual(
                ("한글".precomposedStringWithCanonicalMapping + ".tar.gz").unicodeScalars
            )
        )
    }

    func testEnglishFilenameIsUnchanged() {
        let name = "Meeting Notes.txt"
        XCTAssertTrue(normalizer.normalizedFilename(name).unicodeScalars.elementsEqual(name.unicodeScalars))
        XCTAssertFalse(normalizer.needsNormalization(name))
    }

    func testNumbersAndSymbolsAreUnchanged() {
        let name = "file-01_v2 (copy) [final].txt"
        XCTAssertTrue(normalizer.normalizedFilename(name).unicodeScalars.elementsEqual(name.unicodeScalars))
        XCTAssertFalse(normalizer.needsNormalization(name))
    }

    func testCombiningAccentBecomesPrecomposed() {
        let nfd = "cafe\u{0301}.txt"
        let normalized = normalizer.normalizedFilename(nfd)
        XCTAssertTrue(normalized.unicodeScalars.elementsEqual("caf\u{00e9}.txt".unicodeScalars))
    }

    func testCanonicalSingletonIsComposed() {
        let ohm = "\u{2126}"
        let omega = "\u{03A9}"
        XCTAssertTrue(normalizer.normalizedFilename(ohm).unicodeScalars.elementsEqual(omega.unicodeScalars))
        XCTAssertTrue(normalizer.needsNormalization(ohm))
    }

    func testCompatibilityCharactersAreNotChanged() {
        let ligature = "\u{FB01}.txt"
        let fullwidth = "\u{FF21}1.txt"
        XCTAssertTrue(normalizer.normalizedFilename(ligature).unicodeScalars.elementsEqual(ligature.unicodeScalars))
        XCTAssertTrue(normalizer.normalizedFilename(fullwidth).unicodeScalars.elementsEqual(fullwidth.unicodeScalars))
        XCTAssertFalse(normalizer.needsNormalization(ligature))
        XCTAssertFalse(normalizer.needsNormalization(fullwidth))
    }
}

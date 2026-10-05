import XCTest

final class UpdateConfigurationTests: XCTestCase {
    func testSparklePublicKeyIsConfigured() {
        XCTAssertEqual(Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String, "URE")
        let key = Bundle.main.object(forInfoDictionaryKey: "SUPublicEDKey") as? String
        XCTAssertNotNil(key)
        XCTAssertFalse(key?.isEmpty ?? true)
    }
}

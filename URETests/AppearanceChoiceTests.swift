import XCTest
@testable import URE

final class AppearanceChoiceTests: XCTestCase {
    func testLightAndDarkOverrideTheSystem() {
        XCTAssertEqual(AppearanceChoice.light.colorScheme, .light)
        XCTAssertEqual(AppearanceChoice.dark.colorScheme, .dark)
        XCTAssertNil(AppearanceChoice.system.colorScheme)
    }
}

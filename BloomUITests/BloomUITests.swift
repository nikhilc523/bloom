import XCTest

final class BloomUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    /// Happy path: logging a period surfaces the "logged today" badge.
    /// Queries use accessibility identifiers, never visible text.
    func testLogPeriodShowsBadge() {
        let app = XCUIApplication()
        app.launchArguments += ["-uiTesting"]
        app.launch()

        XCTAssertTrue(app.otherElements["cycleRing"].waitForExistence(timeout: 5))

        app.buttons["logPeriodButton"].tap()
        app.buttons["flowMediumButton"].tap()
        app.buttons["saveLogButton"].tap()

        let badge = app.descendants(matching: .any)["loggedTodayBadge"]
        XCTAssertTrue(
            badge.waitForExistence(timeout: 3),
            "Logging a period should reveal the 'logged today' badge"
        )
    }
}

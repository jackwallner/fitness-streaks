import XCTest

/// Release-gate journeys. Seeded streaks stand in for Apple Health history, which a
/// simulator does not have: 12 day steps, 9 day exercise, 7 day stand, 6 day sleep.
@MainActor
final class ReleaseJourneysUITests: XCTestCase {
    private let seedArguments = ["-FitnessScreenshotBrand", "-UITestSeedStreaks", "-UITestSkipHealthKit", "-UITestSetPro"]

    override func setUp() {
        continueAfterFailure = false
    }

    private func makeApp() -> XCUIApplication {
        // Addressed by bundle id: PRODUCT_NAME differs from the target name here.
        XCUIApplication(bundleIdentifier: "com.jackwallner.streaks")
    }

    /// Any element whose accessibility label starts with `prefix`, whatever its type,
    /// so the query holds in a tab bar layout and in a two-pane one.
    private func element(_ app: XCUIApplication, startingWith prefix: String) -> XCUIElement {
        app.descendants(matching: .any)
            .matching(NSPredicate(format: "label BEGINSWITH %@", prefix)).firstMatch
    }

    private func requireElement(_ app: XCUIApplication, startingWith prefix: String, timeout: TimeInterval = 90,
                                file: StaticString = #filePath, line: UInt = #line) -> XCUIElement {
        let match = element(app, startingWith: prefix)
        XCTAssertTrue(match.waitForExistence(timeout: timeout), "\"\(prefix)\" never appeared", file: file, line: line)
        return match
    }

    /// Dismisses the first-run coachmark tour if it is up.
    private func skipTutorialIfShown(_ app: XCUIApplication, journey: String = #function) {
        let skip = app.buttons["Skip tutorial"]
        guard skip.waitForExistence(timeout: 5) else { return }
        QA.checkpoint(app, "tutorial", journey: journey)
        skip.tap()
        XCTAssertTrue(skip.waitForNonExistence(timeout: 5), "the tutorial did not close")
    }

    /// The dashboard shows every seeded streak with the count the engine produced.
    private func assertDashboardStreaks(_ app: XCUIApplication) {
        _ = requireElement(app, startingWith: "Steps streak: 12 days, threshold")
        _ = requireElement(app, startingWith: "Exercise streak: 9 days")
        _ = requireElement(app, startingWith: "Stand streak: 7 days")
        _ = requireElement(app, startingWith: "Sleep streak: 6 days")
    }

    func testCoreLoopStreaksCountAndSurviveRelaunch() {
        let app = makeApp()
        QA.launch(app, arguments: seedArguments)

        assertDashboardStreaks(app)
        QA.checkpoint(app, "dashboard-streaks")

        skipTutorialIfShown(app)
        QA.checkpoint(app, "dashboard-after-tutorial")

        // Open a streak and read its numbers on the detail screen.
        let exercise = requireElement(app, startingWith: "Exercise streak: 9 days")
        exercise.tap()
        _ = requireElement(app, startingWith: "Exercise streak: 9 days in a row, threshold 20 min")
        XCTAssertTrue(app.staticTexts["DETAIL"].waitForExistence(timeout: 10), "the detail screen did not open")
        QA.checkpoint(app, "exercise-detail")

        app.buttons["Back"].tap()
        assertDashboardStreaks(app)
        QA.checkpoint(app, "dashboard-after-detail")

        // The same streaks, and a tour that stays dismissed, after a cold start.
        QA.relaunch(app)
        assertDashboardStreaks(app)
        XCTAssertFalse(app.buttons["Skip tutorial"].waitForExistence(timeout: 3), "the tutorial came back after relaunch")
        QA.checkpoint(app, "dashboard-after-relaunch")
    }
}

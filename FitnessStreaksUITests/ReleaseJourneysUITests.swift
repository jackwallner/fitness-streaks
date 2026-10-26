import XCTest

/// The release gate's journeys (`qa-gate run`): the welcome screen, seeded
/// streaks with a detail, Saves and Stats, the Streaks+ paywall shown and
/// closed, and a return visit with an interruption. Each step ends in
/// `QA.checkpoint`, which runs the fleet oracles on the screen. Assert
/// reachability only.
///
/// First run stops at the welcome screen: its button raises the system's
/// Apple Health prompt, which is not the app's to check.
@MainActor
final class ReleaseJourneysUITests: XCTestCase {

    private static let bundle = "com.jackwallner.streaks"
    private static let seeded = ["-FitnessScreenshotBrand", "-UITestSeedStreaks", "-UITestSkipHealthKit"]

    func test01FirstRunWelcome() {
        continueAfterFailure = false
        let app = XCUIApplication(bundleIdentifier: Self.bundle)
        QA.launch(app)
        XCTAssertTrue(app.staticTexts["DISCOVER YOUR STREAKS"].waitForExistence(timeout: 20), "welcome never rendered")
        QA.checkpoint(app, "welcome")
    }

    func test02StreaksSavesAndStats() {
        continueAfterFailure = false
        let app = launch(Self.seeded + ["-UITestSetPro"])
        QA.checkpoint(app, "streaks")

        app.buttons["Saves"].firstMatch.tap()
        QA.checkpoint(app, "saves")

        app.buttons["Stats"].firstMatch.tap()
        QA.checkpoint(app, "stats")

        app.buttons["Streaks"].firstMatch.tap()
        QA.checkpoint(app, "streaks-return")
    }

    func test03StreaksPlusPaywallShownAndClosed() {
        continueAfterFailure = false
        // The Test Store, a separate RevenueCat app, supplies the prices; the
        // production key never runs on a simulator. Its customer never buys.
        let app = launch(Self.seeded + ["-UITestSetFree", "-rcfunnelprobe"],
                         environment: ["RC_PROBE_USER": "qa-streaks-journeys"])
        // The auto-save banner is the free user's way in; the screenshot brand
        // hides Settings' Streaks+ section.
        let unlock = app.buttons.matching(NSPredicate(
            format: "label BEGINSWITH[c] %@ OR label BEGINSWITH[c] %@", "UNLOCK STREAKS+", "TRY STREAKS+ FREE")).firstMatch
        XCTAssertTrue(unlock.waitForExistence(timeout: 15), "Streaks+ banner missing for a free user")
        QA.checkpoint(app, "streaks-free")

        for _ in 0..<4 where !unlock.isHittable { app.swipeUp() }
        unlock.tap()
        XCTAssertTrue(app.staticTexts["DON'T BREAK THE STREAK."].waitForExistence(timeout: 20), "paywall never rendered")
        QA.checkpoint(app, "streaks-plus-paywall", paywall: true)

        let close = app.buttons.containing(NSPredicate(format: "label CONTAINS[c] %@", "close")).firstMatch
        XCTAssertTrue(close.waitForExistence(timeout: 10))
        close.tap()
        XCTAssertTrue(unlock.waitForExistence(timeout: 15), "paywall never closed")
        QA.checkpoint(app, "streaks-after-paywall", paywall: false)
    }

    func test04ReturnVisitWithInterruption() {
        continueAfterFailure = false
        let app = launch(Self.seeded + ["-UITestSetPro"])
        app.buttons["Stats"].firstMatch.tap()
        QA.checkpoint(app, "stats-before-interruption")

        QA.interrupt(app)
        QA.checkpoint(app, "stats-after-interruption")

        QA.relaunch(app)
        XCTAssertTrue(app.buttons["Open settings"].waitForExistence(timeout: 25))
        QA.checkpoint(app, "streaks-after-relaunch")
    }

    private func launch(_ arguments: [String], environment: [String: String] = [:]) -> XCUIApplication {
        let app = XCUIApplication(bundleIdentifier: Self.bundle)
        QA.launch(app, environment: environment, arguments: arguments)
        XCTAssertTrue(app.buttons["Open settings"].waitForExistence(timeout: 25), "Streaks never rendered")
        return app
    }
}

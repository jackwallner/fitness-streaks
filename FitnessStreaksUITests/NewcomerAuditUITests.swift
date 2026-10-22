import XCTest

/// Persona audit: a first-time user who does not know the app's terminology.
/// Screenshots and an `observations` attachment carry the findings; the only
/// assertions are that the next element needed for the walk exists.
final class NewcomerAuditUITests: XCTestCase {

    private var app: XCUIApplication!
    private var observations: [String] = []
    private let bundleID = "com.jackwallner.streaks"

    override func setUp() {
        continueAfterFailure = true
    }

    override func tearDown() {
        let note = XCTAttachment(string: observations.joined(separator: "\n"))
        note.name = "observations"
        note.lifetime = .keepAlways
        add(note)
    }

    // MARK: - Helpers

    private func shot(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func note(_ text: String) { observations.append(text) }

    private func settle(_ seconds: TimeInterval = 1.0) {
        Thread.sleep(forTimeInterval: seconds)
    }

    /// Logs every visible static text and every button smaller than 44 pt.
    private func inventory(_ screen: String) {
        let texts = app.staticTexts.allElementsBoundByIndex
            .filter { $0.exists && !$0.label.isEmpty }
            .map { String(format: "%@ [%.0fx%.0f]", $0.label.replacingOccurrences(of: "\n", with: " / "), $0.frame.width, $0.frame.height) }
        note("TEXT@\(screen): " + texts.joined(separator: " | "))
        let small = app.buttons.allElementsBoundByIndex.filter {
            $0.exists && $0.frame.width > 0 && ($0.frame.height < 44 || $0.frame.width < 44)
        }
        let list = small.map { String(format: "%@ [%.0fx%.0f]", $0.label.replacingOccurrences(of: "\n", with: " / "), $0.frame.width, $0.frame.height) }
        note("SMALL-TARGETS@\(screen) (<44pt): " + (list.isEmpty ? "none" : list.joined(separator: " | ")))
    }

    private func tapIfPresent(_ element: XCUIElement, timeout: TimeInterval = 5) -> Bool {
        guard element.waitForExistence(timeout: timeout) else { return false }
        element.tap()
        return true
    }

    /// Answers the Health permission sheet wherever it is hosted.
    private func answerHealthSheet() -> Bool {
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let deadline = Date().addingTimeInterval(25)
        var answered = false
        while Date() < deadline {
            for host in [app!, springboard] {
                for label in ["Turn On All", "Allow", "Turn on All"] {
                    for query in [host.switches[label], host.buttons[label], host.staticTexts[label], host.cells[label]] where query.exists {
                        query.tap()
                        settle(1.0)
                        answered = true
                    }
                }
            }
            if answered && app.buttons["Allow"].exists == false && app.buttons["Done"].exists == false { break }
            settle(1.0)
        }
        return answered
    }

    // MARK: - Fresh install: onboarding with no Health data

    func testNewcomerFirstRunNoHealthData() {
        app = XCUIApplication(bundleIdentifier: bundleID)
        app.launchArguments += ["-UITestSkipHealthKit"]
        let launchStart = Date()
        app.launch()

        let start = app.buttons["▶ GET STARTED"]
        XCTAssertTrue(start.waitForExistence(timeout: 30), "intro never showed GET STARTED")
        note(String(format: "LAUNCH-TO-INTRO %.1fs", Date().timeIntervalSince(launchStart)))
        settle(1.5)
        shot("01-intro")
        inventory("intro")

        start.tap()
        settle(1.0)
        shot("02-intensity")
        inventory("intensity")
        note("INTENSITY rows: " + app.buttons.allElementsBoundByIndex.map { $0.label.replacingOccurrences(of: "\n", with: " / ") }.joined(separator: " || "))

        let find = app.buttons["▶ FIND MY STREAKS"]
        XCTAssertTrue(find.waitForExistence(timeout: 5))
        let findTapped = Date()
        find.tap()
        settle(1.5)
        shot("03-after-find-my-streaks")
        let sheet = answerHealthSheet()
        note("HEALTH-SHEET answered=\(sheet)")
        shot("04-after-health-sheet")
        add(XCTAttachment(string: app.debugDescription))

        // Wait for the discovery result: empty page or the selection page.
        let empty = app.staticTexts["NO STREAKS YET"]
        let yours = app.staticTexts["YOUR STREAKS"]
        let deadline = Date().addingTimeInterval(60)
        while Date() < deadline, !empty.exists, !yours.exists { settle(0.5) }
        note(String(format: "FIND-TO-RESULT %.1fs (empty=%@ selecting=%@)", Date().timeIntervalSince(findTapped), "\(empty.exists)", "\(yours.exists)"))
        shot("05-discovery-result")
        inventory("discovery-result")

        let cont = app.buttons["▶ CONTINUE"]
        if cont.exists {
            cont.tap()
        } else if app.buttons.matching(NSPredicate(format: "label BEGINSWITH '▶ START'")).firstMatch.exists {
            app.buttons.matching(NSPredicate(format: "label BEGINSWITH '▶ START'")).firstMatch.tap()
        }
        settle(3.0)
        shot("06-after-onboarding")
        inventory("post-onboarding")

        // Trial page may or may not appear (no products on a simulator).
        let free = app.buttons["CONTINUE WITH 3 FREE STREAKS"]
        if free.waitForExistence(timeout: 3) { shot("06b-trial-page"); free.tap(); settle(2) }

        shot("07-first-dashboard")
        inventory("first-dashboard")
        add(XCTAttachment(string: app.debugDescription))

        for tab in ["Saves", "Stats", "Streaks"] where app.buttons[tab].exists {
            app.buttons[tab].tap()
            settle(1.2)
            shot("08-tab-\(tab)")
            inventory("tab-\(tab)")
        }
        if tapIfPresent(app.buttons["Open settings"], timeout: 3) {
            settle(1.5)
            shot("09-settings-top")
            inventory("settings")
            app.swipeUp(); settle(0.6)
            shot("10-settings-mid")
            app.swipeUp(); settle(0.6)
            shot("11-settings-bottom")
        }

        // Return visit: relaunch and see what greets the user.
        app.terminate()
        app.launch()
        settle(5)
        shot("12-return-visit")
        inventory("return-visit")
    }

    // MARK: - Seeded dashboard as a free user

    func testNewcomerSeededDashboardFree() {
        app = XCUIApplication(bundleIdentifier: bundleID)
        app.launchArguments += ["-FitnessScreenshotBrand", "-UITestSeedStreaks", "-UITestSkipHealthKit"]
        app.launch()

        let cards = app.buttons.matching(NSPredicate(format: "label CONTAINS ' streak: '"))
        XCTAssertTrue(cards.firstMatch.waitForExistence(timeout: 30), "seeded dashboard never showed a streak")
        settle(1.5)
        shot("20-seeded-dashboard")
        inventory("seeded-dashboard")
        note("CARD labels: " + cards.allElementsBoundByIndex.map { $0.label }.joined(separator: " || "))

        app.swipeUp(); settle(0.6)
        shot("21-seeded-dashboard-scrolled")
        inventory("seeded-dashboard-scrolled")
        app.swipeDown(); settle(0.6)

        // Open the hero streak.
        cards.firstMatch.tap()
        settle(1.2)
        shot("22-hero-detail")
        inventory("hero-detail")
        app.swipeUp(); settle(0.6)
        shot("23-hero-detail-bottom")
        if app.buttons["Back"].exists { app.buttons["Back"].tap(); settle(1) }

        // The "find more" path a newcomer would use to add something.
        let findMore = app.buttons.matching(NSPredicate(format: "label CONTAINS 'FIND MORE'")).firstMatch
        if !findMore.exists { app.swipeUp(); settle(0.6) }
        if findMore.exists {
            findMore.tap()
            settle(1.5)
            shot("24-find-more-picker")
            inventory("find-more-picker")
            app.swipeUp(); settle(0.6)
            shot("25-find-more-picker-scrolled")
            let close = app.buttons.matching(NSPredicate(format: "label IN {'Close','Done','CLOSE','DONE','Back'}")).firstMatch
            if close.exists { close.tap(); settle(1) }
        } else {
            note("FIND MORE button not found on seeded dashboard")
        }

        for tab in ["Saves", "Stats"] where app.buttons[tab].exists {
            app.buttons[tab].tap()
            settle(1.2)
            shot("26-tab-\(tab)")
            inventory("seeded-tab-\(tab)")
        }
    }
}

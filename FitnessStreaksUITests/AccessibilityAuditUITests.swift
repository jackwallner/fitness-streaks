import XCTest

/// Persona audit: larger text, reduced motion, imperfect vision, one-handed reach.
/// Screenshots and an `observations` attachment carry the findings. The only
/// assertions are that the element needed for the next step exists.
final class AccessibilityAuditUITests: XCTestCase {

    private var app: XCUIApplication!
    private var observations: [String] = []
    private let bundleID = "com.jackwallner.streaks"
    private let axXXXL = "UICTContentSizeCategoryAccessibilityXXXL"

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

    private func launch(_ extra: [String], size: String? = nil) {
        app = XCUIApplication(bundleIdentifier: bundleID)
        app.launchArguments += extra
        if let size { app.launchArguments += ["-UIPreferredContentSizeCategoryName", size] }
        app.launch()
    }

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

    private func clean(_ s: String) -> String { s.replacingOccurrences(of: "\n", with: " / ") }

    /// Logs buttons with their frames: size, and the thumb zone they sit in
    /// (top third of the screen is hard to reach one-handed on a large phone).
    private func inventory(_ screen: String) {
        let screenH = app.windows.firstMatch.frame.height
        let small = app.buttons.allElementsBoundByIndex.filter {
            $0.exists && $0.frame.width > 0 && ($0.frame.height < 44 || $0.frame.width < 44)
        }
        note("SMALL-TARGETS@\(screen) (<44pt): " + (small.isEmpty ? "none" : small.map {
            String(format: "%@ [%.0fx%.0f @y%.0f]", clean($0.label), $0.frame.width, $0.frame.height, $0.frame.minY)
        }.joined(separator: " | ")))
        let top = app.buttons.allElementsBoundByIndex.filter {
            $0.exists && $0.frame.width > 0 && $0.frame.maxY < screenH / 3 && $0.frame.minY > 0
        }
        note("TOP-THIRD-BUTTONS@\(screen): " + (top.isEmpty ? "none" : top.map {
            String(format: "%@ [y%.0f]", clean($0.label), $0.frame.minY)
        }.joined(separator: " | ")))
        let texts = app.staticTexts.allElementsBoundByIndex
            .filter { $0.exists && !$0.label.isEmpty }
            .map { String(format: "%@ [%.0fx%.0f]", clean($0.label), $0.frame.width, $0.frame.height) }
        note("TEXT@\(screen): " + texts.joined(separator: " | "))
        let offscreen = app.staticTexts.allElementsBoundByIndex.filter {
            $0.exists && !$0.label.isEmpty && ($0.frame.minX < -1 || $0.frame.maxX > app.windows.firstMatch.frame.width + 1)
        }
        if !offscreen.isEmpty {
            note("CLIPPED-HORIZONTAL@\(screen): " + offscreen.map { clean($0.label) }.joined(separator: " | "))
        }
    }

    /// Runs Apple's accessibility audit and records every issue instead of failing.
    private func audit(_ screen: String) {
        do {
            var count = 0
            try app.performAccessibilityAudit(for: .all) { issue in
                count += 1
                let el = issue.element
                note("AUDIT@\(screen): type=\(issue.auditType.rawValue) \(issue.compactDescription) :: \(issue.detailedDescription) :: element=\(el.map { clean($0.label) } ?? "?") [\(el.map { String(format: "%.0fx%.0f", $0.frame.width, $0.frame.height) } ?? "?")]")
                return true
            }
            note("AUDIT@\(screen): \(count) issue(s)")
        } catch {
            note("AUDIT@\(screen) failed: \(error)")
        }
    }

    private func tapIfPresent(_ element: XCUIElement, timeout: TimeInterval = 5) -> Bool {
        guard element.waitForExistence(timeout: timeout) else { return false }
        element.tap()
        return true
    }

    // MARK: - Large text: onboarding

    func testLargeTextOnboarding() {
        launch(["-UITestSkipHealthKit"], size: axXXXL)
        let start = app.buttons.matching(NSPredicate(format: "label CONTAINS 'GET STARTED'")).firstMatch
        XCTAssertTrue(start.waitForExistence(timeout: 30), "intro never showed GET STARTED")
        settle(1.5)
        shot("a01-intro-ax5")
        inventory("intro-ax5")
        note(String(format: "INTRO GET STARTED frame: %.0fx%.0f @y%.0f of %.0f", start.frame.width, start.frame.height, start.frame.minY, app.windows.firstMatch.frame.height))
        audit("intro-ax5")

        // At AX5 the CTA may sit below the fold; scroll to it if needed.
        if !start.isHittable { app.swipeUp(); settle(0.6); note("INTRO: GET STARTED needed scrolling at AX5") }
        shot("a02-intro-ax5-scrolled")
        start.tap()
        settle(1.2)
        shot("a03-intensity-ax5")
        inventory("intensity-ax5")
        let find = app.buttons.matching(NSPredicate(format: "label CONTAINS 'FIND MY STREAKS'")).firstMatch
        note("INTENSITY: FIND MY STREAKS exists=\(find.exists) hittable=\(find.exists && find.isHittable)")
        if find.exists && !find.isHittable { app.swipeUp(); settle(0.6); shot("a04-intensity-ax5-scrolled") }
        audit("intensity-ax5")
    }

    // MARK: - Large text: seeded dashboard, detail, tabs, settings

    func testLargeTextDashboardFlow() {
        launch(["-FitnessScreenshotBrand", "-UITestSeedStreaks", "-UITestSkipHealthKit"], size: axXXXL)
        let cards = app.buttons.matching(NSPredicate(format: "label CONTAINS ' streak: '"))
        XCTAssertTrue(cards.firstMatch.waitForExistence(timeout: 30), "seeded dashboard never showed a streak")
        settle(1.5)
        shot("b01-dashboard-ax5")
        inventory("dashboard-ax5")
        note("CARD labels: " + cards.allElementsBoundByIndex.map { clean($0.label) }.joined(separator: " || "))
        audit("dashboard-ax5")

        app.swipeUp(); settle(0.6)
        shot("b02-dashboard-ax5-scrolled")
        inventory("dashboard-ax5-scrolled")
        app.swipeDown(); app.swipeDown(); settle(0.6)

        if tapIfPresent(cards.firstMatch) {
            settle(1.2)
            shot("b03-detail-ax5")
            inventory("detail-ax5")
            audit("detail-ax5")
            app.swipeUp(); settle(0.6)
            shot("b04-detail-ax5-scrolled")
            app.swipeUp(); settle(0.6)
            shot("b05-detail-ax5-bottom")
            inventory("detail-ax5-bottom")
            if app.buttons["Back"].exists { app.buttons["Back"].tap(); settle(1) }
        }

        for tab in ["Saves", "Stats", "Streaks"] where app.buttons[tab].exists {
            app.buttons[tab].tap()
            settle(1.2)
            shot("b06-tab-\(tab)-ax5")
            inventory("tab-\(tab)-ax5")
            if tab != "Streaks" { audit("tab-\(tab)-ax5") }
        }
        note("TABBAR buttons: " + ["Streaks", "Saves", "Stats"].map { "\($0)=\(app.buttons[$0].exists ? String(format: "%.0fx%.0f", app.buttons[$0].frame.width, app.buttons[$0].frame.height) : "missing")" }.joined(separator: ", "))

        if tapIfPresent(app.buttons["Open settings"], timeout: 3) {
            settle(1.5)
            shot("b07-settings-ax5")
            inventory("settings-ax5")
            audit("settings-ax5")
            for i in 1...4 {
                app.swipeUp(); settle(0.5)
                shot("b08-settings-ax5-\(i)")
            }
        }
    }

    // MARK: - Default size: reach, targets, contrast, audit

    func testDefaultSizeReachAndAudit() {
        launch(["-FitnessScreenshotBrand", "-UITestSeedStreaks", "-UITestSkipHealthKit"])
        let cards = app.buttons.matching(NSPredicate(format: "label CONTAINS ' streak: '"))
        XCTAssertTrue(cards.firstMatch.waitForExistence(timeout: 30))
        settle(1.5)
        shot("c01-dashboard-default")
        inventory("dashboard-default")
        audit("dashboard-default")

        cards.firstMatch.tap()
        settle(1.2)
        shot("c02-detail-default")
        inventory("detail-default")
        audit("detail-default")
        if app.buttons["Back"].exists { app.buttons["Back"].tap(); settle(1) }

        let findMore = app.buttons.matching(NSPredicate(format: "label CONTAINS 'FIND MORE'")).firstMatch
        if !findMore.exists { app.swipeUp(); settle(0.6) }
        if findMore.exists {
            findMore.tap()
            settle(1.5)
            shot("c03-picker-default")
            inventory("picker-default")
            audit("picker-default")
        }
    }

    // MARK: - Large text, first-run with HealthKit prompt skipped: discovery + trial

    func testLargeTextDiscoveryAndPaywall() {
        launch(["-UITestSkipHealthKit"], size: axXXXL)
        let start = app.buttons.matching(NSPredicate(format: "label CONTAINS 'GET STARTED'")).firstMatch
        XCTAssertTrue(start.waitForExistence(timeout: 30))
        start.tap(); settle(1)
        let find = app.buttons.matching(NSPredicate(format: "label CONTAINS 'FIND MY STREAKS'")).firstMatch
        if !find.isHittable { app.swipeUp(); settle(0.6) }
        XCTAssertTrue(find.waitForExistence(timeout: 5))
        find.tap()
        settle(2)
        let empty = app.staticTexts["NO STREAKS YET"]
        let yours = app.staticTexts["YOUR STREAKS"]
        let deadline = Date().addingTimeInterval(60)
        while Date() < deadline, !empty.exists, !yours.exists { settle(0.5) }
        shot("d01-discovery-result-ax5")
        inventory("discovery-ax5")
        audit("discovery-ax5")
        app.swipeUp(); settle(0.6)
        shot("d02-discovery-result-ax5-scrolled")

        let cont = app.buttons.matching(NSPredicate(format: "label CONTAINS 'CONTINUE' OR label BEGINSWITH '▶ START'")).firstMatch
        if cont.exists { cont.tap(); settle(2.5) }
        shot("d03-after-onboarding-ax5")
        inventory("post-onboarding-ax5")
        let free = app.buttons.matching(NSPredicate(format: "label CONTAINS 'FREE STREAKS'")).firstMatch
        if free.waitForExistence(timeout: 3) {
            shot("d04-trial-page-ax5")
            inventory("trial-ax5")
            audit("trial-ax5")
            app.swipeUp(); settle(0.6)
            shot("d05-trial-page-ax5-scrolled")
        }
    }
}

import XCTest

/// Persona audit: a tired, busy user who is interrupted mid-task, comes back
/// later and expects the app to be where they left it.
///
/// Each test makes an interruption (home and back, or a kill and relaunch) and
/// records what the screen shows afterwards as screenshots plus an
/// "observations" attachment. Nothing here asserts product behaviour: a screen
/// or control that is not there is written down as a note, so one run collects
/// every observation. Seeded streaks stand in for Apple Health, which the
/// simulator cannot grant, so `-UITestSkipHealthKit` also skips the Health
/// request inside onboarding (DEBUG only).
@MainActor
final class InterruptedUserAuditUITests: XCTestCase {

    private static let bundle = "com.jackwallner.streaks"
    private static let seeded = ["-UITestSeedStreaks", "-UITestSkipHealthKit"]
    private static let firstRun = ["-UITestResetSetup", "-UITestSetFree"] + seeded

    private var notes: [String] = []
    private var shots = 0

    // MARK: - Onboarding interrupted

    /// Kill the app on the intensity step, come back, and see what was kept.
    func test01OnboardingKilledAtIntensityStep() {
        defer { flush("t01-intensity-kill") }
        continueAfterFailure = true
        let app = launch(Self.firstRun)
        note("launch 1: \(waitForScreen(app, ["intro"], timeout: 40))")
        shot("intro")
        guard tap(button(app, "GET STARTED"), "GET STARTED") else { return }
        _ = waitForScreen(app, ["intensity"], timeout: 10)
        shot("intensity-default")
        note("rows before pick: \(intensityRows(app))")
        tap(button(app, "Sustained"), "Sustained row")
        shot("intensity-sustained-picked")
        note("rows after pick: \(intensityRows(app))")

        relaunch(app, dropping: ["-UITestResetSetup"])
        let after = waitForScreen(app, ["intro", "intensity", "selecting", "dashboard"], timeout: 40)
        note("after kill and relaunch: \(after)")
        shot("relaunch-after-kill")
        if after == "intro", tap(button(app, "GET STARTED"), "GET STARTED again") {
            _ = waitForScreen(app, ["intensity"], timeout: 10)
            shot("intensity-after-relaunch")
            note("rows after relaunch: \(intensityRows(app))")
        }
    }

    /// Edit the selection, leave and come back, then kill and come back.
    func test02OnboardingInterruptedOnStreakSelection() {
        defer { flush("t02-selection") }
        continueAfterFailure = true
        let app = launch(Self.firstRun)
        _ = waitForScreen(app, ["intro"], timeout: 40)
        guard tap(button(app, "GET STARTED"), "GET STARTED") else { return }
        guard tap(button(app, "FIND MY STREAKS"), "FIND MY STREAKS") else { return }
        note("after FIND MY STREAKS: \(waitForScreen(app, ["selecting", "empty"], timeout: 40))")
        shot("selection-default")
        note("default: \(selectionSummary(app))")

        tap(button(app, "EXERCISE"), "EXERCISE row")
        shot("selection-edited")
        note("after untick: \(selectionSummary(app))")

        interrupt(app)
        shot("selection-after-home")
        note("after home and back: screen=\(currentScreen(app)) \(selectionSummary(app))")

        relaunch(app, dropping: ["-UITestResetSetup"])
        let after = waitForScreen(app, ["intro", "intensity", "selecting", "dashboard"], timeout: 40)
        note("after kill and relaunch: \(after)")
        shot("selection-after-kill")
        if after == "intro" {
            guard tap(button(app, "GET STARTED"), "GET STARTED again") else { return }
            _ = waitForScreen(app, ["intensity"], timeout: 10)
            note("rows on second pass: \(intensityRows(app))")
            guard tap(button(app, "FIND MY STREAKS"), "FIND MY STREAKS again") else { return }
            note("second discovery: \(waitForScreen(app, ["selecting", "empty"], timeout: 40))")
            shot("selection-second-pass")
            note("second pass: \(selectionSummary(app))")
        }
    }

    /// Finish onboarding, then interrupt the first-run tour.
    func test03TourInterruptedByKillAndTabSwitch() {
        defer { flush("t03-tour") }
        continueAfterFailure = true
        let app = launch(Self.firstRun)
        _ = waitForScreen(app, ["intro"], timeout: 40)
        guard tap(button(app, "GET STARTED"), "GET STARTED") else { return }
        guard tap(button(app, "FIND MY STREAKS"), "FIND MY STREAKS") else { return }
        _ = waitForScreen(app, ["selecting", "empty"], timeout: 40)
        note("selection: \(selectionSummary(app))")
        guard tap(button(app, "START"), "START") else { return }
        let landed = waitForScreen(app, ["dashboard+tour", "dashboard", "trial", "paywall"], timeout: 40)
        note("after START: \(landed)")
        if landed == "dashboard" { note("tour appeared: \(waitForScreen(app, ["dashboard+tour"], timeout: 15))") }
        shot("after-start")
        note("tour step: \(tourStep(app) ?? "none")")
        guard tourStep(app) != nil else { return }

        tap(button(app, "NEXT"), "NEXT")
        shot("tour-step-2")
        note("tour step after NEXT: \(tourStep(app) ?? "none")")

        relaunch(app, dropping: ["-UITestResetSetup"])
        note("after kill and relaunch: \(waitForScreen(app, ["dashboard+tour", "dashboard", "intro"], timeout: 40))")
        shot("tour-after-kill")
        note("tour step after relaunch: \(tourStep(app) ?? "none")")

        guard tourStep(app) != nil else { return }
        let saves = app.buttons["Saves"].firstMatch
        note("tab bar tappable during tour: exists=\(saves.exists) hittable=\(saves.isHittable)")
        tap(saves, "Saves tab")
        shot("tour-tab-saves")
        tap(app.buttons["Streaks"].firstMatch, "Streaks tab")
        _ = waitForScreen(app, ["dashboard+tour", "dashboard"], timeout: 15)
        shot("tour-after-tab-roundtrip")
        note("tour step after tab round trip: \(tourStep(app) ?? "none")")
    }

    /// The trial page is the last onboarding step for a free user. Needs the
    /// RevenueCat Test Store (never the production key) to load prices.
    func test04TrialPageInterruption() {
        defer { flush("t04-trial") }
        continueAfterFailure = true
        let app = launch(Self.firstRun + ["-rcfunnelprobe"], environment: ["RC_PROBE_USER": "qa-streaks-interrupted"])
        _ = waitForScreen(app, ["intro"], timeout: 40)
        guard tap(button(app, "GET STARTED"), "GET STARTED") else { return }
        guard tap(button(app, "FIND MY STREAKS"), "FIND MY STREAKS") else { return }
        _ = waitForScreen(app, ["selecting", "empty"], timeout: 40)
        note("selection: \(selectionSummary(app))")
        guard tap(button(app, "START"), "START") else { return }
        let landed = waitForScreen(app, ["trial", "paywall", "dashboard+tour", "dashboard"], timeout: 60)
        note("after START with prices available: \(landed)")
        shot("after-start")
        guard landed == "trial" || landed == "paywall" else { return }
        note("buttons: \(visibleButtonLabels(app))")

        interrupt(app)
        shot("trial-after-home")
        note("after home and back: \(currentScreen(app))")

        relaunch(app, dropping: ["-UITestResetSetup"])
        let after = waitForScreen(app, ["intro", "trial", "paywall", "dashboard+tour", "dashboard"], timeout: 60)
        note("after kill and relaunch: \(after)")
        shot("trial-after-kill")
    }

    // MARK: - Moving between tabs

    /// Scroll the dashboard, open a streak, glance at another tab and come back.
    func test05TabSwitchKeepsPlace() {
        defer { flush("t05-tab-switch") }
        continueAfterFailure = true
        let app = launch(["-FitnessScreenshotBrand", "-UITestSetPro"] + Self.seeded)
        guard app.buttons["Open settings"].waitForExistence(timeout: 40) else {
            note("MISSING: dashboard never rendered")
            return
        }
        shot("dashboard-top")
        note("cards at top: \(cardFrames(app))")
        app.swipeUp()
        app.swipeUp()
        shot("dashboard-scrolled")
        note("cards after scroll: \(cardFrames(app))")

        tap(app.buttons["Saves"].firstMatch, "Saves tab")
        shot("saves-glance")
        tap(app.buttons["Streaks"].firstMatch, "Streaks tab")
        _ = app.buttons["Open settings"].waitForExistence(timeout: 10)
        shot("dashboard-after-tab-round-trip")
        note("cards after Saves and back: \(cardFrames(app))")

        let hero = button(app, "Steps streak")
        guard tap(hero, "hero card") else { return }
        _ = app.buttons["Back"].waitForExistence(timeout: 10)
        shot("detail-open")
        app.swipeUp()
        shot("detail-scrolled")
        let stats = app.buttons["Stats"].firstMatch
        note("tab bar on detail: exists=\(stats.exists) hittable=\(stats.isHittable)")
        tap(stats, "Stats tab")
        shot("stats-glance")
        tap(app.buttons["Streaks"].firstMatch, "Streaks tab")
        _ = app.buttons["Open settings"].waitForExistence(timeout: 10)
        shot("after-stats-round-trip")
        note("detail still open after Stats and back: back=\(app.buttons["Back"].exists) gear=\(app.buttons["Open settings"].exists)")
    }

    // MARK: - Helpers

    private func note(_ line: String) {
        notes.append(line)
        print("AUDIT: \(line)")
    }

    private func flush(_ name: String) {
        let attachment = XCTAttachment(string: notes.joined(separator: "\n"))
        attachment.name = "observations-\(name)"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func shot(_ name: String) {
        shots += 1
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = (shots < 10 ? "0\(shots)" : "\(shots)") + "-" + name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func launch(_ arguments: [String], environment: [String: String] = [:]) -> XCUIApplication {
        let app = XCUIApplication(bundleIdentifier: Self.bundle)
        app.launchArguments += arguments
        for (key, value) in environment { app.launchEnvironment[key] = value }
        app.launch()
        return app
    }

    private func relaunch(_ app: XCUIApplication, dropping dropped: [String]) {
        app.terminate()
        app.launchArguments = app.launchArguments.filter { !dropped.contains($0) }
        app.launch()
    }

    private func interrupt(_ app: XCUIApplication, seconds: UInt32 = 4) {
        XCUIDevice.shared.press(.home)
        sleep(seconds)
        app.activate()
        _ = app.wait(for: .runningForeground, timeout: 15)
        sleep(1)
    }

    private func button(_ app: XCUIApplication, _ text: String) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", text)).firstMatch
    }

    private func staticText(_ app: XCUIApplication, _ text: String) -> XCUIElement {
        app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] %@", text)).firstMatch
    }

    @discardableResult
    private func tap(_ element: XCUIElement, _ what: String, timeout: TimeInterval = 10) -> Bool {
        guard element.waitForExistence(timeout: timeout) else {
            note("MISSING: \(what)")
            return false
        }
        element.tap()
        return true
    }

    private func tourStep(_ app: XCUIApplication) -> String? {
        let step = app.staticTexts.matching(NSPredicate(format: "label MATCHES %@", "STEP [0-9]+ / [0-9]+")).firstMatch
        return step.exists ? step.label : nil
    }

    /// Which onboarding or dashboard screen is up, without waiting.
    private func currentScreen(_ app: XCUIApplication) -> String {
        if app.state != .runningForeground { return "not-foreground(\(app.state.rawValue))" }
        if tourStep(app) != nil { return "dashboard+tour" }
        if staticText(app, "DISCOVER YOUR STREAKS").exists { return "intro" }
        if staticText(app, "PICK YOUR INTENSITY").exists { return "intensity" }
        if staticText(app, "FINDING YOUR").exists { return "loading" }
        if staticText(app, "pick the ones you want to track").exists { return "selecting" }
        if staticText(app, "NO STREAKS YET").exists { return "empty" }
        if staticText(app, "KEEP ALL").exists || staticText(app, "PROTECT YOUR").exists { return "trial" }
        if staticText(app, "DON'T BREAK THE STREAK").exists { return "paywall" }
        if app.buttons["Open settings"].exists { return "dashboard" }
        return "unknown"
    }

    @discardableResult
    private func waitForScreen(_ app: XCUIApplication, _ wanted: [String], timeout: TimeInterval) -> String {
        let end = Date().addingTimeInterval(timeout)
        var seen = currentScreen(app)
        while Date() < end {
            seen = currentScreen(app)
            if wanted.contains(seen) { return seen }
            Thread.sleep(forTimeInterval: 0.5)
        }
        return seen
    }

    private func intensityRows(_ app: XCUIApplication) -> String {
        ["Sustained", "Challenging", "Life Changing"].map { name -> String in
            let row = button(app, name)
            return row.exists ? "[\(row.label.prefix(14))]" : "[missing]"
        }.joined(separator: " ")
    }

    private func selectionSummary(_ app: XCUIApplication) -> String {
        let count = staticText(app, "SELECTED")
        let start = button(app, "START")
        let proCard = staticText(app, "FREE TRACKS")
        return "count=\(count.exists ? count.label : "n/a") start=\(start.exists ? start.label : "n/a") card=\(proCard.exists ? proCard.label : "n/a")"
    }

    private func cardFrames(_ app: XCUIApplication) -> String {
        let cards = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "streak:")).allElementsBoundByIndex
        return cards.map { "\($0.label.prefix(18))@y\(Int($0.frame.minY))" }.joined(separator: ", ")
    }

    private func visibleButtonLabels(_ app: XCUIApplication) -> String {
        app.buttons.allElementsBoundByIndex.prefix(14).map { String($0.label.prefix(40)) }.joined(separator: " | ")
    }
}

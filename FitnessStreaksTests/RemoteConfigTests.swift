import XCTest

/// The offering-metadata reader and the trial button wording it drives. The
/// control arm must be exactly the copy the app shipped before the reader.
final class RemoteConfigTests: XCTestCase {
    func testMissingMetadataIsControl() {
        XCTAssertEqual(TrialCTA.from(metadata: nil), .control)
        XCTAssertEqual(TrialCTA.from(metadata: [:]), .control)
    }

    func testNonStringValueIsControl() {
        XCTAssertEqual(TrialCTA.from(metadata: ["trial_cta": 3]), .control)
        XCTAssertEqual(TrialCTA.from(metadata: ["trial_cta": true]), .control)
    }

    func testUnknownValueIsControl() {
        XCTAssertEqual(TrialCTA.from(metadata: ["trial_cta": "our"]), .control)
        XCTAssertEqual(TrialCTA.from(metadata: ["trial_cta": ""]), .control)
    }

    func testEachKnownValueSelectsItsArm() {
        XCTAssertEqual(TrialCTA.from(metadata: ["trial_cta": "seven_day"]), .control)
        XCTAssertEqual(TrialCTA.from(metadata: ["trial_cta": "my"]), .my)
        XCTAssertEqual(TrialCTA.from(metadata: ["trial_cta": "your"]), .your)
    }

    func testMetadataKey() {
        XCTAssertEqual(TrialCTA.metadataKey, "trial_cta")
    }

    // MARK: - Wording per surface

    func testControlOfferSheetTitleIsTodaysCopy() {
        XCTAssertEqual(TrialCTA.control.offerSheetTitle, "START FREE TRIAL")
    }

    func testControlOnboardingButtonIsTodaysCopy() {
        let trial = TrialLength(value: 7, unit: .day)
        XCTAssertEqual(TrialCTA.control.onboardingButton(trial: trial), trial.keepAllButton)
        XCTAssertEqual(trial.keepAllButton, "▶ KEEP ALL · START 7-day free trial")
    }

    func testControlPaywallTitleIsTodaysCopy() {
        let cta = TrialCTA.control
        XCTAssertEqual(
            cta.paywallTitle(plan: .annual, days: 7, price: "$29.99", recurringLabel: "$29.99 / year"),
            "START 7 DAYS FREE · YEARLY $29.99"
        )
        XCTAssertEqual(
            cta.paywallTitle(plan: .monthly, days: 7, price: "$4.99", recurringLabel: "$4.99 / month"),
            "START 7 DAYS FREE · MONTHLY $4.99"
        )
        XCTAssertEqual(
            cta.paywallTitle(plan: .other, days: 7, price: "$9.99", recurringLabel: "$9.99 / 3 months"),
            "START 7 DAYS FREE · $9.99 / 3 months $9.99"
        )
    }

    func testMyArmTitlesPerSurface() {
        let trial = TrialLength(value: 7, unit: .day)
        XCTAssertEqual(TrialCTA.my.offerSheetTitle, "START MY FREE TRIAL")
        XCTAssertEqual(TrialCTA.my.onboardingButton(trial: trial), "▶ KEEP ALL · START MY FREE TRIAL")
        XCTAssertEqual(
            TrialCTA.my.paywallTitle(plan: .annual, days: 7, price: "$29.99", recurringLabel: "x"),
            "START MY FREE TRIAL · YEARLY $29.99"
        )
        XCTAssertEqual(
            TrialCTA.my.paywallTitle(plan: .monthly, days: 7, price: "$4.99", recurringLabel: "x"),
            "START MY FREE TRIAL · MONTHLY $4.99"
        )
    }

    func testYourArmTitlesPerSurface() {
        let trial = TrialLength(value: 7, unit: .day)
        XCTAssertEqual(TrialCTA.your.offerSheetTitle, "START YOUR FREE TRIAL")
        XCTAssertEqual(TrialCTA.your.onboardingButton(trial: trial), "▶ KEEP ALL · START YOUR FREE TRIAL")
        XCTAssertEqual(
            TrialCTA.your.paywallTitle(plan: .annual, days: 7, price: "$29.99", recurringLabel: "x"),
            "START YOUR FREE TRIAL · YEARLY $29.99"
        )
    }

    /// The disclosures and the no-trial wording do not depend on the arm: an
    /// account that already used its trial never reaches a trial button.
    func testDisclosuresIgnoreTheArm() {
        let trial = TrialLength(value: 7, unit: .day)
        XCTAssertEqual(
            trial.onboardingDisclosure(then: "$29.99 / year"),
            "7-Day Free Trial, then $29.99 / year. Auto-renews unless canceled at least 24 hours before the trial ends."
        )
        XCTAssertEqual(
            trial.paywallDisclosure(then: "$29.99 / year"),
            "7-Day Free Trial, then $29.99 / year. Renews automatically unless you cancel at least 24 hours before the trial ends."
        )
    }

    // MARK: - Switches

    func testSwitchIsOnByDefault() {
        XCTAssertTrue(RemoteConfig.isOn(.ratingPrompt, in: nil))
        XCTAssertTrue(RemoteConfig.isOn(.ratingPrompt, in: [:]))
        XCTAssertTrue(RemoteConfig.isOn(.ratingPrompt, in: ["rating_prompt": "on"]))
        XCTAssertTrue(RemoteConfig.isOn(.ratingPrompt, in: ["rating_prompt": false]))
    }

    func testSwitchIsOffOnlyForOff() {
        XCTAssertFalse(RemoteConfig.isOn(.ratingPrompt, in: ["rating_prompt": "off"]))
        XCTAssertTrue(RemoteConfig.isOn(.ratingPrompt, in: ["rating_prompt": "OFF"]))
    }

    func testSwitchKey() {
        XCTAssertEqual(RemoteSwitch.ratingPrompt.rawValue, "rating_prompt")
    }

    // MARK: - Attribute

    func testTrialCTAArmRidesToRevenueCatAfterAPitch() {
        let suite = UserDefaults(suiteName: "RemoteConfigTests.\(UUID().uuidString)")!
        ConversionDiagnostics.defaultsOverride = suite
        defer { ConversionDiagnostics.defaultsOverride = nil }
        ConversionDiagnostics.recordPitchView(impressionID: "streaks_dashboard_sheet")
        XCTAssertNil(ConversionDiagnostics.subscriberAttributes["trial_cta"])
        ConversionDiagnostics.recordTrialCTA("my")
        XCTAssertEqual(ConversionDiagnostics.subscriberAttributes["trial_cta"], "my")
    }
}

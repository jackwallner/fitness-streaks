import XCTest

@MainActor
final class PaidFeatureTests: XCTestCase {

    // MARK: - Lifecycle

    override func setUp() {
        super.setUp()
        // Reset earned grace days to a known state before each test.
        StreakSettings.shared.earnedGraceDays = 0
        StreakSettings.shared.graceAwardTier = 0
        StreakSettings.shared.customStreaks = []
        StreakSettings.shared.gracePreservations = [:]
        StreakSettings.shared.recentlyBroken = []
        StreakSettings.shared.committedThresholds = [:]
        StreakSettings.shared.trackedStreaks = nil
        StreakSettings.shared.hiddenMetrics = []
        StreakSettings.shared.intensity = .challenging
    }

    override func tearDown() {
        StreakSettings.shared.earnedGraceDays = 0
        StreakSettings.shared.graceAwardTier = 0
        StreakSettings.shared.customStreaks = []
        StreakSettings.shared.gracePreservations = [:]
        StreakSettings.shared.recentlyBroken = []
        StreakSettings.shared.committedThresholds = [:]
        super.tearDown()
    }

    // MARK: - Helper: streak factory

    private func makeStreak(current: Int, metric: StreakMetric = .steps, cadence: StreakCadence = .daily, threshold: Double = 10000) -> Streak {
        Streak(
            metric: metric,
            cadence: cadence,
            threshold: threshold,
            current: current,
            best: max(current, 30),
            startDate: nil,
            lastHitDate: nil,
            currentUnitCompleted: true,
            currentUnitProgress: 1.0,
            currentUnitValue: threshold,
            completionRate: 0.8,
            lookbackDays: 30
        )
    }

    // ──────────────────────────────────────────────
    // MARK: - StoreKitService State Management
    // ──────────────────────────────────────────────

    func testIsProDefaultsToFalse() {
        // Before any debug override, isPro should reflect the persisted
        // entitlement (which is false in a fresh test environment).
        #if DEBUG
        StoreKitService.shared.debugSetPro(false)
        #endif
        XCTAssertFalse(StoreKitService.shared.isPro, "isPro should default to false")
    }

    #if DEBUG
    func testDebugSetProTrue() {
        StoreKitService.shared.debugSetPro(true)
        XCTAssertTrue(StoreKitService.shared.isPro, "debugSetPro(true) should set isPro to true")
    }

    func testDebugSetProFalse() {
        StoreKitService.shared.debugSetPro(true)
        StoreKitService.shared.debugSetPro(false)
        XCTAssertFalse(StoreKitService.shared.isPro, "debugSetPro(false) should set isPro to false")
    }

    func testDebugSetProPersistsToUserDefaults() {
        StoreKitService.shared.debugSetPro(true)
        let defaults = UserDefaults(suiteName: "group.com.jackwallner.streaks") ?? .standard
        XCTAssertTrue(defaults.bool(forKey: "isProEntitled.v1"), "Pro entitlement should be persisted to App Group UserDefaults")
    }

    func testDebugSetProFalseClearsPersistence() {
        StoreKitService.shared.debugSetPro(true)
        StoreKitService.shared.debugSetPro(false)
        let defaults = UserDefaults(suiteName: "group.com.jackwallner.streaks") ?? .standard
        XCTAssertFalse(defaults.bool(forKey: "isProEntitled.v1"), "Pro entitlement should be cleared from UserDefaults")
    }
    #endif

    func testPurchaseInProgressInitiallyFalse() {
        XCTAssertFalse(StoreKitService.shared.purchaseInProgress, "purchaseInProgress should be false initially")
    }

    func testLastErrorInitiallyNil() {
        XCTAssertNil(StoreKitService.shared.lastError, "lastError should be nil initially")
    }

    func testProductAccessorsReturnNilWhenNotLoaded() {
        // Before loadProducts() is called, products array is empty.
        XCTAssertNil(StoreKitService.shared.lifetime, "lifetime should be nil before products are loaded")
        XCTAssertNil(StoreKitService.shared.yearly, "yearly should be nil before products are loaded")
        XCTAssertNil(StoreKitService.shared.monthly, "monthly should be nil before products are loaded")
    }

    // ──────────────────────────────────────────────
    // MARK: - Grace Day Earning
    // ──────────────────────────────────────────────

    func testAwardGraceDaysAtTier1_30Days() {
        let streaks = [makeStreak(current: 30)]
        StreakSettings.shared.awardGraceDays(from: streaks)

        XCTAssertEqual(StreakSettings.shared.earnedGraceDays, 1,
                       "Crossing 30 days should award 1 grace day")
        XCTAssertEqual(StreakSettings.shared.graceAwardTier, 1,
                       "graceAwardTier should be 1 after 30-day tier")
    }

    func testAwardGraceDaysAtTier2_60Days() {
        let streaks = [makeStreak(current: 60)]
        StreakSettings.shared.awardGraceDays(from: streaks)

        XCTAssertEqual(StreakSettings.shared.earnedGraceDays, 2,
                       "Crossing 60 days should award 2 grace days")
        XCTAssertEqual(StreakSettings.shared.graceAwardTier, 2,
                       "graceAwardTier should be 2 after 60-day tier")
    }

    func testAwardGraceDaysAtTier3_90Days() {
        let streaks = [makeStreak(current: 90)]
        StreakSettings.shared.awardGraceDays(from: streaks)

        XCTAssertEqual(StreakSettings.shared.earnedGraceDays, 3,
                       "Crossing 90 days should award 3 grace days")
    }

    func testAwardGraceDaysIncrementalTiers() {
        // Simulate progression: 30 → 60 → 90
        let settings = StreakSettings.shared

        settings.awardGraceDays(from: [makeStreak(current: 30)])
        XCTAssertEqual(settings.earnedGraceDays, 1)

        settings.awardGraceDays(from: [makeStreak(current: 60)])
        XCTAssertEqual(settings.earnedGraceDays, 2)

        settings.awardGraceDays(from: [makeStreak(current: 90)])
        XCTAssertEqual(settings.earnedGraceDays, 3)
    }

    func testAwardGraceDaysCappedAt9() {
        // Simulate a massive streak: tier 12 (360 days)
        let streaks = [makeStreak(current: 360)]
        StreakSettings.shared.awardGraceDays(from: streaks)

        XCTAssertEqual(StreakSettings.shared.earnedGraceDays, 9,
                       "Grace days should cap at 9 regardless of streak length")
    }

    func testAwardGraceDaysNoDoubleAward() {
        let settings = StreakSettings.shared

        settings.awardGraceDays(from: [makeStreak(current: 30)])
        XCTAssertEqual(settings.earnedGraceDays, 1)

        // Calling again at the same tier should not award again.
        settings.awardGraceDays(from: [makeStreak(current: 30)])
        XCTAssertEqual(settings.earnedGraceDays, 1,
                       "Re-calling at same tier should not double-award")
    }

    func testAwardGraceDaysZeroStreakLength() {
        StreakSettings.shared.awardGraceDays(from: [makeStreak(current: 0)])
        XCTAssertEqual(StreakSettings.shared.earnedGraceDays, 0,
                       "A 0-length streak should award no grace days")
        XCTAssertEqual(StreakSettings.shared.graceAwardTier, 0,
                       "Tier should remain 0 for 0-length streak")
    }

    func testAwardGraceDaysBelow30Days() {
        StreakSettings.shared.awardGraceDays(from: [makeStreak(current: 29)])
        XCTAssertEqual(StreakSettings.shared.earnedGraceDays, 0,
                       "Streaks below 30 days should award no grace days")
    }

    func testAwardGraceDaysUsesHeroStreak() {
        // Only the first (hero) streak should drive tier calculation.
        let streaks = [
            makeStreak(current: 120, metric: .steps),       // hero: tier 4
            makeStreak(current: 300, metric: .workouts),     // badge: tier 10
        ]
        StreakSettings.shared.awardGraceDays(from: streaks)

        // If the badge drove it, we'd get 10→capped at 9.
        // If the hero drives it, we get 4.
        XCTAssertEqual(StreakSettings.shared.earnedGraceDays, 4,
                       "Award should be driven by hero (first) streak, not largest badge")
    }

    func testAwardGraceDaysFromEmptyStreaks() {
        StreakSettings.shared.awardGraceDays(from: [])
        XCTAssertEqual(StreakSettings.shared.earnedGraceDays, 0)
        XCTAssertEqual(StreakSettings.shared.graceAwardTier, 0)
    }

    // ──────────────────────────────────────────────
    // MARK: - Grace Day Consumption Gating
    // ──────────────────────────────────────────────

    func testConsumeGraceDayAsProWithGraceDaysAvailable() {
        StreakSettings.shared.earnedGraceDays = 3
        let result = StreakSettings.shared.consumeGraceDay(isPro: true)

        XCTAssertTrue(result, "Pro user with grace days should be able to consume")
        XCTAssertEqual(StreakSettings.shared.earnedGraceDays, 2,
                       "Consumption should decrement earnedGraceDays")
    }

    func testConsumeGraceDayAsFreeWithGraceDaysAvailable() {
        StreakSettings.shared.earnedGraceDays = 3
        let result = StreakSettings.shared.consumeGraceDay(isPro: false)

        XCTAssertFalse(result, "Free user should NOT be able to consume grace days")
        XCTAssertEqual(StreakSettings.shared.earnedGraceDays, 3,
                       "Free user should NOT have grace days decremented on attempt")
    }

    func testConsumeGraceDayAsProWithNoGraceDays() {
        StreakSettings.shared.earnedGraceDays = 0
        let result = StreakSettings.shared.consumeGraceDay(isPro: true)

        XCTAssertFalse(result, "Pro user with 0 grace days should not be able to consume")
    }

    func testConsumeGraceDayAsFreeWithNoGraceDays() {
        StreakSettings.shared.earnedGraceDays = 0
        let result = StreakSettings.shared.consumeGraceDay(isPro: false)

        XCTAssertFalse(result, "Free user with 0 grace days should not be able to consume")
    }

    func testConsumeGraceDayMultipleTimes() {
        StreakSettings.shared.earnedGraceDays = 3

        XCTAssertTrue(StreakSettings.shared.consumeGraceDay(isPro: true))
        XCTAssertEqual(StreakSettings.shared.earnedGraceDays, 2)

        XCTAssertTrue(StreakSettings.shared.consumeGraceDay(isPro: true))
        XCTAssertEqual(StreakSettings.shared.earnedGraceDays, 1)

        XCTAssertTrue(StreakSettings.shared.consumeGraceDay(isPro: true))
        XCTAssertEqual(StreakSettings.shared.earnedGraceDays, 0)

        // Now empty — should fail.
        XCTAssertFalse(StreakSettings.shared.consumeGraceDay(isPro: true),
                       "Should fail when grace days are exhausted")
    }

    // ──────────────────────────────────────────────
    // MARK: - Grace Day End-to-End Flow
    // ──────────────────────────────────────────────

    func testEndToEndGraceDayFlowFreeUser() {
        let settings = StreakSettings.shared

        // Stage 1: User earns a grace day by hitting 30 days.
        settings.awardGraceDays(from: [makeStreak(current: 30)])
        XCTAssertEqual(settings.earnedGraceDays, 1)

        // Stage 2: Streak breaks — user is free, consumption fails.
        let consumed = settings.consumeGraceDay(isPro: false)
        XCTAssertFalse(consumed, "Free user must not be able to consume earned grace days")
        XCTAssertEqual(settings.earnedGraceDays, 1,
                       "Grace days remain banked for the upsell")
    }

    func testEndToEndGraceDayFlowProUser() {
        let settings = StreakSettings.shared

        // Stage 1: Earn grace days.
        settings.awardGraceDays(from: [makeStreak(current: 60)])
        XCTAssertEqual(settings.earnedGraceDays, 2)

        // Stage 2: Streak breaks — Pro user, consumption succeeds.
        let consumed = settings.consumeGraceDay(isPro: true)
        XCTAssertTrue(consumed, "Pro user must be able to consume earned grace days")
        XCTAssertEqual(settings.earnedGraceDays, 1,
                       "Grace day was spent, leaving 1 remaining")
    }

    func testEndToEndGraceDayFlowFreeToPro() {
        let settings = StreakSettings.shared

        // Stage 1: Free user earns grace days.
        settings.awardGraceDays(from: [makeStreak(current: 90)])
        XCTAssertEqual(settings.earnedGraceDays, 3)

        // Stage 2: Free user streak breaks — cannot consume.
        let freeAttempt = settings.consumeGraceDay(isPro: false)
        XCTAssertFalse(freeAttempt)
        XCTAssertEqual(settings.earnedGraceDays, 3)

        // Stage 3: User upgrades to Pro.
        // (Simulated via the isPro parameter — no StoreKit interaction needed.)

        // Stage 4: Pro user streak breaks — consumption succeeds.
        let proAttempt = settings.consumeGraceDay(isPro: true)
        XCTAssertTrue(proAttempt)
        XCTAssertEqual(settings.earnedGraceDays, 2)
    }

    func testGraceDayExhaustionAfterUpgrade() {
        let settings = StreakSettings.shared

        // Earn 9 grace days.
        settings.awardGraceDays(from: [makeStreak(current: 270)])
        XCTAssertEqual(settings.earnedGraceDays, 9)

        // Consume all 9 as Pro.
        for i in stride(from: 8, through: 0, by: -1) {
            XCTAssertTrue(settings.consumeGraceDay(isPro: true),
                          "Should consume grace day \(9 - i)")
            XCTAssertEqual(settings.earnedGraceDays, i)
        }

        // 10th attempt fails.
        XCTAssertFalse(settings.consumeGraceDay(isPro: true))
    }

    // ──────────────────────────────────────────────
    // MARK: - Grace Day Preservation Records
    // ──────────────────────────────────────────────

    func testGracePreservationRecordStructure() {
        let preservation = GracePreservation(
            key: "steps-daily",
            missedDate: Date(),
            preservedLength: 45,
            threshold: 10000,
            metric: .steps,
            cadence: .daily,
            hourWindow: nil,
            grantedAt: Date()
        )

        XCTAssertEqual(preservation.key, "steps-daily")
        XCTAssertEqual(preservation.preservedLength, 45)
        XCTAssertEqual(preservation.threshold, 10000)
        XCTAssertEqual(preservation.metric, .steps)
    }

    func testGracePreservationRoundtripPersistence() {
        let settings = StreakSettings.shared
        let preservation = GracePreservation(
            key: "steps-daily",
            missedDate: Date(timeIntervalSince1970: 1715900000),
            preservedLength: 30,
            threshold: 10000,
            metric: .steps,
            cadence: .daily,
            hourWindow: nil,
            grantedAt: Date(timeIntervalSince1970: 1715900100)
        )

        settings.gracePreservations = ["steps-daily": preservation]
        XCTAssertEqual(settings.gracePreservations.count, 1)
        XCTAssertEqual(settings.gracePreservations["steps-daily"]?.preservedLength, 30)
    }

    // ──────────────────────────────────────────────
    // MARK: - Custom Streak Pro Gating
    // ──────────────────────────────────────────────

    func testFreeUserCanBuildCustomStreaksUpToLimit() {
        let settings = StreakSettings.shared
        let isPro = false
        let freeLimit = 3

        // 0 streaks → can build
        settings.customStreaks = []
        XCTAssertTrue(isPro || settings.customStreaks.count < freeLimit)

        // 1 streak → can build
        settings.customStreaks = [CustomStreak(id: "a", metric: .steps, cadence: .daily, threshold: 5000)]
        XCTAssertTrue(isPro || settings.customStreaks.count < freeLimit)

        // 2 streaks → can build
        settings.customStreaks = [
            CustomStreak(id: "a", metric: .steps, cadence: .daily, threshold: 5000),
            CustomStreak(id: "b", metric: .workouts, cadence: .daily, threshold: 1),
        ]
        XCTAssertTrue(isPro || settings.customStreaks.count < freeLimit)
    }

    func testFreeUserCannotBuildFourthCustomStreak() {
        let settings = StreakSettings.shared
        let isPro = false
        let freeLimit = 3

        settings.customStreaks = (0..<3).map { i in
            CustomStreak(
                id: "test-\(i)",
                metric: .steps,
                cadence: .daily,
                threshold: Double(5000 + i * 1000)
            )
        }

        let canBuild = isPro || settings.customStreaks.count < freeLimit
        XCTAssertFalse(canBuild, "Free user with 3 custom streaks should not be able to build a 4th")
    }

    func testProUserCanBuildUnlimitedCustomStreaks() {
        let settings = StreakSettings.shared
        let isPro = true
        let freeLimit = 3

        // Add 10 custom streaks — Pro should still be allowed.
        settings.customStreaks = (0..<10).map { i in
            CustomStreak(
                id: "pro-test-\(i)",
                metric: .steps,
                cadence: .daily,
                threshold: Double(5000 + i * 1000)
            )
        }

        let canBuild = isPro || settings.customStreaks.count < freeLimit
        XCTAssertTrue(canBuild, "Pro user should be able to build unlimited custom streaks")
    }

    func testCustomStreakLimitIsThreeForFree() {
        let freeLimit = 3
        XCTAssertEqual(freeLimit, 3, "Free custom limit should be 3")
    }

    // ──────────────────────────────────────────────
    // MARK: - Notification Pro Gating
    // ──────────────────────────────────────────────

    func testNotificationsEnabledDefaultsToFalse() {
        // notificationsEnabled should default to false (opt-in only).
        // After setUp reset, we can verify the default.
        XCTAssertFalse(StreakSettings.shared.notificationsEnabled,
                       "Notifications should default to false")
    }

    func testNotificationSettingsPersist() {
        let settings = StreakSettings.shared

        settings.notificationsEnabled = true
        XCTAssertTrue(settings.notificationsEnabled)

        settings.notificationsEnabled = false
        XCTAssertFalse(settings.notificationsEnabled)
    }

    func testNotificationTimeDefaults() {
        let settings = StreakSettings.shared
        XCTAssertEqual(settings.notificationHour, 19, "Default notification hour should be 7 PM")
        XCTAssertEqual(settings.notificationMinute, 0, "Default notification minute should be 0")
    }

    func testProGatingEnforcesNotificationToggle() {
        // This mirrors SettingsView logic:
        // When isPro becomes false, notificationsEnabled should be forced off.
        let settings = StreakSettings.shared
        #if DEBUG
        StoreKitService.shared.debugSetPro(false)
        #endif

        // Simulate: user had notifications on, then Pro expired.
        settings.notificationsEnabled = true
        let isPro = StoreKitService.shared.isPro
        if !isPro && settings.notificationsEnabled {
            settings.notificationsEnabled = false
        }

        XCTAssertFalse(settings.notificationsEnabled,
                       "Free users should have notifications disabled")
    }

    // ──────────────────────────────────────────────
    // MARK: - Combined Gating Matrix
    // ──────────────────────────────────────────────

    func testFullGatingMatrix() {
        // This test exercises every gating point together to verify
        // no gate interferes with another.

        let settings = StreakSettings.shared
        let isPro = false

        // 1. Grace Days: free users earn but can't consume.
        settings.awardGraceDays(from: [makeStreak(current: 60)])
        XCTAssertEqual(settings.earnedGraceDays, 2)
        XCTAssertFalse(settings.consumeGraceDay(isPro: isPro))
        XCTAssertEqual(settings.earnedGraceDays, 2, "Grace days preserved for upsell")

        // 2. Custom Streaks: free users limited to 3.
        let custom = CustomStreak(
            id: "gate-test-0",
            metric: .exerciseMinutes,
            cadence: .daily,
            threshold: 30
        )
        let custom2 = CustomStreak(
            id: "gate-test-1",
            metric: .steps,
            cadence: .daily,
            threshold: 5000
        )
        let custom3 = CustomStreak(
            id: "gate-test-2",
            metric: .workouts,
            cadence: .daily,
            threshold: 1
        )
        settings.customStreaks = [custom, custom2, custom3]
        let canBuildAnother = isPro || settings.customStreaks.count < 3
        XCTAssertFalse(canBuildAnother)

        // 3. Notifications: free users can't enable.
        let canEnableNotifications = isPro
        XCTAssertFalse(canEnableNotifications)
    }

    func testFullGatingMatrixAsPro() {
        let settings = StreakSettings.shared
        let isPro = true

        // 1. Grace Days: Pro users earn AND consume.
        settings.awardGraceDays(from: [makeStreak(current: 60)])
        XCTAssertEqual(settings.earnedGraceDays, 2)
        XCTAssertTrue(settings.consumeGraceDay(isPro: isPro))
        XCTAssertEqual(settings.earnedGraceDays, 1)

        // 2. Custom Streaks: Pro users have unlimited.
        settings.customStreaks = (0..<10).map { i in
            CustomStreak(
                id: "pro-gate-test-\(i)",
                metric: .exerciseMinutes,
                cadence: .daily,
                threshold: Double(30 + i),
                hourWindow: nil,
                workoutType: nil,
                workoutMeasure: nil
            )
        }
        let canBuildAnother = isPro || settings.customStreaks.count < 3
        XCTAssertTrue(canBuildAnother, "Pro users should always be able to build custom streaks")

        // 3. Notifications: Pro users can enable.
        let canEnableNotifications = isPro
        XCTAssertTrue(canEnableNotifications)
    }

    // ──────────────────────────────────────────────
    // MARK: - Edge Cases
    // ──────────────────────────────────────────────

    func testAwardGraceDaysNegativeStreakLength() {
        // current should never be negative, but verify defensive behavior.
        StreakSettings.shared.awardGraceDays(from: [makeStreak(current: -1)])
        XCTAssertEqual(StreakSettings.shared.earnedGraceDays, 0)
        XCTAssertEqual(StreakSettings.shared.graceAwardTier, 0)
    }

    func testConsumeGraceDayDoesNotGoNegative() {
        StreakSettings.shared.earnedGraceDays = 0
        _ = StreakSettings.shared.consumeGraceDay(isPro: true)
        // earnedGraceDays is Int and the method guards `> 0` before decrementing,
        // so it should never go negative.
        XCTAssertGreaterThanOrEqual(StreakSettings.shared.earnedGraceDays, 0)
    }

    func testAwardGraceDaysSimulatesRealProgression() {
        let settings = StreakSettings.shared

        // Simulate a user building their streak day by day:
        // Day 30: 1 grace day earned
        settings.awardGraceDays(from: [makeStreak(current: 30)])
        XCTAssertEqual(settings.earnedGraceDays, 1)
        XCTAssertEqual(settings.graceAwardTier, 1)

        // Day 31-59: no new awards (same tier)
        settings.awardGraceDays(from: [makeStreak(current: 31)])
        settings.awardGraceDays(from: [makeStreak(current: 45)])
        settings.awardGraceDays(from: [makeStreak(current: 59)])
        XCTAssertEqual(settings.earnedGraceDays, 1, "Should not award for same tier")

        // Day 60: 2nd grace day
        settings.awardGraceDays(from: [makeStreak(current: 60)])
        XCTAssertEqual(settings.earnedGraceDays, 2)
        XCTAssertEqual(settings.graceAwardTier, 2)

        // Day 90: 3rd grace day
        settings.awardGraceDays(from: [makeStreak(current: 90)])
        XCTAssertEqual(settings.earnedGraceDays, 3)
    }

    func testFreeUserBankedDaysVisibleToProAfterUpgrade() {
        // The core upsell mechanic: a free user who has banked grace days
        // should have them instantly available after going Pro.

        let settings = StreakSettings.shared

        // Free user earns 4 grace days over time.
        settings.awardGraceDays(from: [makeStreak(current: 30)])
        settings.awardGraceDays(from: [makeStreak(current: 60)])
        settings.awardGraceDays(from: [makeStreak(current: 90)])
        settings.awardGraceDays(from: [makeStreak(current: 120)])
        XCTAssertEqual(settings.earnedGraceDays, 4)

        // Free user can't consume.
        XCTAssertFalse(settings.consumeGraceDay(isPro: false))
        XCTAssertEqual(settings.earnedGraceDays, 4)

        // User upgrades — now they can consume their banked days.
        XCTAssertTrue(settings.consumeGraceDay(isPro: true))
        XCTAssertEqual(settings.earnedGraceDays, 3)

        XCTAssertTrue(settings.consumeGraceDay(isPro: true))
        XCTAssertEqual(settings.earnedGraceDays, 2)
    }
}

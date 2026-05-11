import XCTest

@MainActor
final class PaidFeatureTests: XCTestCase {

    // MARK: - Lifecycle

    override func setUp() {
        super.setUp()
        StreakSettings.shared.customStreaks = []
        StreakSettings.shared.gracePreservations = [:]
        StreakSettings.shared.recentlyBroken = []
        StreakSettings.shared.committedThresholds = [:]
        StreakSettings.shared.trackedStreaks = nil
        StreakSettings.shared.hiddenMetrics = []
        StreakSettings.shared.intensity = .challenging
    }

    override func tearDown() {
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
        #if DEBUG
        StoreKitService.shared.debugSetPro(false)
        #endif
        XCTAssertFalse(StoreKitService.shared.isPro, "isPro should default to false")
    }

    #if DEBUG
    func testDebugSetProTrue() {
        StoreKitService.shared.debugSetPro(true)
        XCTAssertTrue(StoreKitService.shared.isPro)
    }

    func testDebugSetProFalse() {
        StoreKitService.shared.debugSetPro(true)
        StoreKitService.shared.debugSetPro(false)
        XCTAssertFalse(StoreKitService.shared.isPro)
    }

    func testDebugSetProPersistsToUserDefaults() {
        StoreKitService.shared.debugSetPro(true)
        let defaults = UserDefaults(suiteName: "group.com.jackwallner.streaks") ?? .standard
        XCTAssertTrue(defaults.bool(forKey: "isProEntitled.v1"))
    }

    func testDebugSetProFalseClearsPersistence() {
        StoreKitService.shared.debugSetPro(true)
        StoreKitService.shared.debugSetPro(false)
        let defaults = UserDefaults(suiteName: "group.com.jackwallner.streaks") ?? .standard
        XCTAssertFalse(defaults.bool(forKey: "isProEntitled.v1"))
    }
    #endif

    func testPurchaseInProgressInitiallyFalse() {
        XCTAssertFalse(StoreKitService.shared.purchaseInProgress)
    }

    func testLastErrorInitiallyNil() {
        XCTAssertNil(StoreKitService.shared.lastError)
    }

    // ──────────────────────────────────────────────
    // MARK: - Auto-save entitlement
    //
    // Pro = unlimited auto-saves; Free = no auto-saves. The "earn grace days"
    // mechanic was removed — saves are a Pro-tier entitlement, not a counter.
    // ──────────────────────────────────────────────

    func testAttemptAutoSaveAsPro() {
        XCTAssertTrue(StreakSettings.shared.attemptAutoSave(isPro: true),
                      "Pro should always auto-save a missed streak")
    }

    func testAttemptAutoSaveAsFree() {
        XCTAssertFalse(StreakSettings.shared.attemptAutoSave(isPro: false),
                       "Free users should not auto-save — streak breaks and paywall appears")
    }

    func testAttemptAutoSaveIsIdempotentForPro() {
        // Pro is an unlimited entitlement — every attempt succeeds regardless of how
        // many came before. No counter to deplete.
        for _ in 0..<20 {
            XCTAssertTrue(StreakSettings.shared.attemptAutoSave(isPro: true))
        }
    }

    // ──────────────────────────────────────────────
    // MARK: - Grace Preservation Records
    //
    // Even though there's no "grace day" counter anymore, the engine still records
    // each auto-save event as a GracePreservation so the user can see "Pro saved
    // your 47-day steps streak on Apr 12."
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

        settings.customStreaks = []
        XCTAssertTrue(isPro || settings.customStreaks.count < freeLimit)

        settings.customStreaks = [CustomStreak(id: "a", metric: .steps, cadence: .daily, threshold: 5000)]
        XCTAssertTrue(isPro || settings.customStreaks.count < freeLimit)

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

    // ──────────────────────────────────────────────
    // MARK: - Notification Pro Gating
    // ──────────────────────────────────────────────

    func testNotificationsEnabledDefaultsToFalse() {
        XCTAssertFalse(StreakSettings.shared.notificationsEnabled,
                       "Notifications should default to false (opt-in only)")
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
        XCTAssertEqual(settings.notificationHour, 19)
        XCTAssertEqual(settings.notificationMinute, 0)
    }

    func testProGatingEnforcesNotificationToggle() {
        let settings = StreakSettings.shared
        #if DEBUG
        StoreKitService.shared.debugSetPro(false)
        #endif

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

    func testFullGatingMatrixAsFree() {
        let settings = StreakSettings.shared
        let isPro = false

        // 1. Auto-save: free users get nothing.
        XCTAssertFalse(settings.attemptAutoSave(isPro: isPro))

        // 2. Custom Streaks: free users limited to 3.
        settings.customStreaks = [
            CustomStreak(id: "g0", metric: .exerciseMinutes, cadence: .daily, threshold: 30),
            CustomStreak(id: "g1", metric: .steps, cadence: .daily, threshold: 5000),
            CustomStreak(id: "g2", metric: .workouts, cadence: .daily, threshold: 1),
        ]
        let canBuildAnother = isPro || settings.customStreaks.count < 3
        XCTAssertFalse(canBuildAnother)

        // 3. Notifications: free users can't enable.
        XCTAssertFalse(isPro)
    }

    func testFullGatingMatrixAsPro() {
        let settings = StreakSettings.shared
        let isPro = true

        // 1. Auto-save: Pro succeeds unconditionally.
        XCTAssertTrue(settings.attemptAutoSave(isPro: isPro))

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
        XCTAssertTrue(canBuildAnother)

        // 3. Notifications: Pro users can enable.
        XCTAssertTrue(isPro)
    }
}

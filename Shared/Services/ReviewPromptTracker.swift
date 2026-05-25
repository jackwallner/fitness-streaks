import Foundation

/// Persists review-prompt eligibility and outcomes in the app group.
@MainActor
enum ReviewPromptTracker {
    enum Outcome: String {
        case openedWriteReview
        case submittedFeedback
    }

    private static let defaults = UserDefaults(suiteName: streaksAppGroupID) ?? .standard

    private enum Key {
        static let launchCount = "reviewPrompt.appLaunchCount"
        static let firstOpenDate = "reviewPrompt.firstAppOpenDate"
        static let lastNotNowDate = "reviewPrompt.lastNotNowDate"
        static let outcome = "reviewPrompt.outcome"
        static let positiveMomentCount = "reviewPrompt.positiveMomentCount"
        static let pendingPositiveMoment = "reviewPrompt.pendingPositiveMoment"
        static let sessionPromptShown = "reviewPrompt.sessionPromptShown"
        static let pendingNativeReview = "reviewPrompt.pendingNativeReview"
    }

    #if DEBUG
    private static let minimumLaunchCount = 2
    private static let minimumDaysSinceFirstOpen = 0
    #else
    private static let minimumLaunchCount = 5
    private static let minimumDaysSinceFirstOpen = 7
    #endif

    private static let notNowCooldownDays = 120
    private static let minimumPositiveMoments = 1

    static var skipsAutomation: Bool {
        ProcessInfo.processInfo.arguments.contains(where: {
            $0.hasPrefix("-UITest") || $0 == "-FASTLANE_SNAPSHOT"
        })
    }

    // MARK: - Recording

    static func recordAppLaunch() {
        guard !skipsAutomation else { return }
        let count = defaults.integer(forKey: Key.launchCount) + 1
        defaults.set(count, forKey: Key.launchCount)
        if defaults.object(forKey: Key.firstOpenDate) == nil {
            defaults.set(Date().timeIntervalSince1970, forKey: Key.firstOpenDate)
        }
    }

    static func recordPositiveMoment() {
        guard !skipsAutomation else { return }
        let count = defaults.integer(forKey: Key.positiveMomentCount) + 1
        defaults.set(count, forKey: Key.positiveMomentCount)
        defaults.set(true, forKey: Key.pendingPositiveMoment)
    }

    // MARK: - Eligibility

    static func canPresentEnjoymentPrompt(
        hasCompletedSetup: Bool,
        bypassPassiveGates: Bool = false
    ) -> Bool {
        guard !skipsAutomation else { return false }
        if let outcome = loadOutcome() {
            switch outcome {
            case .openedWriteReview, .submittedFeedback:
                return false
            }
        }
        guard hasCompletedSetup else { return false }
        if bypassPassiveGates {
            return true
        }

        guard !defaults.bool(forKey: Key.sessionPromptShown) else { return false }
        guard defaults.integer(forKey: Key.launchCount) >= minimumLaunchCount else { return false }

        if let firstOpen = firstOpenDate {
            let days = Calendar.current.dateComponents([.day], from: firstOpen, to: Date()).day ?? 0
            guard days >= minimumDaysSinceFirstOpen else { return false }
        }

        if let lastNotNow = lastNotNowDate {
            let days = Calendar.current.dateComponents([.day], from: lastNotNow, to: Date()).day ?? 0
            guard days >= notNowCooldownDays else { return false }
        }

        let hasMoment = defaults.bool(forKey: Key.pendingPositiveMoment)
            || defaults.integer(forKey: Key.positiveMomentCount) >= minimumPositiveMoments
        guard hasMoment else { return false }

        return true
    }

    // MARK: - Outcomes

    static func markShown() {
        defaults.set(true, forKey: Key.sessionPromptShown)
        defaults.set(false, forKey: Key.pendingPositiveMoment)
    }

    static func markNotNow() {
        defaults.set(Date().timeIntervalSince1970, forKey: Key.lastNotNowDate)
        defaults.set(true, forKey: Key.sessionPromptShown)
        defaults.set(false, forKey: Key.pendingPositiveMoment)
    }

    static func markOpenedWriteReview() {
        saveOutcome(.openedWriteReview)
        defaults.set(false, forKey: Key.pendingPositiveMoment)
    }

    static func markFeedbackSubmitted() {
        saveOutcome(.submittedFeedback)
        defaults.set(false, forKey: Key.pendingPositiveMoment)
    }

    static func pendingNativeReviewRequested() -> Bool {
        defaults.bool(forKey: Key.pendingNativeReview)
    }

    static func setPendingNativeReview(_ pending: Bool) {
        defaults.set(pending, forKey: Key.pendingNativeReview)
    }

    // MARK: - Private

    private static var firstOpenDate: Date? {
        guard let ts = defaults.object(forKey: Key.firstOpenDate) as? TimeInterval else { return nil }
        return Date(timeIntervalSince1970: ts)
    }

    private static var lastNotNowDate: Date? {
        guard let ts = defaults.object(forKey: Key.lastNotNowDate) as? TimeInterval else { return nil }
        return Date(timeIntervalSince1970: ts)
    }

    private static func loadOutcome() -> Outcome? {
        guard let raw = defaults.string(forKey: Key.outcome) else { return nil }
        return Outcome(rawValue: raw)
    }

    private static func saveOutcome(_ outcome: Outcome) {
        defaults.set(outcome.rawValue, forKey: Key.outcome)
        defaults.set(true, forKey: Key.sessionPromptShown)
    }
}

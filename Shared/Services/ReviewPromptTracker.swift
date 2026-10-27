import Foundation

/// Persists rating-ask eligibility in the app group. The ask itself is the
/// system `requestReview()` with no question in front of it (App Review 5.6.1).
@MainActor
enum ReviewPromptTracker {
    /// What the user did about a review. Only opening the review page ends the
    /// passive asks: someone who sent feedback can still rate.
    enum Outcome: String {
        case openedWriteReview
        /// Sent feedback by mail. Never stops the asks.
        case submittedFeedback
    }

    private static let defaults = UserDefaults(suiteName: streaksAppGroupID) ?? .standard

    private enum Key {
        static let launchCount = "reviewPrompt.appLaunchCount"
        static let firstOpenDate = "reviewPrompt.firstAppOpenDate"
        static let lastShownDate = "reviewPrompt.lastShownDate"
        /// Written by the old enjoyment sheet's "Not now". Read only as a
        /// cooldown fallback so an upgrade doesn't ask again right away.
        static let legacyNotNowDate = "reviewPrompt.lastNotNowDate"
        static let outcome = "reviewPrompt.outcome"
        static let positiveMomentCount = "reviewPrompt.positiveMomentCount"
        static let pendingPositiveMoment = "reviewPrompt.pendingPositiveMoment"
    }

    /// Ask early. Most installs are gone within a week, and a rating from
    /// someone whose streak grew twice beats no rating at all. The only tenure
    /// gate is "not the first session": a second cold start.
    static let minimumLaunchCount = 2
    /// Days between our calls. Apple shows the prompt at most three times a
    /// year per device and decides each time, so this paces the asks rather
    /// than the user's answers.
    static let cooldownDays = 30

    static var skipsAutomation: Bool {
        #if DEBUG
        return ProcessInfo.processInfo.arguments.contains(where: {
            $0.hasPrefix("-UITest") || $0 == "-FASTLANE_SNAPSHOT"
        })
        #else
        return false
        #endif
    }

    // MARK: - State

    static var appLaunchCount: Int {
        get { max(defaults.integer(forKey: Key.launchCount), 0) }
        set { defaults.set(newValue, forKey: Key.launchCount) }
    }

    static var lastShownDate: Date? {
        get {
            let stored = defaults.object(forKey: Key.lastShownDate) as? TimeInterval
                ?? defaults.object(forKey: Key.legacyNotNowDate) as? TimeInterval
            return stored.map(Date.init(timeIntervalSince1970:))
        }
        set {
            defaults.removeObject(forKey: Key.legacyNotNowDate)
            if let date = newValue {
                defaults.set(date.timeIntervalSince1970, forKey: Key.lastShownDate)
            } else {
                defaults.removeObject(forKey: Key.lastShownDate)
            }
        }
    }

    static var outcome: Outcome? {
        get { defaults.string(forKey: Key.outcome).flatMap(Outcome.init(rawValue:)) }
        set {
            if let value = newValue {
                defaults.set(value.rawValue, forKey: Key.outcome)
            } else {
                defaults.removeObject(forKey: Key.outcome)
            }
        }
    }

    static var hasPendingPositiveMoment: Bool {
        get { defaults.bool(forKey: Key.pendingPositiveMoment) }
        set { defaults.set(newValue, forKey: Key.pendingPositiveMoment) }
    }

    // MARK: - Recording

    static func recordAppLaunch() {
        guard !skipsAutomation else { return }
        appLaunchCount += 1
        if defaults.object(forKey: Key.firstOpenDate) == nil {
            defaults.set(Date().timeIntervalSince1970, forKey: Key.firstOpenDate)
        }
    }

    static func recordPositiveMoment() {
        guard !skipsAutomation else { return }
        let count = defaults.integer(forKey: Key.positiveMomentCount) + 1
        defaults.set(count, forKey: Key.positiveMomentCount)
        hasPendingPositiveMoment = true
    }

    // MARK: - Eligibility

    static func passivePromptAllowed(now: Date = .now) -> Bool {
        guard outcome != .openedWriteReview else { return false }
        guard let last = lastShownDate else { return true }
        return now.timeIntervalSince(last) >= TimeInterval(cooldownDays) * 86_400
    }

    static func canRequestReview(hasCompletedSetup: Bool, now: Date = .now) -> Bool {
        guard !skipsAutomation else { return false }
        guard hasCompletedSetup else { return false }
        guard passivePromptAllowed(now: now) else { return false }
        return appLaunchCount >= minimumLaunchCount
    }

    static func shouldRequestAfterPositiveMoment(hasCompletedSetup: Bool, now: Date = .now) -> Bool {
        guard hasPendingPositiveMoment else { return false }
        return canRequestReview(hasCompletedSetup: hasCompletedSetup, now: now)
    }

    // MARK: - Outcomes

    static func markShown(now: Date = .now) {
        lastShownDate = now
        hasPendingPositiveMoment = false
    }

    static func markOpenedWriteReview() {
        outcome = .openedWriteReview
        markShown()
    }

    /// Never overwrites `.openedWriteReview`: feedback sent after the review
    /// page must not reopen the asks that page ended.
    static func markFeedbackSubmitted() {
        if outcome != .openedWriteReview {
            outcome = .submittedFeedback
        }
    }
}

import Foundation

/// Which top-level screen the Watch app shows.
enum WatchRootScreen: Equatable {
    case setup
    case streaks

    /// App Group storage is per device, so the iPhone's `hasCompletedSetup` never
    /// reaches the Watch. A snapshot synced from the iPhone is the real signal.
    static func resolve(hasCompletedSetup: Bool, hasSnapshot: Bool) -> WatchRootScreen {
        hasSnapshot || hasCompletedSetup ? .streaks : .setup
    }
}

enum SetupGate {
    /// Whether a launch should send a user who finished setup back to onboarding.
    /// Only when Health was never requested on this device and nothing was ever
    /// cached. A user who stayed away for weeks, or a store that fell back to
    /// memory, keeps their setup.
    static func shouldRestartOnboarding(
        hasCompletedSetup: Bool,
        hasAnyCachedDay: Bool,
        healthNeverRequested: Bool?
    ) -> Bool {
        guard hasCompletedSetup, !hasAnyCachedDay else { return false }
        return healthNeverRequested == true
    }
}

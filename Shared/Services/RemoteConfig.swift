import Foundation

/// Everything RevenueCat can change without a release, read from the current
/// offering's metadata (a running Experiment's variant included). Every
/// variant ships in the binary; a missing, non-string or unknown value is the
/// control, which is what the app shipped before the reader existed. Keys a
/// switch reads must be set the same on every offering, or an Experiment arm
/// would flip them as a side effect. Wording tests go through offering
/// metadata `trial_cta`.
///
/// DEBUG builds can pin any key for captures: `-streaks.rc.<key> <value>`.
///
/// Held as plain `[String: Any]` so the widget, Watch and test targets, which
/// do not link RevenueCat, compile and test it too.

/// Plan shapes the paywall button names.
enum PaywallPlan: Equatable, Sendable {
    case annual, monthly, other
}

/// The trial button's wording on every surface: the onboarding trial page, the
/// trial sheet and the paywall. Only an account that can still start a free
/// trial reaches these strings; the buttons for an account that already used
/// its trial keep their own wording (3.1.2).
enum TrialCTA: String, CaseIterable, Sendable {
    static let metadataKey = "trial_cta"

    /// Control: exactly the copy the app shipped with.
    case control = "seven_day"
    case my
    case your

    static func from(metadata: [String: Any]?) -> TrialCTA {
        RemoteConfig.value(metadataKey, in: metadata, default: .control)
    }

    /// The onboarding trial page's primary button. The button upper-cases it.
    func onboardingButton(trial: TrialLength) -> String {
        switch self {
        case .control: trial.keepAllButton
        case .my: String(localized: "▶ KEEP ALL · START MY FREE TRIAL")
        case .your: String(localized: "▶ KEEP ALL · START YOUR FREE TRIAL")
        }
    }

    /// The trial sheet's primary button. The price sits in its subtitle, so the
    /// recurring price stays the most conspicuous figure (3.1.2).
    var offerSheetTitle: String {
        switch self {
        case .control: String(localized: "START FREE TRIAL")
        case .my: String(localized: "START MY FREE TRIAL")
        case .your: String(localized: "START YOUR FREE TRIAL")
        }
    }

    /// The paywall's primary button for a plan with a free trial. It names the
    /// plan and the recurring price (3.1.2). `days` is the control's trial
    /// length; the arms leave it to the disclosure under the plan.
    func paywallTitle(plan: PaywallPlan, days: Int, price: String, recurringLabel: String) -> String {
        switch (self, plan) {
        case (.control, .annual): String(localized: "START \(days) DAYS FREE · YEARLY \(price)")
        case (.control, .monthly): String(localized: "START \(days) DAYS FREE · MONTHLY \(price)")
        case (.control, .other): String(localized: "START \(days) DAYS FREE · \(recurringLabel) \(price)")
        case (.my, .annual): String(localized: "START MY FREE TRIAL · YEARLY \(price)")
        case (.my, .monthly): String(localized: "START MY FREE TRIAL · MONTHLY \(price)")
        case (.my, .other): String(localized: "START MY FREE TRIAL · \(recurringLabel) \(price)")
        case (.your, .annual): String(localized: "START YOUR FREE TRIAL · YEARLY \(price)")
        case (.your, .monthly): String(localized: "START YOUR FREE TRIAL · MONTHLY \(price)")
        case (.your, .other): String(localized: "START YOUR FREE TRIAL · \(recurringLabel) \(price)")
        }
    }
}

/// Remote off switches, for what is worth pausing without a release. On unless
/// the metadata says "off".
enum RemoteSwitch: String, CaseIterable, Sendable {
    /// Apple's rating prompt after a good moment.
    case ratingPrompt = "rating_prompt"
}

enum RemoteConfig {
    /// The value for `key`, or `fallback` when it is missing, not a string, or
    /// not one of the shipped variants.
    static func value<T: RawRepresentable>(_ key: String, in metadata: [String: Any]?, default fallback: T) -> T
    where T.RawValue == String {
        #if DEBUG
        if let pinned = launchOverride(key).flatMap(T.init(rawValue:)) { return pinned }
        #endif
        guard let raw = metadata?[key] as? String else { return fallback }
        return T(rawValue: raw) ?? fallback
    }

    static func isOn(_ remoteSwitch: RemoteSwitch, in metadata: [String: Any]?) -> Bool {
        #if DEBUG
        if let pinned = launchOverride(remoteSwitch.rawValue) { return pinned != "off" }
        #endif
        return (metadata?[remoteSwitch.rawValue] as? String) != "off"
    }

    #if DEBUG
    private static func launchOverride(_ key: String) -> String? {
        let args = ProcessInfo.processInfo.arguments
        guard let index = args.firstIndex(of: "-streaks.rc.\(key)"), index + 1 < args.count else { return nil }
        return args[index + 1]
    }
    #endif
}

import Foundation
import SwiftUI
import Combine
import WidgetKit

/// How aggressive the user wants the discovered streaks to feel.
/// Drives StreakEngine ranking and hero selection.
enum DiscoveryVibe: Int, CaseIterable, Codable, Sendable {
    case sustainable = 0     // "something I've been doing for a while" — longest lower-tier streak
    case challenging = 1     // "stretch, but hittable" — mid-tier with recent momentum
    case lifeChanging = 2    // "I want the top tier" — highest threshold reachable

    var label: String {
        switch self {
        case .sustainable: "Sustainable"
        case .challenging: "Challenging"
        case .lifeChanging: "Life-changing"
        }
    }

    var tagline: String {
        switch self {
        case .sustainable: "Streaks you've already built. Keep the chain alive."
        case .challenging: "A stretch — but within reach with steady effort."
        case .lifeChanging: "The top tier. Aim high; build toward it."
        }
    }

    var short: String {
        switch self {
        case .sustainable: "already doing"
        case .challenging: "push a little"
        case .lifeChanging: "go big"
        }
    }
}

enum AppAppearance: Int, CaseIterable {
    case system = 0
    case light = 1
    case dark = 2

    var label: String {
        switch self {
        case .system: "System"
        case .light: "Light"
        case .dark: "Dark"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

/// Small cached snapshot of the top streaks so widgets/complications can render instantly
/// without re-running the engine. Written to App Group UserDefaults by the main app/watch.
struct StreakSnapshot: Codable, Sendable {
    struct Item: Codable, Sendable, Identifiable {
        var id: String {
            if let h = hourWindow {
                return "\(metric)-\(cadence)-h\(h)-\(Int(threshold))"
            }
            return "\(metric)-\(cadence)-\(Int(threshold))"
        }
        let metric: String            // raw value of StreakMetric
        let cadence: String           // raw value of StreakCadence
        let threshold: Double
        let current: Int
        let best: Int
        let currentUnitCompleted: Bool
        let currentUnitProgress: Double
        let currentUnitValue: Double
        var hourWindow: Int? = nil    // nil = whole-day; else 0..23 for hour-window streak
    }

    let updated: Date
    let hero: Item?
    let badges: [Item]
}

@MainActor
final class StreakSettings: ObservableObject {
    static let shared = StreakSettings()

    private let defaults: UserDefaults

    @Published var hasCompletedSetup: Bool {
        didSet { defaults.set(hasCompletedSetup, forKey: "hasCompletedSetup") }
    }

    @Published var appearance: AppAppearance {
        didSet { defaults.set(appearance.rawValue, forKey: "appearance") }
    }

    @Published var notificationsEnabled: Bool {
        didSet { defaults.set(notificationsEnabled, forKey: "notificationsEnabled") }
    }

    @Published var vibe: DiscoveryVibe {
        didSet {
            defaults.set(vibe.rawValue, forKey: "discoveryVibe")
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    /// Optional floor — "I want something I've done at least N times".
    /// nil = no minimum preference.
    @Published var minStreakLength: Int? {
        didSet {
            if let v = minStreakLength {
                defaults.set(v, forKey: "minStreakLength")
            } else {
                defaults.removeObject(forKey: "minStreakLength")
            }
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    /// Metrics the user has opted out of. Empty = all on.
    @Published var hiddenMetrics: Set<StreakMetric> {
        didSet {
            let raws = hiddenMetrics.map(\.rawValue)
            defaults.set(raws, forKey: "hiddenMetrics")
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    /// Which discovered streaks the user opted in to track, keyed as "metric-cadence"
    /// (e.g. "steps-daily", "workouts-weekly"). `nil` = not yet chosen → treat as "all on".
    @Published var trackedStreaks: Set<String>? {
        didSet {
            if let set = trackedStreaks {
                defaults.set(Array(set), forKey: "trackedStreaks")
            } else {
                defaults.removeObject(forKey: "trackedStreaks")
            }
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    static func streakKey(metric: StreakMetric, cadence: StreakCadence, window: HourWindow? = nil) -> String {
        if let w = window {
            return "\(metric.rawValue)-\(cadence.rawValue)-h\(w.startHour)"
        }
        return "\(metric.rawValue)-\(cadence.rawValue)"
    }

    func isTracked(metric: StreakMetric, cadence: StreakCadence, window: HourWindow? = nil) -> Bool {
        guard let set = trackedStreaks else { return true }
        return set.contains(Self.streakKey(metric: metric, cadence: cadence, window: window))
    }

    private init() {
        let defaults = UserDefaults(suiteName: DataService.appGroupID) ?? .standard
        self.defaults = defaults

        self.hasCompletedSetup = defaults.bool(forKey: "hasCompletedSetup")
        self.appearance = AppAppearance(rawValue: defaults.integer(forKey: "appearance")) ?? .system
        self.notificationsEnabled = defaults.object(forKey: "notificationsEnabled") as? Bool ?? true
        self.vibe = DiscoveryVibe(rawValue: defaults.integer(forKey: "discoveryVibe")) ?? .challenging
        self.minStreakLength = (defaults.object(forKey: "minStreakLength") as? Int)

        if let raws = defaults.array(forKey: "hiddenMetrics") as? [String] {
            self.hiddenMetrics = Set(raws.compactMap(StreakMetric.init(rawValue:)))
        } else {
            self.hiddenMetrics = []
        }

        if let raws = defaults.array(forKey: "trackedStreaks") as? [String] {
            self.trackedStreaks = Set(raws)
        } else {
            self.trackedStreaks = nil
        }
    }

    func isHidden(_ metric: StreakMetric) -> Bool { hiddenMetrics.contains(metric) }

    func toggle(_ metric: StreakMetric) {
        if hiddenMetrics.contains(metric) {
            hiddenMetrics.remove(metric)
        } else {
            hiddenMetrics.insert(metric)
        }
    }
}

enum SnapshotStore {
    private static let key = "streakSnapshot.v1"

    static func save(_ snapshot: StreakSnapshot) {
        let defaults = UserDefaults(suiteName: streaksAppGroupID) ?? .standard
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults.set(data, forKey: key)
        WidgetCenter.shared.reloadAllTimelines()
    }

    static func load() -> StreakSnapshot? {
        let defaults = UserDefaults(suiteName: streaksAppGroupID) ?? .standard
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(StreakSnapshot.self, from: data)
    }
}

import Foundation
import SwiftUI
import Combine
import WidgetKit

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
        var id: String { "\(metric)-\(cadence)-\(Int(threshold))" }
        let metric: String            // raw value of StreakMetric
        let cadence: String           // raw value of StreakCadence
        let threshold: Double
        let current: Int
        let best: Int
        let currentUnitCompleted: Bool
        let currentUnitProgress: Double
        let currentUnitValue: Double
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

    /// Metrics the user has opted out of. Empty = all on.
    @Published var hiddenMetrics: Set<StreakMetric> {
        didSet {
            let raws = hiddenMetrics.map(\.rawValue)
            defaults.set(raws, forKey: "hiddenMetrics")
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    private init() {
        let defaults = UserDefaults(suiteName: DataService.appGroupID) ?? .standard
        self.defaults = defaults

        self.hasCompletedSetup = defaults.bool(forKey: "hasCompletedSetup")
        self.appearance = AppAppearance(rawValue: defaults.integer(forKey: "appearance")) ?? .system
        self.notificationsEnabled = defaults.object(forKey: "notificationsEnabled") as? Bool ?? true

        if let raws = defaults.array(forKey: "hiddenMetrics") as? [String] {
            self.hiddenMetrics = Set(raws.compactMap(StreakMetric.init(rawValue:)))
        } else {
            self.hiddenMetrics = []
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

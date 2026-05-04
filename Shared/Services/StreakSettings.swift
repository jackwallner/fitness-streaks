import Foundation
import SwiftUI
import Combine
import WidgetKit

/// How aggressive the user wants the discovered streaks to feel.
/// Drives StreakEngine ranking and hero selection.
enum DiscoveryIntensity: Int, CaseIterable, Codable, Sendable {
    case sustainable = 0     // ~80% historical daily completion — easy to maintain
    case challenging = 1     // ~65% historical daily completion — stretch to daily
    case lifeChanging = 2    // ~50% historical daily completion — transformative if daily

    var label: String {
        switch self {
        case .sustainable: "Sustained"
        case .challenging: "Challenging"
        case .lifeChanging: "Life Changing"
        }
    }

    var tagline: String {
        switch self {
        case .sustainable: "Goals you already hit most days. Turn them into unbroken streaks."
        case .challenging: "Goals you hit roughly 2 of 3 days. Push to make them daily."
        case .lifeChanging: "Goals you hit about half the time. Building the daily habit changes everything."
        }
    }

    var short: String {
        switch self {
        case .sustainable: "sustained"
        case .challenging: "challenging"
        case .lifeChanging: "life changing"
        }
    }

    /// Minimum historical daily completion rate used to select a threshold for this intensity.
    var targetCompletionRate: Double {
        switch self {
        case .sustainable: 0.80
        case .challenging: 0.65
        case .lifeChanging: 0.50
        }
    }
}

enum AppAppearance: Int, CaseIterable {
    case light = 0
    case dark = 1
    case system = 2

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
            if let type = workoutType {
                return "\(metric)-\(cadence)-\(type)-\(Int(threshold))"
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
        var customID: String? = nil
        var workoutType: String? = nil  // WorkoutTypeCatalog.Entry.key when this is a per-type streak
        var workoutMeasure: String? = nil // raw of WorkoutMeasure when workoutType is set

        var workoutTypeEntry: WorkoutTypeCatalog.Entry? {
            workoutType.flatMap(WorkoutTypeCatalog.entry(forKey:))
        }
        var workoutMeasureValue: WorkoutMeasure? {
            workoutMeasure.flatMap(WorkoutMeasure.init(rawValue:))
        }
        var streakMetric: StreakMetric? { StreakMetric(rawValue: metric) }
        var streakCadence: StreakCadence { StreakCadence(rawValue: cadence) ?? .daily }

        /// "Cycling" / "Steps" — falls back to the metric name if no workout type.
        var displayName: String {
            if let entry = workoutTypeEntry { return entry.displayName }
            return streakMetric?.displayName ?? metric.capitalized
        }
        /// SF Symbol for the streak; uses the workout-type symbol when applicable.
        var displaySymbol: String {
            if let entry = workoutTypeEntry { return entry.symbol }
            return streakMetric?.symbol ?? "flame.fill"
        }
        /// "20 min cycling" / "10k steps" — short label.
        var thresholdLabel: String {
            if let entry = workoutTypeEntry, let measure = workoutMeasureValue {
                return Streak.workoutThresholdLabel(threshold, entry: entry, measure: measure)
            }
            return streakMetric?.thresholdLabel(threshold, cadence: streakCadence) ?? ""
        }

        var unitLabel: String {
            if let measure = workoutMeasureValue { return measure.unit }
            return streakMetric?.unitLabel ?? ""
        }

        var currentUnitValueLabel: String {
            formatValue(currentUnitValue, rounded: false, compact: false)
        }

        var goalValueLabel: String {
            formatValue(threshold, rounded: true, compact: false)
        }

        var compactCurrentUnitValueLabel: String {
            formatValue(currentUnitValue, rounded: false, compact: true)
        }

        var compactGoalValueLabel: String {
            formatValue(threshold, rounded: true, compact: true)
        }

        var progressValueLabel: String {
            let unit = unitLabel
            let values = "\(currentUnitValueLabel) / \(goalValueLabel)"
            return unit.isEmpty ? values : "\(values) \(unit)"
        }

        private func formatValue(_ value: Double, rounded: Bool, compact: Bool) -> String {
            if compact {
                return Self.compactFormat(value)
            }
            if let measure = workoutMeasureValue {
                switch measure {
                case .count, .minutes:
                    return Self.integerFormat(rounded ? value.rounded() : floor(value))
                case .miles:
                    let displayed = rounded ? value : floor(value * 10) / 10
                    return String(format: displayed < 10 ? "%.1f" : "%.0f", displayed)
                }
            }
            guard let metric = streakMetric else {
                return Self.integerFormat(rounded ? value.rounded() : floor(value))
            }
            switch metric {
            case .sleepHours, .distanceMiles, .intensityRatio:
                let displayed = rounded ? value : floor(value * 10) / 10
                return String(format: displayed < 10 ? "%.1f" : "%.0f", displayed)
            default:
                return Self.integerFormat(rounded ? value.rounded() : floor(value))
            }
        }

        private static func integerFormat(_ value: Double) -> String {
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.maximumFractionDigits = 0
            return formatter.string(from: NSNumber(value: value)) ?? "\(Int(value))"
        }

        private static func compactFormat(_ value: Double) -> String {
            let absValue = abs(value)
            if absValue >= 10_000 {
                return "\(Int((value / 1_000).rounded()))k"
            }
            if absValue >= 1_000 {
                let truncated = floor(value / 100) / 10
                return String(format: truncated.truncatingRemainder(dividingBy: 1) == 0 ? "%.0fk" : "%.1fk", truncated)
            }
            if absValue >= 10 {
                return "\(Int(value.rounded()))"
            }
            let truncated = floor(value * 10) / 10
            return String(format: truncated.truncatingRemainder(dividingBy: 1) == 0 ? "%.0f" : "%.1f", truncated)
        }
    }

    let updated: Date
    let hero: Item?
    let badges: [Item]
    var recentlyBroken: [BrokenStreak] = []
}

struct BrokenStreak: Codable, Sendable, Identifiable, Hashable {
    var id: String { "\(key)-\(Int(brokenAt.timeIntervalSince1970))" }
    let key: String
    let metric: StreakMetric
    let cadence: StreakCadence
    let threshold: Double
    let hourWindow: Int?
    let brokenLength: Int
    let brokenAt: Date
}

struct CustomStreak: Codable, Sendable, Identifiable, Hashable {
    var id: String
    var metric: StreakMetric
    var cadence: StreakCadence
    var threshold: Double
    var hourWindow: Int?
    /// When set, the streak tracks a specific Apple workout activity type instead of all workouts.
    /// Key matches `WorkoutTypeCatalog.Entry.key`.
    var workoutType: String?
    /// What we measure when `workoutType` is set: session count, total minutes, or total miles.
    var workoutMeasure: WorkoutMeasure?

    var trackingKey: String { "custom-\(id)" }
}

@MainActor
final class StreakSettings: ObservableObject {
    static let shared = StreakSettings()

    private let defaults: UserDefaults

    @Published var hasCompletedSetup: Bool {
        didSet { defaults.set(hasCompletedSetup, forKey: "hasCompletedSetup") }
    }

    /// Watch-specific setup flag (separate from iOS because watch doesn't do its own HealthKit auth)
    @Published var hasWatchCompletedSetup: Bool {
        didSet { defaults.set(hasWatchCompletedSetup, forKey: "hasWatchCompletedSetup") }
    }

    @Published var appearance: AppAppearance {
        didSet { defaults.set(appearance.rawValue, forKey: "appearance") }
    }

    @Published var notificationsEnabled: Bool {
        didSet { defaults.set(notificationsEnabled, forKey: "notificationsEnabled") }
    }

    @Published var notificationHour: Int {
        didSet { defaults.set(notificationHour, forKey: "notificationHour") }
    }

    @Published var notificationMinute: Int {
        didSet { defaults.set(notificationMinute, forKey: "notificationMinute") }
    }

    @Published var earnedGraceDays: Int {
        didSet { defaults.set(earnedGraceDays, forKey: "earnedGraceDays") }
    }

    @Published var graceAwardTier: Int {
        didSet { defaults.set(graceAwardTier, forKey: "graceAwardTier") }
    }

    @Published var intensity: DiscoveryIntensity {
        didSet {
            defaults.set(intensity.rawValue, forKey: "discoveryVibe")
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    /// How many days of history to consider when computing completion rates.
    /// Default 30; range 7–365.
    @Published var lookbackDays: Int {
        didSet {
            defaults.set(lookbackDays, forKey: "lookbackDays")
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
    /// (e.g. "steps-daily", "workouts-daily"). `nil` = not yet chosen → treat as "all on".
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

    @Published var committedThresholds: [String: Double] {
        didSet { saveCodable(committedThresholds, key: "committedThresholds") }
    }

    @Published var customStreaks: [CustomStreak] {
        didSet {
            saveCodable(customStreaks, key: "customStreaks")
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    @Published var recentlyBroken: [BrokenStreak] {
        didSet {
            saveCodable(recentlyBroken, key: "recentlyBroken")
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    @Published var gracePreservations: [String: GracePreservation] {
        didSet { saveCodable(gracePreservations, key: "gracePreservations") }
    }

    /// Manual ordering of streak tracking keys. First = hero, rest = badges in order.
    /// Streaks not in this list are sorted by engine score after listed ones.
    @Published var manualStreakOrder: [String] {
        didSet {
            saveCodable(manualStreakOrder, key: "manualStreakOrder")
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    /// Last-known `current` for each tracked streak, persisted between launches so we can
    /// detect breaks even after a cold start (when the in-memory `previous` array is empty).
    /// Keyed by `Streak.trackingKey`.
    @Published var lastKnownStreakLengths: [String: Int] {
        didSet { saveCodable(lastKnownStreakLengths, key: "lastKnownStreakLengths") }
    }

    nonisolated static func streakKey(metric: StreakMetric, cadence: StreakCadence, window: HourWindow? = nil) -> String {
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
        self.hasWatchCompletedSetup = defaults.bool(forKey: "hasWatchCompletedSetup")
        self.appearance = AppAppearance(rawValue: defaults.integer(forKey: "appearance")) ?? .light
        // Default OFF — never request notification permission until the user explicitly opts in.
        self.notificationsEnabled = defaults.object(forKey: "notificationsEnabled") as? Bool ?? false
        self.notificationHour = defaults.object(forKey: "notificationHour") as? Int ?? 19
        self.notificationMinute = defaults.object(forKey: "notificationMinute") as? Int ?? 0
        self.earnedGraceDays = defaults.object(forKey: "earnedGraceDays") as? Int ?? 0
        self.graceAwardTier = defaults.object(forKey: "graceAwardTier") as? Int ?? 0
        if let stored = defaults.object(forKey: "discoveryVibe") as? Int,
           let v = DiscoveryIntensity(rawValue: stored) {
            self.intensity = v
        } else {
            self.intensity = .challenging
        }
        // Migration: ignore old minStreakLength semantics; default to 30-day lookback.
        let raw = defaults.object(forKey: "lookbackDays") as? Int
            ?? defaults.object(forKey: "minStreakLength") as? Int
        if let raw, (7...365).contains(raw) {
            self.lookbackDays = raw
        } else {
            self.lookbackDays = 30
        }

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

        self.committedThresholds = Self.loadCodable([String: Double].self, key: "committedThresholds", defaults: defaults) ?? [:]
        self.customStreaks = Self.loadCodable([CustomStreak].self, key: "customStreaks", defaults: defaults) ?? []
        self.recentlyBroken = Self.loadCodable([BrokenStreak].self, key: "recentlyBroken", defaults: defaults) ?? []
        self.gracePreservations = Self.loadCodable([String: GracePreservation].self, key: "gracePreservations", defaults: defaults) ?? [:]
        self.manualStreakOrder = Self.loadCodable([String].self, key: "manualStreakOrder", defaults: defaults) ?? []
        self.lastKnownStreakLengths = Self.loadCodable([String: Int].self, key: "lastKnownStreakLengths", defaults: defaults) ?? [:]
    }

    func isHidden(_ metric: StreakMetric) -> Bool { hiddenMetrics.contains(metric) }

    func toggle(_ metric: StreakMetric) {
        if hiddenMetrics.contains(metric) {
            hiddenMetrics.remove(metric)
        } else {
            hiddenMetrics.insert(metric)
        }
    }

    func commitThresholds(for streaks: [Streak]) {
        var next = committedThresholds
        for streak in streaks where streak.customID == nil {
            if next[streak.trackingKey] == nil {
                next[streak.trackingKey] = streak.threshold
            }
        }
        committedThresholds = next
    }

    func clearCommittedThreshold(for key: String) {
        committedThresholds.removeValue(forKey: key)
    }

    func updateCustomStreak(id: String, threshold: Double) {
        guard let index = customStreaks.firstIndex(where: { $0.id == id }) else { return }
        var updated = customStreaks[index]
        updated.threshold = threshold
        customStreaks[index] = updated
    }

    func dismissBroken(_ broken: BrokenStreak) {
        recentlyBroken.removeAll { $0.id == broken.id }
    }

    func pruneBroken(now: Date = .now) {
        recentlyBroken.removeAll { now.timeIntervalSince($0.brokenAt) > 48 * 60 * 60 }
    }

    /// Bank Grace Days as the user crosses 30-day tiers on their hero streak.
    /// Free users accrue too — used as Pro upsell currency ("you have 3 banked").
    func awardGraceDays(from streaks: [Streak]) {
        // Tier is driven by the hero streak so the user understands the reward source.
        let tier = (streaks.first?.current ?? 0) / 30
        if tier > graceAwardTier {
            earnedGraceDays = min(9, earnedGraceDays + (tier - graceAwardTier))
            graceAwardTier = tier
        }
    }

    /// Spend a Grace Day to preserve a streak. Pro entitlement required.
    /// Free users accrue but cannot consume — that's the upsell hook.
    func consumeGraceDay(isPro: Bool) -> Bool {
        guard isPro, earnedGraceDays > 0 else { return false }
        earnedGraceDays -= 1
        return true
    }

    private func saveCodable<T: Encodable>(_ value: T, key: String) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        defaults.set(data, forKey: key)
    }

    private static func loadCodable<T: Decodable>(_ type: T.Type, key: String, defaults: UserDefaults) -> T? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }
}

struct GracePreservation: Codable, Sendable, Hashable {
    let key: String
    let missedDate: Date
    let preservedLength: Int
    let threshold: Double
    let metric: StreakMetric
    let cadence: StreakCadence
    let hourWindow: Int?
    let grantedAt: Date
}

enum SnapshotStore {
    private static let key = "streakSnapshot.v1"
    static let transferDataKey = "streakSnapshot.data.v1"

    static func save(_ snapshot: StreakSnapshot) {
        let defaults = UserDefaults(suiteName: streaksAppGroupID) ?? .standard
        guard let data = encode(snapshot) else { return }
        defaults.set(data, forKey: key)
        WidgetCenter.shared.reloadAllTimelines()
    }

    static func load() -> StreakSnapshot? {
        let defaults = UserDefaults(suiteName: streaksAppGroupID) ?? .standard
        guard let data = defaults.data(forKey: key) else { return nil }
        return decode(data)
    }

    static func encode(_ snapshot: StreakSnapshot) -> Data? {
        try? JSONEncoder().encode(snapshot)
    }

    static func decode(_ data: Data) -> StreakSnapshot? {
        try? JSONDecoder().decode(StreakSnapshot.self, from: data)
    }

    @discardableResult
    static func saveEncodedSnapshot(_ data: Data) -> StreakSnapshot? {
        guard let snapshot = decode(data) else { return nil }
        save(snapshot)
        return snapshot
    }
}

import WidgetKit
import SwiftUI

// MARK: - Entry

struct StreakEntry: TimelineEntry {
    let date: Date
    let hero: StreakSnapshot.Item?
    let badges: [StreakSnapshot.Item]

    static let placeholder = StreakEntry(
        date: .now,
        hero: StreakSnapshot.Item(
            metric: "exerciseMinutes",
            cadence: "daily",
            threshold: 30,
            current: 42,
            best: 60,
            currentUnitCompleted: true,
            currentUnitProgress: 1.0,
            currentUnitValue: 38
        ),
        badges: []
    )
}

// MARK: - Provider

struct StreakTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> StreakEntry { .placeholder }

    func getSnapshot(in context: Context, completion: @escaping (StreakEntry) -> Void) {
        completion(currentEntry())
    }

    func getTimeline(in context: Context, completion: @escaping @Sendable (Timeline<StreakEntry>) -> Void) {
        let now = Date.now
        let calendar = DateHelpers.gregorian
        let tomorrow = calendar.startOfDay(for: calendar.date(byAdding: .day, value: 1, to: now) ?? now)
        let nowEntry = currentEntry(at: now, resetForNewDay: false)
        // Emit a second entry at midnight that resets today's "locked-in" state to false,
        // so the lock-screen widget doesn't keep claiming today is done after midnight rolls.
        let midnightEntry = currentEntry(at: tomorrow, resetForNewDay: true)
        completion(Timeline(entries: [nowEntry, midnightEntry], policy: .after(tomorrow)))
    }

    private func currentEntry(at date: Date = .now, resetForNewDay: Bool = false) -> StreakEntry {
        guard let snap = SnapshotStore.load() else {
            return StreakEntry(date: date, hero: nil, badges: [])
        }
        let hero = resetForNewDay ? snap.hero.map(Self.resetForNewDay) : snap.hero
        let badges = resetForNewDay ? snap.badges.map(Self.resetForNewDay) : snap.badges
        return StreakEntry(date: date, hero: hero, badges: badges)
    }

    static func resetForNewDay(_ item: StreakSnapshot.Item) -> StreakSnapshot.Item {
        var copy = item
        copy = StreakSnapshot.Item(
            metric: item.metric,
            cadence: item.cadence,
            threshold: item.threshold,
            current: item.current,
            best: item.best,
            currentUnitCompleted: false,
            currentUnitProgress: 0,
            currentUnitValue: 0,
            hourWindow: item.hourWindow,
            customID: item.customID,
            workoutType: item.workoutType,
            workoutMeasure: item.workoutMeasure
        )
        return copy
    }
}

// MARK: - Helpers
// Snapshot display helpers (displayName, displaySymbol, thresholdLabel) live on StreakSnapshot.Item.

// MARK: - Views

struct StreakWidgetView: View {
    var entry: StreakEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .accessoryInline: inlineView
        case .accessoryCircular: circularView
        case .accessoryRectangular: rectangularView
        case .systemSmall: smallView
        case .systemMedium: mediumView
        default: smallView
        }
    }

    // Lock-screen inline: one line
    private var inlineView: some View {
        if let hero = entry.hero {
            return AnyView(
                Text("\(Image(systemName: hero.displaySymbol)) \(hero.progressValueLabel)")
            )
        }
        return AnyView(Text("Open app to sync streaks"))
    }

    // Lock-screen circular
    private var circularView: some View {
        Group {
            if let hero = entry.hero {
                ZStack {
                    AccessoryWidgetBackground()
                    Gauge(value: clampedProgress(hero)) {
                        Image(systemName: hero.displaySymbol)
                    } currentValueLabel: {
                        VStack(spacing: 0) {
                            Text(hero.compactCurrentUnitValueLabel)
                                .font(.system(size: 18, weight: .bold, design: .rounded))
                                .minimumScaleFactor(0.5)
                            Text("/\(hero.compactGoalValueLabel)")
                                .font(.system(size: 8, weight: .bold, design: .rounded))
                                .minimumScaleFactor(0.6)
                        }
                    }
                    .gaugeStyle(.accessoryCircular)
                    .tint(heroAccent(hero))
                }
            } else {
                ZStack {
                    AccessoryWidgetBackground()
                    Image(systemName: "flame")
                        .font(.system(size: 22))
                }
            }
        }
        .containerBackground(.clear, for: .widget)
    }

    // Lock-screen rectangular
    private var rectangularView: some View {
        VStack(alignment: .leading, spacing: 2) {
            if let hero = entry.hero {
                HStack(spacing: 4) {
                    Image(systemName: hero.displaySymbol).font(.system(size: 11, weight: .semibold))
                    Text(hero.displayName).font(.system(size: 11, weight: .semibold, design: .rounded))
                }
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(hero.currentUnitValueLabel)
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .minimumScaleFactor(0.55)
                    Text("/ \(hero.goalValueLabel) \(hero.unitLabel)")
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
                ProgressView(value: clampedProgress(hero))
                    .tint(heroAccent(hero))
                Text("\(streakLengthLabel(hero)) streak")
                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                    .lineLimit(1)
            } else {
                Text("No streak yet")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
            }
        }
        .containerBackground(.clear, for: .widget)
    }

    // Home-screen small
    private var smallView: some View {
        ZStack {
            Theme.streakGradient
            VStack(alignment: .leading, spacing: 7) {
                if let hero = entry.hero {
                    HStack(spacing: 6) {
                        Image(systemName: hero.displaySymbol)
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                        Text(hero.displayName)
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .lineLimit(1)
                        Spacer(minLength: 0)
                    }
                    .foregroundStyle(.white.opacity(0.92))

                    Spacer(minLength: 0)

                    VStack(alignment: .leading, spacing: 0) {
                        Text(hero.compactCurrentUnitValueLabel)
                            .font(.system(size: 48, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .monospacedDigit()
                            .minimumScaleFactor(0.45)
                        Text("/ \(hero.compactGoalValueLabel) \(hero.unitLabel)")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.82))
                            .lineLimit(1)
                            .minimumScaleFactor(0.65)
                    }

                    ProgressView(value: clampedProgress(hero))
                        .tint(.white)

                    Text("\(streakLengthLabel(hero)) streak")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.78))
                        .lineLimit(1)
                } else {
                    Image(systemName: "figure.run")
                        .font(.system(size: 34, weight: .regular))
                        .foregroundStyle(.white.opacity(0.9))
                    Text("No streak yet — open app")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.85))
                        .multilineTextAlignment(.center)
                }
            }
            .padding(10)
        }
        .containerBackground(.clear, for: .widget)
    }

    // Home-screen medium: hero + up to 3 badges
    private var mediumView: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Theme.streakGradient)
                VStack(alignment: .leading, spacing: 7) {
                    if let hero = entry.hero {
                        Label(hero.displayName, systemImage: hero.displaySymbol)
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.92))
                            .lineLimit(1)
                        Spacer(minLength: 0)
                        Text(hero.compactCurrentUnitValueLabel)
                            .font(.system(size: 40, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .monospacedDigit()
                            .minimumScaleFactor(0.45)
                        Text("/ \(hero.compactGoalValueLabel) \(hero.unitLabel)")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.82))
                            .lineLimit(1)
                            .minimumScaleFactor(0.65)
                        ProgressView(value: clampedProgress(hero))
                            .tint(.white)
                        Text("\(streakLengthLabel(hero)) streak")
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.78))
                            .lineLimit(1)
                    } else {
                        Image(systemName: "figure.run")
                            .font(.system(size: 28))
                            .foregroundStyle(.white)
                    }
                }
                .padding(8)
            }
            .frame(width: 120)

            VStack(alignment: .leading, spacing: 7) {
                Text("More streaks")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(.secondary)
                ForEach(entry.badges.prefix(3)) { b in
                    mediumBadgeRow(b)
                }
                if entry.badges.isEmpty {
                    Text("No streak yet — open app")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
        }
        .padding(10)
        .containerBackground(.fill.tertiary, for: .widget)
    }

    private func mediumBadgeRow(_ item: StreakSnapshot.Item) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 6) {
                Image(systemName: item.displaySymbol)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(heroAccent(item))
                    .frame(width: 16)
                Text(item.displayName)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .lineLimit(1)
                Spacer(minLength: 2)
                Text("\(item.compactCurrentUnitValueLabel)/\(item.compactGoalValueLabel)")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
            ProgressView(value: clampedProgress(item))
                .tint(heroAccent(item))
        }
    }

    private func clampedProgress(_ item: StreakSnapshot.Item) -> Double {
        min(max(item.currentUnitProgress, 0), 1)
    }

    private func heroAccent(_ item: StreakSnapshot.Item) -> Color {
        item.streakMetric?.accent ?? Theme.streakHot
    }

    private func streakLengthLabel(_ item: StreakSnapshot.Item) -> String {
        if item.cadence == "daily" {
            return item.current == 1 ? "1 day" : "\(item.current) days"
        }
        return item.current == 1 ? "1 week" : "\(item.current) weeks"
    }
}

// MARK: - Widget entry point

@main
struct FitnessStreaksWidgets: WidgetBundle {
    var body: some Widget {
        FitnessStreaksWidget()
    }
}

struct FitnessStreaksWidget: Widget {
    let kind: String = "FitnessStreaksWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: StreakTimelineProvider()) { entry in
            StreakWidgetView(entry: entry)
        }
        .configurationDisplayName("Streak Finder")
        .description("Your hottest streak, at a glance.")
        .supportedFamilies([
            .systemSmall,
            .systemMedium,
            .accessoryInline,
            .accessoryCircular,
            .accessoryRectangular
        ])
    }
}

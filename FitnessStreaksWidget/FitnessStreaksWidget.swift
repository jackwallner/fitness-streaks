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
                Text("\(Image(systemName: hero.displaySymbol)) \(hero.current) \(cadenceLabel(hero))")
            )
        }
        return AnyView(Text("No streak yet — open app"))
    }

    // Lock-screen circular
    private var circularView: some View {
        Group {
            if let hero = entry.hero {
                ZStack {
                    AccessoryWidgetBackground()
                    VStack(spacing: 0) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 10, weight: .semibold))
                        Text("\(hero.current)")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .minimumScaleFactor(0.6)
                        Text(hero.cadence == "daily" ? "days" : "wks")
                            .font(.system(size: 9, weight: .semibold, design: .rounded))
                    }
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
                    Text("\(hero.current)")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .monospacedDigit()
                    Text(cadenceLabel(hero))
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                }
                Text(hero.thresholdLabel)
                    .font(.system(size: 9, weight: .medium, design: .rounded))
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
            VStack(spacing: 2) {
                if let hero = entry.hero {
                    Image(systemName: hero.displaySymbol)
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.9))
                        .padding(.bottom, 2)
                    Text("\(hero.current)")
                        .font(.system(size: 58, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .monospacedDigit()
                        .minimumScaleFactor(0.6)
                    Text(cadenceLabel(hero))
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.85))
                    Text(hero.displayName)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.75))
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
                VStack(spacing: 2) {
                    if let hero = entry.hero {
                        Image(systemName: hero.displaySymbol)
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.9))
                        Text("\(hero.current)")
                            .font(.system(size: 44, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .monospacedDigit()
                            .minimumScaleFactor(0.6)
                        Text(cadenceLabel(hero))
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.85))
                        Text(hero.displayName)
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.75))
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

            VStack(alignment: .leading, spacing: 6) {
                ForEach(entry.badges.prefix(3)) { b in
                    HStack(spacing: 6) {
                        Image(systemName: b.displaySymbol)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(b.streakMetric?.accent ?? .primary)
                            .frame(width: 16)
                        Text(b.displayName)
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .lineLimit(1)
                        Spacer(minLength: 2)
                        Text("\(b.current)")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .monospacedDigit()
                        Text(b.cadence == "daily" ? "d" : "w")
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
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

    private func cadenceLabel(_ item: StreakSnapshot.Item) -> String {
        if item.cadence == "daily" {
            return item.current == 1 ? "day" : "days"
        }
        return item.current == 1 ? "week" : "weeks"
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

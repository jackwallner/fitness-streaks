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
        Group {
            if let hero = entry.hero {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 5) {
                        Image(systemName: hero.displaySymbol)
                            .font(.system(size: 13, weight: .bold))
                        Text(hero.displayName)
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                    }
                    .foregroundStyle(.white.opacity(0.95))

                    Spacer(minLength: 6)

                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(hero.compactCurrentUnitValueLabel)
                            .font(.system(size: 44, weight: .heavy, design: .rounded))
                            .foregroundStyle(.white)
                            .monospacedDigit()
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                        Text(hero.unitLabel)
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.85))
                    }
                    Text("of \(hero.compactGoalValueLabel) goal")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.8))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)

                    Spacer(minLength: 8)

                    progressBar(clampedProgress(hero), height: 7)

                    HStack(spacing: 4) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 10, weight: .bold))
                        Text(streakLengthLabel(hero))
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .lineLimit(1)
                        if hero.currentUnitCompleted {
                            Spacer(minLength: 0)
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 11, weight: .bold))
                        }
                    }
                    .foregroundStyle(.white.opacity(0.9))
                    .padding(.top, 6)
                }
            } else {
                emptyState
            }
        }
        .containerBackground(Theme.streakGradient, for: .widget)
    }

    // Home-screen medium: hero + up to 3 badges
    private var mediumView: some View {
        HStack(spacing: 14) {
            Group {
                if let hero = entry.hero {
                    VStack(alignment: .leading, spacing: 0) {
                        HStack(spacing: 5) {
                            Image(systemName: hero.displaySymbol)
                                .font(.system(size: 12, weight: .bold))
                            Text(hero.displayName)
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .lineLimit(1)
                                .minimumScaleFactor(0.75)
                        }
                        .foregroundStyle(.white.opacity(0.95))

                        Spacer(minLength: 4)

                        HStack(alignment: .firstTextBaseline, spacing: 3) {
                            Text(hero.compactCurrentUnitValueLabel)
                                .font(.system(size: 40, weight: .heavy, design: .rounded))
                                .foregroundStyle(.white)
                                .monospacedDigit()
                                .lineLimit(1)
                                .minimumScaleFactor(0.5)
                            Text(hero.unitLabel)
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundStyle(.white.opacity(0.85))
                        }
                        Text("of \(hero.compactGoalValueLabel) goal")
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.8))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)

                        Spacer(minLength: 6)

                        progressBar(clampedProgress(hero), height: 6)

                        HStack(spacing: 4) {
                            Image(systemName: "flame.fill")
                                .font(.system(size: 9, weight: .bold))
                            Text(streakLengthLabel(hero))
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .lineLimit(1)
                        }
                        .foregroundStyle(.white.opacity(0.9))
                        .padding(.top, 5)
                    }
                } else {
                    emptyState
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .leading, spacing: 8) {
                Text("MORE STREAKS")
                    .font(.system(size: 9, weight: .heavy, design: .rounded))
                    .tracking(0.6)
                    .foregroundStyle(.white.opacity(0.65))
                if entry.badges.isEmpty {
                    Text("Keep going to unlock more")
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.7))
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    ForEach(entry.badges.prefix(3)) { b in
                        mediumBadgeRow(b)
                    }
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.white.opacity(0.14))
            )
        }
        .containerBackground(Theme.streakGradient, for: .widget)
    }

    private func mediumBadgeRow(_ item: StreakSnapshot.Item) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 5) {
                Image(systemName: item.displaySymbol)
                    .font(.system(size: 10, weight: .bold))
                    .frame(width: 14)
                Text(item.displayName)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Spacer(minLength: 2)
                Text("\(item.compactCurrentUnitValueLabel)/\(item.compactGoalValueLabel)")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
            .foregroundStyle(.white.opacity(0.95))
            progressBar(clampedProgress(item), height: 4, trackOpacity: 0.2, fillOpacity: 0.9)
        }
    }

    // Crisp capsule progress bar — replaces the default ProgressView, which
    // renders inconsistently and can't be sized cleanly inside widgets.
    private func progressBar(_ value: Double,
                             height: CGFloat,
                             trackOpacity: Double = 0.25,
                             fillOpacity: Double = 1) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(.white.opacity(trackOpacity))
                Capsule()
                    .fill(.white.opacity(fillOpacity))
                    .frame(width: value <= 0 ? 0 : max(height, geo.size.width * value))
            }
        }
        .frame(height: height)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "figure.run")
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(.white)
            Text("Open app to sync streaks")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.9))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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

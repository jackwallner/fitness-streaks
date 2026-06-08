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
                let accent = heroAccent(hero)
                let valueColor: Color = hero.currentUnitCompleted ? Theme.retroLime : accent
                VStack(alignment: .leading, spacing: 0) {
                    HStack(alignment: .top, spacing: 6) {
                        Text(hero.displayName.uppercased())
                            .font(.system(size: 12, weight: .heavy, design: .rounded))
                            .tracking(0.8)
                            .foregroundStyle(accent)
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                        Spacer(minLength: 4)
                        Image(systemName: hero.displaySymbol)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(accent)
                    }

                    Spacer(minLength: 6)

                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(hero.compactCurrentUnitValueLabel)
                            .font(.system(size: 44, weight: .heavy, design: .rounded))
                            .foregroundStyle(valueColor)
                            .monospacedDigit()
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                        Text(hero.unitLabel.uppercased())
                            .font(.system(size: 11, weight: .heavy, design: .rounded))
                            .tracking(0.6)
                            .foregroundStyle(Theme.retroInkDim)
                    }
                    Text("OF \(hero.compactGoalValueLabel) GOAL")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .tracking(0.6)
                        .foregroundStyle(Theme.retroInkDim)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)

                    Spacer(minLength: 8)

                    progressBar(clampedProgress(hero), accent: valueColor, height: 7)

                    HStack(spacing: 4) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(hero.currentUnitCompleted ? Theme.retroLime : Theme.retroAmber)
                        Text(streakLengthLabel(hero).uppercased())
                            .font(.system(size: 11, weight: .heavy, design: .rounded))
                            .tracking(0.4)
                            .foregroundStyle(Theme.retroInk)
                            .lineLimit(1)
                        Spacer(minLength: 0)
                        if hero.currentUnitCompleted {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(Theme.retroLime)
                        }
                    }
                    .padding(.top, 6)
                }
            } else {
                emptyState
            }
        }
        .containerBackground(Theme.retroBg, for: .widget)
    }

    // Home-screen medium: hero + up to 3 badges
    private var mediumView: some View {
        HStack(spacing: 12) {
            Group {
                if let hero = entry.hero {
                    let accent = heroAccent(hero)
                    let valueColor: Color = hero.currentUnitCompleted ? Theme.retroLime : accent
                    VStack(alignment: .leading, spacing: 0) {
                        HStack(alignment: .top, spacing: 6) {
                            Text(hero.displayName.uppercased())
                                .font(.system(size: 12, weight: .heavy, design: .rounded))
                                .tracking(0.8)
                                .foregroundStyle(accent)
                                .lineLimit(1)
                                .minimumScaleFactor(0.6)
                            Spacer(minLength: 4)
                            Image(systemName: hero.displaySymbol)
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(accent)
                        }

                        Spacer(minLength: 4)

                        HStack(alignment: .firstTextBaseline, spacing: 3) {
                            Text(hero.compactCurrentUnitValueLabel)
                                .font(.system(size: 40, weight: .heavy, design: .rounded))
                                .foregroundStyle(valueColor)
                                .monospacedDigit()
                                .lineLimit(1)
                                .minimumScaleFactor(0.5)
                            Text(hero.unitLabel.uppercased())
                                .font(.system(size: 10, weight: .heavy, design: .rounded))
                                .tracking(0.6)
                                .foregroundStyle(Theme.retroInkDim)
                        }
                        Text("OF \(hero.compactGoalValueLabel) GOAL")
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                            .tracking(0.6)
                            .foregroundStyle(Theme.retroInkDim)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)

                        Spacer(minLength: 6)

                        progressBar(clampedProgress(hero), accent: valueColor, height: 6)

                        HStack(spacing: 4) {
                            Image(systemName: "flame.fill")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(hero.currentUnitCompleted ? Theme.retroLime : Theme.retroAmber)
                            Text(streakLengthLabel(hero).uppercased())
                                .font(.system(size: 10, weight: .heavy, design: .rounded))
                                .tracking(0.4)
                                .foregroundStyle(Theme.retroInk)
                                .lineLimit(1)
                        }
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
                    .tracking(1)
                    .foregroundStyle(Theme.retroInkDim)
                if entry.badges.isEmpty {
                    Text("Keep going to unlock more")
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundStyle(Theme.retroInkDim)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    ForEach(entry.badges.prefix(3)) { b in
                        mediumBadgeRow(b)
                    }
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Theme.retroBgRaised)
            )
        }
        .containerBackground(Theme.retroBg, for: .widget)
    }

    private func mediumBadgeRow(_ item: StreakSnapshot.Item) -> some View {
        let accent = item.streakMetric?.accent ?? Theme.streakHot
        let valueColor: Color = item.currentUnitCompleted ? Theme.retroLime : accent
        return VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 5) {
                Image(systemName: item.displaySymbol)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(accent)
                    .frame(width: 14)
                Text(item.displayName)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.retroInk)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Spacer(minLength: 2)
                Text("\(item.compactCurrentUnitValueLabel)/\(item.compactGoalValueLabel)")
                    .font(.system(size: 10, weight: .heavy, design: .rounded))
                    .foregroundStyle(valueColor)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
            progressBar(clampedProgress(item), accent: valueColor, height: 4)
        }
    }

    // Crisp capsule progress bar — replaces the default ProgressView, which
    // renders inconsistently and can't be sized cleanly inside widgets.
    private func progressBar(_ value: Double,
                             accent: Color,
                             height: CGFloat) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.retroInkFaint.opacity(0.35))
                Capsule()
                    .fill(accent)
                    .frame(width: value <= 0 ? 0 : max(height, geo.size.width * value))
            }
        }
        .frame(height: height)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "figure.run")
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(Theme.retroMagenta)
            Text("Open app to sync streaks")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(Theme.retroInkDim)
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
        .configurationDisplayName("Streaks")
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

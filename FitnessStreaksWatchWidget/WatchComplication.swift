import WidgetKit
import SwiftUI

struct WatchStreakEntry: TimelineEntry {
    let date: Date
    let hero: StreakSnapshot.Item?

    static let placeholder = WatchStreakEntry(
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
        )
    )
}

struct WatchStreakProvider: TimelineProvider {
    func placeholder(in context: Context) -> WatchStreakEntry { .placeholder }

    func getSnapshot(in context: Context, completion: @escaping (WatchStreakEntry) -> Void) {
        completion(currentEntry())
    }

    func getTimeline(in context: Context, completion: @escaping @Sendable (Timeline<WatchStreakEntry>) -> Void) {
        let now = Date.now
        let calendar = DateHelpers.gregorian
        let tomorrow = calendar.startOfDay(for: calendar.date(byAdding: .day, value: 1, to: now) ?? now)
        let snap = SnapshotStore.load()
        let nowEntry = WatchStreakEntry(date: now, hero: snap?.hero)
        let midnightEntry = WatchStreakEntry(date: tomorrow, hero: snap?.hero.map(Self.resetForNewDay))
        completion(Timeline(entries: [nowEntry, midnightEntry], policy: .after(tomorrow)))
    }

    private func currentEntry() -> WatchStreakEntry {
        WatchStreakEntry(date: .now, hero: SnapshotStore.load()?.hero)
    }

    static func resetForNewDay(_ item: StreakSnapshot.Item) -> StreakSnapshot.Item {
        StreakSnapshot.Item(
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
    }
}

struct WatchComplicationView: View {
    var entry: WatchStreakEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .accessoryInline: inline
        case .accessoryCircular: circular
        case .accessoryRectangular: rectangular
        #if os(watchOS)
        case .accessoryCorner: corner
        #endif
        default: circular
        }
    }

    private var inline: some View {
        Group {
            if let hero = entry.hero {
                Text("\(Image(systemName: hero.displaySymbol)) \(hero.progressValueLabel)")
            } else {
                Text("Open app to sync streaks")
            }
        }
    }

    private var circular: some View {
        ZStack {
            AccessoryWidgetBackground()
            if let hero = entry.hero {
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
            } else {
                Image(systemName: "flame")
                    .font(.system(size: 18))
            }
        }
        .containerBackground(.clear, for: .widget)
    }

    private var rectangular: some View {
        VStack(alignment: .leading, spacing: 2) {
            if let hero = entry.hero {
                HStack(spacing: 4) {
                    Image(systemName: hero.displaySymbol).font(.system(size: 10, weight: .semibold))
                    Text(hero.displayName).font(.system(size: 11, weight: .semibold, design: .rounded))
                }
                HStack(alignment: .firstTextBaseline, spacing: 3) {
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
                Text(rectangularProgressLabel(hero))
                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                    .lineLimit(1)
            } else {
                Text("Open iPhone app to sync")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
            }
        }
        .containerBackground(.clear, for: .widget)
    }

    private var corner: some View {
        Group {
            if let hero = entry.hero {
                Text(hero.compactCurrentUnitValueLabel)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .minimumScaleFactor(0.45)
                    .widgetCurvesContent()
                    .widgetLabel {
                        Label("\(hero.displayName) / \(hero.compactGoalValueLabel)", systemImage: hero.displaySymbol)
                    }
            } else {
                Image(systemName: "flame").widgetLabel("Open app to sync")
            }
        }
        .containerBackground(.clear, for: .widget)
    }

    private func clampedProgress(_ item: StreakSnapshot.Item) -> Double {
        min(max(item.currentUnitProgress, 0), 1)
    }

    private func heroAccent(_ item: StreakSnapshot.Item) -> Color {
        item.streakMetric?.accent ?? Theme.streakHot
    }

    private func rectangularProgressLabel(_ item: StreakSnapshot.Item) -> String {
        if item.currentUnitCompleted {
            return "\(item.progressValueLabel) done"
        }
        return item.progressValueLabel
    }
}

@main
struct FitnessStreaksWatchWidgets: WidgetBundle {
    var body: some Widget {
        FitnessStreaksWatchComplication()
    }
}

private let supportedFamilies: [WidgetFamily] = {
    var families: [WidgetFamily] = [.accessoryInline, .accessoryCircular, .accessoryRectangular]
    #if os(watchOS)
    families.append(.accessoryCorner)
    #endif
    return families
}()

struct FitnessStreaksWatchComplication: Widget {
    let kind: String = "FitnessStreaksWatchComplication"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: WatchStreakProvider()) { entry in
            WatchComplicationView(entry: entry)
        }
        .configurationDisplayName("Streak")
        .description("Your hottest streak on your wrist.")
        .supportedFamilies(supportedFamilies)
    }
}

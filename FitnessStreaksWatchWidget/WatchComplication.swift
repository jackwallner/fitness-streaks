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
        let entry = currentEntry()
        let next = Calendar.current.date(byAdding: .hour, value: 1, to: .now) ?? .now.addingTimeInterval(3600)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }

    private func currentEntry() -> WatchStreakEntry {
        WatchStreakEntry(date: .now, hero: SnapshotStore.load()?.hero)
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
        case .accessoryCorner: corner
        default: circular
        }
    }

    private var metric: StreakMetric? {
        guard let raw = entry.hero?.metric else { return nil }
        return StreakMetric(rawValue: raw)
    }

    private var inline: some View {
        Group {
            if let hero = entry.hero, let m = metric {
                Text("\(Image(systemName: m.symbol)) \(hero.current) \(hero.cadence == "daily" ? "d" : "w")")
            } else {
                Text("Streak Finder")
            }
        }
    }

    private var circular: some View {
        ZStack {
            AccessoryWidgetBackground()
            if let hero = entry.hero {
                VStack(spacing: 0) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 10, weight: .semibold))
                    Text("\(hero.current)")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .minimumScaleFactor(0.5)
                    Text(hero.cadence == "daily" ? "d" : "w")
                        .font(.system(size: 9, weight: .semibold, design: .rounded))
                }
            } else {
                Image(systemName: "flame").font(.system(size: 18))
            }
        }
        .containerBackground(.clear, for: .widget)
    }

    private var rectangular: some View {
        VStack(alignment: .leading, spacing: 1) {
            if let hero = entry.hero, let m = metric {
                HStack(spacing: 4) {
                    Image(systemName: m.symbol).font(.system(size: 10, weight: .semibold))
                    Text(m.displayName).font(.system(size: 11, weight: .semibold, design: .rounded))
                }
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text("\(hero.current)")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .monospacedDigit()
                    Text(hero.cadence == "daily" ? "days" : "weeks")
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                }
                Text(m.thresholdLabel(hero.threshold, cadence: StreakCadence(rawValue: hero.cadence) ?? .daily))
                    .font(.system(size: 9, weight: .medium, design: .rounded))
                    .lineLimit(1)
            } else {
                Text("Streak Finder").font(.system(size: 12, weight: .semibold))
            }
        }
        .containerBackground(.clear, for: .widget)
    }

    private var corner: some View {
        Group {
            if let hero = entry.hero {
                Text("\(hero.current)")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .widgetCurvesContent()
                    .widgetLabel {
                        Text(metric?.displayName ?? "Streak")
                    }
            } else {
                Image(systemName: "flame").widgetLabel("Streak Finder")
            }
        }
        .containerBackground(.clear, for: .widget)
    }
}

@main
struct FitnessStreaksWatchWidgets: WidgetBundle {
    var body: some Widget {
        FitnessStreaksWatchComplication()
    }
}

struct FitnessStreaksWatchComplication: Widget {
    let kind: String = "FitnessStreaksWatchComplication"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: WatchStreakProvider()) { entry in
            WatchComplicationView(entry: entry)
        }
        .configurationDisplayName("Streak")
        .description("Your hottest streak on your wrist.")
        .supportedFamilies([
            .accessoryInline,
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryCorner
        ])
    }
}

import SwiftUI

/// GitHub-style calendar heatmap. Columns = weeks, rows = weekdays (Mon–Sun).
/// Filled cells meet the threshold; faded cells don't.
struct CalendarHeatmap: View {
    let entries: [(date: Date, met: Bool, value: Double)]
    let accent: Color

    private let cell: CGFloat = 11
    private let spacing: CGFloat = 3

    var body: some View {
        let weeks = groupByWeek(entries)
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: spacing) {
                    ForEach(Array(weeks.enumerated()), id: \.offset) { idx, week in
                        VStack(spacing: spacing) {
                            ForEach(0..<7, id: \.self) { weekdayIndex in
                                let day = week.first { weekdayOrdinal($0.date) == weekdayIndex }
                                cellView(day: day)
                            }
                        }
                        .id(idx)
                    }
                }
                .padding(.horizontal, 2)
                .padding(.vertical, 4)
            }
            .onAppear {
                proxy.scrollTo(weeks.count - 1, anchor: .trailing)
            }
        }
    }

    @ViewBuilder
    private func cellView(day: (date: Date, met: Bool, value: Double)?) -> some View {
        RoundedRectangle(cornerRadius: 2, style: .continuous)
            .fill(color(for: day))
            .frame(width: cell, height: cell)
    }

    private func color(for day: (date: Date, met: Bool, value: Double)?) -> Color {
        guard let day else { return Theme.ringTrack.opacity(0.4) }
        if day.met { return accent }
        if day.value > 0 { return accent.opacity(0.25) }
        return Theme.ringTrack.opacity(0.6)
    }

    private func weekdayOrdinal(_ date: Date) -> Int {
        // Monday-first ordering (0 = Mon, 6 = Sun)
        let wd = DateHelpers.gregorian.component(.weekday, from: date) // 1=Sun...7=Sat
        return (wd + 5) % 7
    }

    private func groupByWeek(_ entries: [(date: Date, met: Bool, value: Double)]) -> [[(date: Date, met: Bool, value: Double)]] {
        let sorted = entries.sorted { $0.date < $1.date }
        var result: [[(date: Date, met: Bool, value: Double)]] = []
        var currentWeek: Date? = nil
        var bucket: [(date: Date, met: Bool, value: Double)] = []
        for entry in sorted {
            let w = DateHelpers.startOfWeek(entry.date)
            if w != currentWeek {
                if !bucket.isEmpty { result.append(bucket) }
                bucket = []
                currentWeek = w
            }
            bucket.append(entry)
        }
        if !bucket.isEmpty { result.append(bucket) }
        return result
    }
}

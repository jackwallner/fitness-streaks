import SwiftUI

/// Pixel calendar heatmap. Columns = weeks, rows = weekdays (Mon–Sun).
/// Sharp square cells, no corner radius. Met cells get a subtle inset highlight.
struct CalendarHeatmap: View {
    let entries: [(date: Date, met: Bool, value: Double)]
    let accent: Color

    private let cell: CGFloat = 8
    private let gap: CGFloat = 2

    var body: some View {
        let weeks = groupByWeek(entries)
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: gap) {
                    ForEach(Array(weeks.enumerated()), id: \.offset) { idx, week in
                        VStack(spacing: gap) {
                            ForEach(0..<7, id: \.self) { wd in
                                let day = week.first { weekdayOrdinal($0.date) == wd }
                                cellView(day: day)
                            }
                        }
                        .id(idx)
                    }
                }
                .padding(.vertical, 2)
            }
            .onAppear {
                proxy.scrollTo(weeks.count - 1, anchor: .trailing)
            }
        }
    }

    @ViewBuilder
    private func cellView(day: (date: Date, met: Bool, value: Double)?) -> some View {
        Rectangle()
            .fill(color(for: day))
            .frame(width: cell, height: cell)
            .overlay(
                Rectangle()
                    .stroke(Color.white.opacity(day?.met == true ? 0.2 : 0), lineWidth: 1)
            )
    }

    private func color(for day: (date: Date, met: Bool, value: Double)?) -> Color {
        guard let day else { return Theme.retroInkFaint.opacity(0.5) }
        if day.met { return accent }
        if day.value > 0 { return accent.opacity(0.25) }
        return Theme.retroInkFaint.opacity(0.5)
    }

    private func weekdayOrdinal(_ date: Date) -> Int {
        let wd = DateHelpers.gregorian.component(.weekday, from: date)
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

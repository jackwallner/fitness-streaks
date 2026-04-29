import SwiftUI

/// Pixel calendar heatmap. Columns = weeks, rows = weekdays (Mon–Sun).
/// Sharp square cells, no corner radius. Met cells get a subtle inset highlight.
struct CalendarHeatmap: View {
    let entries: [(date: Date, value: Double, met: Bool)]
    let accent: Color

    private let cell: CGFloat = 8
    private let gap: CGFloat = 2

    var body: some View {
        let weeks = groupByWeek(entries)
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 4) {
                    // Month labels
                    HStack(alignment: .top, spacing: gap) {
                        ForEach(Array(weeks.enumerated()), id: \.offset) { item in
                            let firstDay = item.element.first?.date ?? Date()
                            let isFirstWeekOfMonth = DateHelpers.gregorian.component(.day, from: firstDay) <= 7
                            if isFirstWeekOfMonth {
                                Text(monthName(for: firstDay))
                                    .font(RetroFont.pixel(8))
                                    .foregroundStyle(Theme.retroInkDim)
                                    .frame(width: cell, alignment: .leading)
                            } else {
                                Color.clear.frame(width: cell)
                            }
                        }
                    }
                    
                    // Heatmap cells
                    HStack(alignment: .top, spacing: gap) {
                        ForEach(Array(weeks.enumerated()), id: \.offset) { item in
                            VStack(spacing: gap) {
                                ForEach(0..<7, id: \.self) { wd in
                                    let day = item.element.first { weekdayOrdinal($0.date) == wd }
                                    cellView(day: day)
                                }
                            }
                            .id(item.offset)
                        }
                    }
                }
                .padding(.vertical, 2)
            }
            .onAppear {
                proxy.scrollTo(weeks.count - 1, anchor: .trailing)
            }
        }
    }

    private func monthName(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM"
        return formatter.string(from: date).uppercased()
    }

    @ViewBuilder
    private func cellView(day: (date: Date, value: Double, met: Bool)?) -> some View {
        Rectangle()
            .fill(color(for: day))
            .frame(width: cell, height: cell)
            .overlay(
                Rectangle()
                    .stroke(Color.white.opacity(day?.met == true ? 0.2 : 0), lineWidth: 1)
            )
    }

    private func color(for day: (date: Date, value: Double, met: Bool)?) -> Color {
        guard let day else { return Theme.retroInkFaint.opacity(0.5) }
        if day.met { return accent }
        if day.value > 0 { return accent.opacity(0.25) }
        return Theme.retroInkFaint.opacity(0.5)
    }

    private func weekdayOrdinal(_ date: Date) -> Int {
        let wd = DateHelpers.gregorian.component(.weekday, from: date)
        return (wd + 5) % 7
    }

    private func groupByWeek(_ entries: [(date: Date, value: Double, met: Bool)]) -> [[(date: Date, value: Double, met: Bool)]] {
        let sorted = entries.sorted { $0.date < $1.date }
        var result: [[(date: Date, value: Double, met: Bool)]] = []
        var currentWeek: Date? = nil
        var bucket: [(date: Date, value: Double, met: Bool)] = []
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

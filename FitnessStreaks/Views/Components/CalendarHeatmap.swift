import SwiftUI

/// Date range options for the heatmap
enum HeatmapDateRange: String, CaseIterable {
    case last30Days = "30d"
    case last90Days = "90d"
    case last180Days = "6mo"
    case fullYear = "1yr"

    var label: String {
        switch self {
        case .last30Days: return "30d"
        case .last90Days: return "90d"
        case .last180Days: return "6mo"
        case .fullYear: return "1yr"
        }
    }

    var days: Int {
        switch self {
        case .last30Days: return 30
        case .last90Days: return 90
        case .last180Days: return 180
        case .fullYear: return 365
        }
    }

    /// Pick the smallest range that comfortably contains the user's lookback window.
    static func defaultFor(lookbackDays: Int) -> HeatmapDateRange {
        switch lookbackDays {
        case ..<46: return .last30Days
        case ..<136: return .last90Days
        case ..<271: return .last180Days
        default: return .fullYear
        }
    }
}

typealias HeatmapDay = (date: Date, value: Double, met: Bool)

/// Pixel calendar heatmap. Columns = weeks, rows = weekdays (Mon–Sun).
/// Sharp square cells, no corner radius. Binary colors for pass/fail goals.
struct CalendarHeatmap: View {
    let entries: [HeatmapDay]
    let accent: Color
    @Binding var selectedRange: HeatmapDateRange

    private let gap: CGFloat = 2
    private let minCell: CGFloat = 6
    private let maxCell: CGFloat = 18

    /// Build a complete calendar grid for the selected range. Missing Health rows
    /// still get a cell so longer ranges don't collapse into sparse columns.
    private var calendarWeeks: [[HeatmapDay]] {
        let today = DateHelpers.startOfDay()
        let firstVisibleDay = DateHelpers.addDays(-(selectedRange.days - 1), to: today)
        let firstWeekStart = DateHelpers.startOfWeek(firstVisibleDay)
        let entryByDay = Dictionary(entries.map { (DateHelpers.startOfDay($0.date), $0) },
                                    uniquingKeysWith: { _, latest in latest })

        var weeks: [[HeatmapDay]] = []
        var week: [HeatmapDay] = []
        var day = firstWeekStart

        while day <= today {
            let normalized = DateHelpers.startOfDay(day)
            let entry = entryByDay[normalized] ?? (date: normalized, value: 0, met: false)
            week.append(entry)

            if week.count == 7 {
                weeks.append(week)
                week = []
            }

            guard let nextDay = DateHelpers.gregorian.date(byAdding: .day, value: 1, to: day) else {
                break
            }
            day = nextDay
        }

        if !week.isEmpty {
            weeks.append(week)
        }

        return weeks
    }

    var body: some View {
        let weeks = calendarWeeks
        GeometryReader { geo in
            let cell = cellSize(for: weeks.count, available: geo.size.width)
            let needsScroll = cell <= minCell + 0.1
            let height = CGFloat(7) * cell + CGFloat(6) * gap + 16 // cells + gaps + month labels

            Group {
                if needsScroll {
                    ScrollViewReader { proxy in
                        ScrollView(.horizontal, showsIndicators: false) {
                            grid(weeks: weeks, cell: cell)
                        }
                        .onAppear {
                            proxy.scrollTo(weeks.count - 1, anchor: .trailing)
                        }
                        .onChange(of: selectedRange) { _, _ in
                            DispatchQueue.main.async {
                                withAnimation { proxy.scrollTo(weeks.count - 1, anchor: .trailing) }
                            }
                        }
                    }
                } else {
                    grid(weeks: weeks, cell: cell)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
            .frame(height: height)
        }
        .frame(height: maxHeight)
    }

    @ViewBuilder
    private func grid(weeks: [[HeatmapDay]], cell: CGFloat) -> some View {
        let width = CGFloat(weeks.count) * cell + CGFloat(max(0, weeks.count - 1)) * gap
        VStack(alignment: .leading, spacing: 4) {
            ZStack(alignment: .topLeading) {
                // Reserve a row for month labels.
                Color.clear.frame(height: 12)
                ForEach(Array(weeks.enumerated()), id: \.offset) { item in
                    let firstDay = item.element.first?.date ?? Date()
                    let isFirstWeekOfMonth = DateHelpers.gregorian.component(.day, from: firstDay) <= 7
                    if isFirstWeekOfMonth {
                        Text(monthName(for: firstDay))
                            .font(RetroFont.pixel(8))
                            .foregroundStyle(Theme.retroInkDim)
                            .fixedSize()
                            .offset(x: CGFloat(item.offset) * (cell + gap))
                    }
                }
            }

            HStack(alignment: .top, spacing: gap) {
                ForEach(Array(weeks.enumerated()), id: \.offset) { item in
                    VStack(spacing: gap) {
                        ForEach(0..<7, id: \.self) { wd in
                            let day = item.element.first { weekdayOrdinal($0.date) == wd }
                            cellView(day: day, size: cell)
                        }
                    }
                    .id(item.offset)
                }
            }
        }
        .padding(.vertical, 2)
        .padding(.trailing, 24) // leave room for the rightmost month label to extend past the last column
        .frame(width: width + 24, alignment: .leading)
    }

    private func cellSize(for weekCount: Int, available: CGFloat) -> CGFloat {
        guard weekCount > 0, available > 0 else { return minCell }
        let totalGaps = CGFloat(max(0, weekCount - 1)) * gap
        let raw = (available - totalGaps) / CGFloat(weekCount)
        return max(minCell, min(maxCell, raw))
    }

    private var maxHeight: CGFloat {
        CGFloat(7) * maxCell + CGFloat(6) * gap + 16
    }

    private func monthName(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM"
        return formatter.string(from: date).uppercased()
    }

    @ViewBuilder
    private func cellView(day: HeatmapDay?, size: CGFloat) -> some View {
        Rectangle()
            .fill(color(for: day))
            .frame(width: size, height: size)
    }

    /// Binary color scheme: met = accent, not met but has data = faint accent, no data = background
    private func color(for day: HeatmapDay?) -> Color {
        guard let day else { return Theme.retroInkFaint.opacity(0.5) }
        if day.met { return accent }
        if day.value > 0 { return Theme.retroInkFaint.opacity(0.5) }
        return Theme.retroInkFaint.opacity(0.2)
    }

    private func weekdayOrdinal(_ date: Date) -> Int {
        let wd = DateHelpers.gregorian.component(.weekday, from: date)
        return (wd + 5) % 7
    }

}

/// Date range picker for heatmap
struct HeatmapRangePicker: View {
    @Binding var selectedRange: HeatmapDateRange

    var body: some View {
        HStack(spacing: 4) {
            ForEach(HeatmapDateRange.allCases, id: \.rawValue) { range in
                Button {
                    selectedRange = range
                } label: {
                    Text(range.label)
                        .font(RetroFont.mono(9, weight: .bold))
                        .foregroundStyle(selectedRange == range ? Theme.retroBg : Theme.retroInkDim)
                        .padding(.vertical, 4)
                        .padding(.horizontal, 6)
                        .background(selectedRange == range ? Theme.retroCyan : Color.clear)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

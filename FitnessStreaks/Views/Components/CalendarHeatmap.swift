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

    /// Fixed cell size per range for consistent visual density
    var cellSize: CGFloat {
        switch self {
        case .last30Days: return 16
        case .last90Days: return 10
        case .last180Days: return 6
        case .fullYear: return 4
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

    /// Build weeks only containing days within the selected range.
    /// Each week starts on Monday and contains exactly 7 days.
    private var calendarWeeks: [[HeatmapDay]] {
        let today = DateHelpers.startOfDay()
        let firstVisibleDay = DateHelpers.addDays(-(selectedRange.days - 1), to: today)
        let entryByDay = Dictionary(entries.map { (DateHelpers.startOfDay($0.date), $0) },
                                    uniquingKeysWith: { _, latest in latest })

        // Start from Monday of the week containing firstVisibleDay
        let firstWeekStart = DateHelpers.startOfWeek(firstVisibleDay)

        var weeks: [[HeatmapDay]] = []
        var day = firstWeekStart

        while day <= today {
            var week: [HeatmapDay] = []
            for _ in 0..<7 {
                guard day <= today else { break }
                let normalized = DateHelpers.startOfDay(day)
                let entry = entryByDay[normalized] ?? (date: normalized, value: 0, met: false)
                week.append(entry)
                day = DateHelpers.addDays(1, to: day)
            }
            if !week.isEmpty {
                weeks.append(week)
            }
        }

        return weeks
    }

    /// Month labels positioned at the start of each month
    private func monthLabels(for weeks: [[HeatmapDay]], cell: CGFloat) -> [(index: Int, name: String)] {
        var labels: [(Int, String)] = []
        var lastMonth: Int?

        for (index, week) in weeks.enumerated() {
            guard let firstDay = week.first?.date else { continue }
            let month = DateHelpers.gregorian.component(.month, from: firstDay)
            let day = DateHelpers.gregorian.component(.day, from: firstDay)

            // Show label on first week of month, or if month changed mid-week
            if month != lastMonth && day <= 7 {
                labels.append((index, monthName(for: firstDay)))
                lastMonth = month
            }
        }

        return labels
    }

    var body: some View {
        let weeks = calendarWeeks
        let cell = selectedRange.cellSize
        let height = CGFloat(7) * cell + CGFloat(6) * gap + 14 // cells + gaps + month labels

        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                grid(weeks: weeks, cell: cell)
            }
            .onAppear {
                withAnimation(.easeOut(duration: 0.2)) {
                    proxy.scrollTo(weeks.count - 1, anchor: .trailing)
                }
            }
            .onChange(of: selectedRange) { _, _ in
                DispatchQueue.main.async {
                    withAnimation(.easeOut(duration: 0.2)) {
                        proxy.scrollTo(weeks.count - 1, anchor: .trailing)
                    }
                }
            }
        }
        .frame(height: height)
    }

    @ViewBuilder
    private func grid(weeks: [[HeatmapDay]], cell: CGFloat) -> some View {
        let width = CGFloat(weeks.count) * cell + CGFloat(max(0, weeks.count - 1)) * gap
        let labels = monthLabels(for: weeks, cell: cell)

        VStack(alignment: .leading, spacing: 4) {
            // Month labels row
            ZStack(alignment: .topLeading) {
                Color.clear.frame(height: 10)
                ForEach(labels, id: \.index) { label in
                    Text(label.name)
                        .font(RetroFont.pixel(7))
                        .foregroundStyle(Theme.retroInkDim)
                        .fixedSize()
                        .offset(x: CGFloat(label.index) * (cell + gap))
                }
            }

            // Day cells grid
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
        .padding(.horizontal, 2)
        .frame(width: width + 4, alignment: .leading)
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

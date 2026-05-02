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

    /// Number of weeks (columns) for this range, approximated.
    var weeksCount: Int {
        (days + 6) / 7
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
    private let weekdayLabelWidth: CGFloat = 14

    private struct LayoutMetrics {
        let cell: CGFloat
        let columnSpacing: CGFloat
        let gridWidth: CGFloat
    }

    private struct RenderedDay: Identifiable {
        let date: Date
        let value: Double
        let met: Bool
        let isInRange: Bool
        let isToday: Bool
        let isFuture: Bool

        var id: String { DateHelpers.dayKey(date) }
    }

    private var today: Date {
        DateHelpers.startOfDay()
    }

    private var firstVisibleDay: Date {
        DateHelpers.addDays(-(selectedRange.days - 1), to: today)
    }

    /// Build complete Monday-start weeks for the selected range.
    /// Days before the selected range and future days are rendered as orientation only.
    private var calendarWeeks: [[RenderedDay]] {
        let entryByDay = Dictionary(entries.map { (DateHelpers.startOfDay($0.date), $0) },
                                    uniquingKeysWith: { _, latest in latest })

        let firstWeekStart = DateHelpers.startOfWeek(firstVisibleDay)
        let lastWeekStart = DateHelpers.startOfWeek(today)

        var weeks: [[RenderedDay]] = []
        var weekStart = firstWeekStart

        while weekStart <= lastWeekStart {
            var week: [RenderedDay] = []
            var day = weekStart
            for _ in 0..<7 {
                let normalized = DateHelpers.startOfDay(day)
                let entry = entryByDay[normalized]
                let inRange = normalized >= firstVisibleDay && normalized <= today
                week.append(RenderedDay(
                    date: normalized,
                    value: inRange ? (entry?.value ?? 0) : 0,
                    met: inRange ? (entry?.met ?? false) : false,
                    isInRange: inRange,
                    isToday: normalized == today,
                    isFuture: normalized > today
                ))
                day = DateHelpers.addDays(1, to: day)
            }
            weeks.append(week)
            weekStart = DateHelpers.addDays(7, to: weekStart)
        }

        return weeks
    }

    /// Month labels positioned when the visible range enters a new month.
    private func monthLabels(for weeks: [[RenderedDay]]) -> [(index: Int, name: String)] {
        var labels: [(Int, String)] = []
        var lastMonth: Int?

        for (index, week) in weeks.enumerated() {
            guard let firstDay = week.first(where: { $0.isInRange })?.date else { continue }
            let month = DateHelpers.gregorian.component(.month, from: firstDay)

            if month != lastMonth {
                labels.append((index, monthName(for: firstDay)))
                lastMonth = month
            }
        }

        return labels
    }

    var body: some View {
        let weeks = calendarWeeks

        GeometryReader { proxy in
            let layout = layoutMetrics(weekCount: weeks.count, availableWidth: proxy.size.width)
            grid(weeks: weeks, layout: layout)
                .frame(height: layoutHeight(for: layout.cell))
        }
    }

    /// Calculate card height based on cell size to fit the grid perfectly
    private func layoutHeight(for cellSize: CGFloat) -> CGFloat {
        let topLabelHeight: CGFloat = 14      // Month labels
        let bottomLabelHeight: CGFloat = 16     // Date range + TODAY
        let verticalPadding: CGFloat = 12       // Total vertical padding
        let cellArea = 7 * cellSize + 6 * gap   // 7 rows + 6 gaps
        return topLabelHeight + cellArea + bottomLabelHeight + verticalPadding
    }

    @ViewBuilder
    private func grid(weeks: [[RenderedDay]], layout: LayoutMetrics) -> some View {
        let labels = monthLabels(for: weeks)

        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .top, spacing: 4) {
                Color.clear.frame(width: weekdayLabelWidth, height: 10)

                ZStack(alignment: .topLeading) {
                    Color.clear.frame(width: layout.gridWidth, height: 10)
                    ForEach(labels, id: \.index) { label in
                        Text(label.name)
                            .font(RetroFont.pixel(7))
                            .foregroundStyle(Theme.retroInkDim)
                            .fixedSize()
                            .offset(x: CGFloat(label.index) * (layout.cell + layout.columnSpacing))
                    }
                }
            }

            HStack(alignment: .top, spacing: 4) {
                weekdayLabels(cell: layout.cell)

                HStack(alignment: .top, spacing: layout.columnSpacing) {
                    ForEach(Array(weeks.enumerated()), id: \.offset) { item in
                        VStack(spacing: gap) {
                            ForEach(item.element) { day in
                                cellView(day: day, size: layout.cell)
                            }
                        }
                        .id(item.offset)
                    }
                }
            }

            HStack(spacing: 8) {
                Text("\(rangeLabelStart) - \(rangeLabelEnd)")
                    .font(RetroFont.pixel(8))
                    .foregroundStyle(Theme.retroInkDim)

                HStack(spacing: 4) {
                    Rectangle()
                        .stroke(Theme.retroCyan, lineWidth: 2)
                        .frame(width: 10, height: 10)
                    Text("TODAY")
                        .font(RetroFont.pixel(8))
                        .foregroundStyle(Theme.retroCyan)
                }
            }
            .padding(.leading, weekdayLabelWidth + 4)
        }
        .padding(.vertical, 2)
        .padding(.horizontal, 2)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Target cell sizes for each range - larger cells for shorter time periods
    private func targetCellSize(for weeks: Int) -> CGFloat {
        switch weeks {
        case ...5: return 28   // 30 days (~5 weeks)
        case ...13: return 18  // 90 days (~13 weeks)
        case ...26: return 12  // 180 days (~26 weeks)
        default: return 8      // 365 days (~53 weeks)
        }
    }

    private func layoutMetrics(weekCount: Int, availableWidth: CGFloat) -> LayoutMetrics {
        let columns = max(1, weekCount)
        let gridWidth = max(0, availableWidth - weekdayLabelWidth - 8)

        // Target cell size based on how many weeks we're showing
        let targetSize = targetCellSize(for: columns)

        // Maximum cell size that fits in the available width
        let maxWidthBasedCell = (gridWidth - CGFloat(columns - 1) * gap) / CGFloat(columns)

        // Use the smaller of target or what fits, with bounds
        let cell = max(6, min(targetSize, maxWidthBasedCell))

        // Minimal gap between columns
        let columnSpacing = gap

        return LayoutMetrics(
            cell: cell,
            columnSpacing: columnSpacing,
            gridWidth: gridWidth
        )
    }

    private func weekdayLabels(cell: CGFloat) -> some View {
        VStack(spacing: gap) {
            ForEach(Array(["M", "T", "W", "T", "F", "S", "S"].enumerated()), id: \.offset) { _, label in
                Text(label)
                    .font(RetroFont.pixel(7))
                    .foregroundStyle(Theme.retroInkDim)
                    .frame(width: weekdayLabelWidth, height: cell, alignment: .trailing)
            }
        }
    }

    private func monthName(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM"
        return formatter.string(from: date).uppercased()
    }

    @ViewBuilder
    private func cellView(day: RenderedDay, size: CGFloat) -> some View {
        Rectangle()
            .fill(color(for: day))
            .frame(width: size, height: size)
            .overlay {
                if day.isToday {
                    Rectangle().stroke(Theme.retroCyan, lineWidth: 2)
                }
            }
            .accessibilityLabel(accessibilityLabel(for: day))
    }

    /// Binary color scheme: met = accent, miss/data = faint, range/future padding = dim background.
    private func color(for day: RenderedDay) -> Color {
        guard day.isInRange else { return Theme.retroInkFaint.opacity(day.isFuture ? 0.12 : 0.18) }
        if day.met { return accent }
        if day.value > 0 { return Theme.retroInkFaint.opacity(0.5) }
        return Theme.retroInkFaint.opacity(0.2)
    }

    private var rangeLabelStart: String {
        rangeLabel(for: firstVisibleDay)
    }

    private var rangeLabelEnd: String {
        rangeLabel(for: today)
    }

    private func accessibilityLabel(for day: RenderedDay) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        let date = formatter.string(from: day.date)
        if day.isFuture { return "\(date), future day" }
        if !day.isInRange { return "\(date), outside selected range" }
        return "\(date), \(day.met ? "goal met" : "goal missed")"
    }

    private func rangeLabel(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("MMM d")
        return formatter.string(from: date).uppercased()
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

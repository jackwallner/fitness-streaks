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

    var weeksCount: Int {
        (days + 6) / 7
    }

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

/// Calendar heatmap that completely fills its container.
/// Dynamically calculates cell size to fit available width + height perfectly.
struct CalendarHeatmap: View {
    let entries: [HeatmapDay]
    let accent: Color
    @Binding var selectedRange: HeatmapDateRange

    private let gap: CGFloat = 2
    private let weekdayLabelWidth: CGFloat = 16
    private let headerHeight: CGFloat = 16
    private let footerHeight: CGFloat = 20

    private struct RenderedDay: Identifiable, Hashable {
        let date: Date
        let value: Double
        let met: Bool
        let isInRange: Bool
        let isToday: Bool
        let isFuture: Bool
        var id: String { DateHelpers.dayKey(date) }

        static func == (lhs: RenderedDay, rhs: RenderedDay) -> Bool {
            lhs.id == rhs.id
        }

        func hash(into hasher: inout Hasher) {
            hasher.combine(id)
        }
    }

    private var today: Date { DateHelpers.startOfDay() }
    private var firstVisibleDay: Date {
        DateHelpers.addDays(-(selectedRange.days - 1), to: today)
    }

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

    var body: some View {
        let weeks = calendarWeeks

        GeometryReader { proxy in
            let layout = calculateLayout(weeks: weeks, size: proxy.size)

            VStack(alignment: .leading, spacing: 4) {
                // Month labels header
                monthLabelsRow(weeks: weeks, layout: layout)
                    .frame(height: headerHeight)

                // Main grid - fills remaining space
                gridRow(weeks: weeks, layout: layout)
                    .frame(height: layout.gridHeight)

                // Footer legend
                legendRow()
                    .frame(height: footerHeight)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
    }

    // MARK: - Layout Calculation

    private struct Layout {
        let cellWidth: CGFloat
        let cellHeight: CGFloat
        let gap: CGFloat
        let gridWidth: CGFloat
        let gridHeight: CGFloat
    }

    private func calculateLayout(weeks: [[RenderedDay]], size: CGSize) -> Layout {
        let weekCount = CGFloat(weeks.count)
        let rowCount: CGFloat = 7

        // Available space for the grid itself
        let availableWidth = size.width - weekdayLabelWidth - 8
        let availableHeight = size.height - headerHeight - footerHeight - 8

        // Use ALL available width - calculate cell width independently
        let cellWidth = (availableWidth - (weekCount - 1) * gap) / weekCount

        // Use ALL available height - calculate cell height independently  
        let cellHeight = (availableHeight - (rowCount - 1) * gap) / rowCount

        // Actual grid dimensions fill the container
        let actualGridWidth = weekCount * cellWidth + (weekCount - 1) * gap
        let actualGridHeight = rowCount * cellHeight + (rowCount - 1) * gap

        return Layout(
            cellWidth: max(2, cellWidth),
            cellHeight: max(8, cellHeight), // Minimum 8pt height for visibility
            gap: gap,
            gridWidth: actualGridWidth,
            gridHeight: actualGridHeight
        )
    }

    // MARK: - Views

    private func monthLabelsRow(weeks: [[RenderedDay]], layout: Layout) -> some View {
        let labels = monthLabels(for: weeks, cellWidth: layout.cellWidth, gap: layout.gap)

        return HStack(spacing: 0) {
            Color.clear.frame(width: weekdayLabelWidth)

            ZStack(alignment: .topLeading) {
                Color.clear.frame(width: layout.gridWidth, height: headerHeight)

                ForEach(labels.indices, id: \.self) { i in
                    let label = labels[i]
                    Text(label.name)
                        .font(RetroFont.pixel(7))
                        .foregroundStyle(Theme.retroInkDim)
                        .position(
                            x: CGFloat(label.index) * (layout.cellWidth + layout.gap) + layout.cellWidth/2,
                            y: headerHeight/2
                        )
                }
            }
        }
    }

    private func gridRow(weeks: [[RenderedDay]], layout: Layout) -> some View {
        HStack(alignment: .top, spacing: 4) {
            weekdayLabels(cellHeight: layout.cellHeight)
                .frame(width: weekdayLabelWidth)

            HStack(alignment: .top, spacing: layout.gap) {
                ForEach(weeks.indices, id: \.self) { index in
                    weekColumn(week: weeks[index], layout: layout)
                }
            }
            .frame(width: layout.gridWidth, height: layout.gridHeight)
        }
    }

    private func weekColumn(week: [RenderedDay], layout: Layout) -> some View {
        VStack(spacing: layout.gap) {
            ForEach(week, id: \.id) { day in
                cellView(day: day, width: layout.cellWidth, height: layout.cellHeight)
            }
        }
    }

    @ViewBuilder
    private func cellView(day: RenderedDay, width: CGFloat, height: CGFloat) -> some View {
        Rectangle()
            .fill(color(for: day))
            .frame(width: width, height: height)
            .overlay {
                if day.isToday {
                    Rectangle().stroke(Theme.retroCyan, lineWidth: max(1, min(width, height)/6))
                }
            }
    }

    private func weekdayLabels(cellHeight: CGFloat) -> some View {
        VStack(spacing: gap) {
            ForEach(["M", "T", "W", "T", "F", "S", "S"], id: \.self) { label in
                Text(label)
                    .font(RetroFont.pixel(7))
                    .foregroundStyle(Theme.retroInkDim)
                    .frame(maxWidth: .infinity, minHeight: cellHeight, maxHeight: cellHeight)
            }
        }
    }

    private func legendRow() -> some View {
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

            Spacer()
        }
        .padding(.leading, weekdayLabelWidth + 4)
    }

    // MARK: - Helpers

    private func monthLabels(for weeks: [[RenderedDay]], cellWidth: CGFloat, gap: CGFloat) -> [(index: Int, name: String)] {
        var labels: [(Int, String)] = []
        var lastMonth: Int?
        var lastIndex: Int = -10 // Ensure first label always shows

        // Minimum pixel spacing between labels to prevent overlap
        let minLabelSpacing: CGFloat = 28

        for (index, week) in weeks.enumerated() {
            guard let firstDay = week.first(where: { $0.isInRange })?.date else { continue }
            let month = DateHelpers.gregorian.component(.month, from: firstDay)

            if month != lastMonth {
                let pixelPosition = CGFloat(index) * (cellWidth + gap)
                let lastPosition = CGFloat(lastIndex) * (cellWidth + gap)

                // Only add label if it's far enough from the last one
                if pixelPosition - lastPosition >= minLabelSpacing {
                    labels.append((index, monthName(for: firstDay)))
                    lastIndex = index
                }
                lastMonth = month
            }
        }
        return labels
    }

    private func color(for day: RenderedDay) -> Color {
        guard day.isInRange else { return Theme.retroInkFaint.opacity(day.isFuture ? 0.12 : 0.18) }
        if day.met { return accent }
        if day.value > 0 { return Theme.retroInkFaint.opacity(0.5) }
        return Theme.retroInkFaint.opacity(0.2)
    }

    private func monthName(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM"
        return formatter.string(from: date).uppercased()
    }

    private var rangeLabelStart: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: firstVisibleDay).uppercased()
    }

    private var rangeLabelEnd: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: today).uppercased()
    }
}

// MARK: - Range Picker

struct HeatmapRangePicker: View {
    @Binding var selectedRange: HeatmapDateRange

    var body: some View {
        HStack(spacing: 8) {
            ForEach(HeatmapDateRange.allCases, id: \.self) { range in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedRange = range
                    }
                } label: {
                    Text(range.label)
                        .font(RetroFont.mono(10, weight: selectedRange == range ? .bold : .regular))
                        .foregroundStyle(selectedRange == range ? Theme.retroBg : Theme.retroInk)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(selectedRange == range ? Theme.retroCyan : Color.clear)
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
    }
}

import SwiftUI

/// Date range options for the heatmap
enum HeatmapDateRange: String, CaseIterable {
    case last30Days = "30d"
    case last90Days = "90d"
    case last180Days = "6mo"
    case lookbackPeriod = "LOOKBACK"
    case fullYear = "1yr"

    var label: String {
        switch self {
        case .last30Days: return "30d"
        case .last90Days: return "90d"
        case .last180Days: return "6mo"
        case .lookbackPeriod: return "LOOKBACK"
        case .fullYear: return "1yr"
        }
    }

    func days(lookbackDays: Int) -> Int {
        switch self {
        case .last30Days: return 30
        case .last90Days: return 90
        case .last180Days: return 180
        case .lookbackPeriod: return lookbackDays
        case .fullYear: return 365
        }
    }
}

/// Pixel calendar heatmap. Columns = weeks, rows = weekdays (Mon–Sun).
/// Sharp square cells, no corner radius. Binary colors for pass/fail goals.
struct CalendarHeatmap: View {
    let entries: [(date: Date, value: Double, met: Bool)]
    let accent: Color
    @Binding var selectedRange: HeatmapDateRange
    let lookbackDays: Int

    private let cell: CGFloat = 8
    private let gap: CGFloat = 2

    /// Filter entries based on selected date range
    private var filteredEntries: [(date: Date, value: Double, met: Bool)] {
        let days = selectedRange.days(lookbackDays: lookbackDays)
        let cutoff = DateHelpers.addDays(-days, to: DateHelpers.startOfDay())
        return entries.filter { $0.date >= cutoff }
    }

    var body: some View {
        let weeks = groupByWeek(filteredEntries)
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
            .onChange(of: selectedRange) { _, _ in
                // Scroll to end when range changes
                DispatchQueue.main.async {
                    withAnimation {
                        proxy.scrollTo(weeks.count - 1, anchor: .trailing)
                    }
                }
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
    }

    /// Binary color scheme: met = accent, not met but has data = faint accent, no data = background
    private func color(for day: (date: Date, value: Double, met: Bool)?) -> Color {
        guard let day else { return Theme.retroInkFaint.opacity(0.5) }
        if day.met { return accent }
        if day.value > 0 { return Theme.retroInkFaint.opacity(0.5) }
        return Theme.retroInkFaint.opacity(0.2)
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

/// Date range picker for heatmap
struct HeatmapRangePicker: View {
    @Binding var selectedRange: HeatmapDateRange
    let lookbackDays: Int

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

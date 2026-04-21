import SwiftUI

struct StreakDetailView: View {
    let streak: Streak
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var store: StreakStore

    var isHero: Bool { store.hero?.id == streak.id }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                headerCard.padding(.horizontal, 14)
                todayCard.padding(.horizontal, 14)

                PixelSectionHeader(title: streak.cadence == .daily ? "Last 365 Days" : "Weekly Hits")
                    .padding(.top, 4)

                heatmapCard.padding(.horizontal, 14)
                statsRow.padding(.horizontal, 14)

                if isHero { weekdayHistogram.padding(.horizontal, 14) }
                if isHero { thresholdLadder.padding(.horizontal, 14) }
            }
            .padding(.vertical, 16)
        }
        .background(Theme.retroBg.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button { dismiss() } label: {
                    Text("◄ BACK")
                        .font(RetroFont.pixel(10))
                        .foregroundStyle(Theme.retroMagenta)
                }
            }
            ToolbarItem(placement: .principal) {
                Text(streak.metric.displayName.uppercased())
                    .font(RetroFont.pixel(10))
                    .tracking(2)
                    .foregroundStyle(Theme.retroInkDim)
            }
        }
        .toolbarBackground(Theme.retroBg, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
    }

    // MARK: - Header

    private var headerCard: some View {
        VStack(spacing: 10) {
            Image(systemName: streak.metric.symbol)
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(streak.metric.accent)
                .shadow(color: streak.metric.accent.opacity(0.6), radius: 10)

            Text("\(streak.current)")
                .font(RetroFont.pixel(72))
                .tracking(2)
                .foregroundStyle(streak.metric.accent)
                .retroGlow(streak.metric.accent)
                .minimumScaleFactor(0.5)
                .lineLimit(1)

            Text(streak.cadence == .daily ? "DAYS IN A ROW" : "WEEKS IN A ROW")
                .font(RetroFont.pixel(11))
                .tracking(2)
                .foregroundStyle(Theme.retroInk)

            Text(streak.metric.prose(streak.threshold, cadence: streak.cadence))
                .font(RetroFont.mono(12))
                .foregroundStyle(Theme.retroInkDim)
                .multilineTextAlignment(.center)
                .padding(.top, 6)
        }
        .padding(.vertical, 22)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity)
        .pixelPanel(color: streak.metric.accent)
    }

    // MARK: - Today card

    private var todayCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(streak.cadence == .daily ? "TODAY" : "THIS WEEK")
                    .font(RetroFont.pixel(9))
                    .tracking(2)
                    .foregroundStyle(Theme.retroInkDim)
                Spacer()
                if streak.currentUnitCompleted {
                    Text("✓ LOCKED")
                        .font(RetroFont.pixel(9))
                        .foregroundStyle(Theme.retroLime)
                } else {
                    Text("\(Int(min(1, streak.currentUnitProgress) * 100))%")
                        .font(RetroFont.pixel(9))
                        .foregroundStyle(Theme.retroAmber)
                }
            }
            PixelProgressBar(progress: streak.currentUnitProgress,
                             accent: streak.currentUnitCompleted ? Theme.retroLime : Theme.retroAmber)
        }
        .padding(14)
        .pixelPanel(color: Theme.retroAmber)
    }

    // MARK: - Heatmap

    private var heatmapCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            if streak.cadence == .daily {
                CalendarHeatmap(
                    entries: StreakEngine.dailyHistory(
                        for: streak.metric,
                        threshold: streak.threshold,
                        history: store.history
                    ),
                    accent: streak.metric.accent
                )
                legendRow
            } else {
                weeklyBars
                legendRow
            }
        }
        .padding(14)
        .pixelPanel(color: streak.metric.accent)
    }

    private var legendRow: some View {
        HStack(spacing: 6) {
            Text("LESS")
                .font(RetroFont.pixel(8))
                .foregroundStyle(Theme.retroInkDim)
            ForEach(0..<4) { i in
                Rectangle()
                    .fill(swatchColor(i))
                    .frame(width: 10, height: 10)
            }
            Text("MORE")
                .font(RetroFont.pixel(8))
                .foregroundStyle(Theme.retroInkDim)
            Spacer()
            Text("AVG \(String(format: "%.1f", avgHitsPerWeek)) HITS/WK")
                .font(RetroFont.pixel(8))
                .foregroundStyle(Theme.retroInkDim)
        }
    }

    private func swatchColor(_ i: Int) -> Color {
        let accent = streak.metric.accent
        switch i {
        case 0: return Theme.retroInkFaint.opacity(0.5)
        case 1: return accent.opacity(0.3)
        case 2: return accent.opacity(0.6)
        default: return accent
        }
    }

    private var avgHitsPerWeek: Double {
        let hits = StreakEngine.dailyHistory(for: streak.metric, threshold: streak.threshold, history: store.history)
            .filter(\.met).count
        let weeks = max(1, store.history.count / 7)
        return Double(hits) / Double(weeks)
    }

    private var weeklyBars: some View {
        let weeks = StreakEngine.weeklyHistory(for: streak.metric, threshold: streak.threshold, history: store.history)
        let maxVal = max(streak.threshold * 1.4, weeks.map(\.total).max() ?? streak.threshold)
        return HStack(alignment: .bottom, spacing: 3) {
            ForEach(Array(weeks.enumerated()), id: \.offset) { _, w in
                Rectangle()
                    .fill(w.met ? streak.metric.accent : streak.metric.accent.opacity(0.25))
                    .frame(height: max(4, CGFloat(w.total / maxVal) * 80))
            }
        }
        .frame(height: 80)
    }

    // MARK: - Stats row

    private var statsRow: some View {
        HStack(spacing: 8) {
            statCell(title: "CURRENT",
                     value: "\(streak.current)",
                     unit: streak.cadence == .daily ? "DAYS" : "WKS",
                     color: streak.metric.accent)
            statCell(title: "BEST",
                     value: "\(streak.best)",
                     unit: streak.cadence == .daily ? "DAYS" : "WKS",
                     color: Theme.retroAmber)
            statCell(title: streak.cadence == .daily ? "TODAY" : "WEEK",
                     value: streak.metric.format(value: streak.currentUnitValue),
                     unit: streak.metric.unitLabel.uppercased(),
                     color: Theme.retroLime)
        }
    }

    private func statCell(title: String, value: String, unit: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(RetroFont.pixel(8))
                .tracking(1)
                .foregroundStyle(Theme.retroInkDim)
            Text(value)
                .font(RetroFont.pixel(20))
                .foregroundStyle(color)
                .retroGlow(color, radius: 8)
                .minimumScaleFactor(0.5)
                .lineLimit(1)
            Text(unit)
                .font(RetroFont.pixel(8))
                .foregroundStyle(Theme.retroInkDim)
                .lineLimit(1)
        }
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity)
        .pixelPanel(color: Theme.retroInkFaint)
    }

    // MARK: - Weekday histogram (hero only)

    private var weekdayHistogram: some View {
        let vals = weekdayValues()
        let median = vals.sorted()[vals.count / 2]
        let maxVal = max(1, vals.max() ?? 1)
        return VStack(alignment: .leading, spacing: 10) {
            Text("BY DAY OF WEEK")
                .font(RetroFont.pixel(9))
                .tracking(2)
                .foregroundStyle(Theme.retroInkDim)
            HStack(alignment: .bottom, spacing: 6) {
                ForEach(0..<7, id: \.self) { i in
                    VStack(spacing: 4) {
                        Rectangle()
                            .fill(vals[i] > median ? streak.metric.accent : Theme.retroInkFaint)
                            .frame(height: max(4, CGFloat(vals[i] / maxVal) * 60))
                        Text(["M","T","W","T","F","S","S"][i])
                            .font(RetroFont.pixel(8))
                            .foregroundStyle(Theme.retroInkDim)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(14)
        .pixelPanel(color: Theme.retroCyan)
    }

    private func weekdayValues() -> [Double] {
        var sums = [Double](repeating: 0, count: 7)
        var counts = [Double](repeating: 0, count: 7)
        let cal = DateHelpers.gregorian
        for d in store.history {
            let wd = cal.component(.weekday, from: d.date) // 1=Sun
            let idx = (wd + 5) % 7 // 0=Mon
            sums[idx] += d.value(for: streak.metric)
            counts[idx] += 1
        }
        return (0..<7).map { counts[$0] > 0 ? sums[$0] / counts[$0] : 0 }
    }

    // MARK: - Threshold ladder (hero only)

    private var thresholdLadder: some View {
        let thresholds = streak.cadence == .daily
            ? streak.metric.dailyThresholds
            : (streak.metric.weeklyThresholds ?? [])

        return VStack(alignment: .leading, spacing: 0) {
            Text("THRESHOLD TIERS")
                .font(RetroFont.pixel(9))
                .tracking(2)
                .foregroundStyle(Theme.retroInkDim)
                .padding(.bottom, 10)

            ForEach(thresholds, id: \.self) { t in
                ladderRow(threshold: t)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .pixelPanel(color: Theme.retroAmber)
    }

    private func ladderRow(threshold t: Double) -> some View {
        let s: Streak = {
            if streak.cadence == .daily {
                return StreakEngine.computeDailyStreak(
                    metric: streak.metric,
                    threshold: t,
                    byDay: Dictionary(uniqueKeysWithValues: store.history.map { ($0.date, $0) }),
                    today: DateHelpers.startOfDay()
                )
            }
            let totals = StreakEngine.weeklyTotals(
                for: streak.metric,
                byDay: Dictionary(uniqueKeysWithValues: store.history.map { ($0.date, $0) })
            )
            return StreakEngine.computeWeeklyStreak(
                metric: streak.metric,
                threshold: t,
                weekTotals: totals,
                thisWeek: DateHelpers.startOfWeek()
            )
        }()
        let active = t == streak.threshold
        return HStack(spacing: 10) {
            Rectangle()
                .fill(streak.metric.accent)
                .frame(width: 4, height: 28)
                .opacity(active ? 1 : 0.2)
                .shadow(color: streak.metric.accent.opacity(active ? 0.8 : 0), radius: 6)
            VStack(alignment: .leading, spacing: 2) {
                Text(streak.metric.thresholdLabel(t, cadence: streak.cadence).uppercased())
                    .font(RetroFont.pixel(10))
                    .foregroundStyle(active ? streak.metric.accent : Theme.retroInk)
                if active {
                    Text("◆ ACTIVE TIER")
                        .font(RetroFont.pixel(8))
                        .foregroundStyle(Theme.retroAmber)
                }
            }
            Spacer()
            Text("\(s.current) / best \(s.best)")
                .font(RetroFont.mono(11))
                .foregroundStyle(Theme.retroInkDim)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, active ? 8 : 0)
        .background(active ? streak.metric.accent.opacity(0.1) : .clear)
    }
}

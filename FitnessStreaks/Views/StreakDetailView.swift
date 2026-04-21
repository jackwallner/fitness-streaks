import SwiftUI

struct StreakDetailView: View {
    let streak: Streak

    @EnvironmentObject var store: StreakStore

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                headerCard
                    .padding(.horizontal, 16)

                heatmapCard
                    .padding(.horizontal, 16)

                statsCard
                    .padding(.horizontal, 16)

                thresholdLadder
                    .padding(.horizontal, 16)
            }
            .padding(.vertical, 16)
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle(streak.metric.displayName)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var headerCard: some View {
        VStack(spacing: 8) {
            Image(systemName: streak.metric.symbol)
                .font(.system(size: 28, weight: .semibold, design: .rounded))
                .foregroundStyle(streak.metric.accent)
                .padding(.bottom, 2)
            Text("\(streak.current)")
                .font(Theme.bigNumber(72))
                .foregroundStyle(streak.metric.accent)
                .monospacedDigit()
            Text("\(streak.cadence == .daily ? (streak.current == 1 ? "day" : "days") : (streak.current == 1 ? "week" : "weeks")) in a row")
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(Theme.textSecondary)
            Text(streak.metric.prose(streak.threshold, cadence: streak.cadence))
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(Theme.textPrimary)
                .multilineTextAlignment(.center)
                .padding(.top, 4)
                .padding(.horizontal, 12)
        }
        .padding(.vertical, 20)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
                .fill(Theme.cardSurface)
        )
    }

    private var heatmapCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(streak.cadence == .daily ? "Last year" : "Weekly hits")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.textTertiary)
                    .textCase(.uppercase)
                Spacer()
                Text(streak.currentUnitCompleted
                     ? (streak.cadence == .daily ? "Today ✓" : "This week ✓")
                     : progressLabel)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(streak.metric.accent)
            }

            if streak.cadence == .daily {
                CalendarHeatmap(
                    entries: StreakEngine.dailyHistory(
                        for: streak.metric,
                        threshold: streak.threshold,
                        history: store.history
                    ),
                    accent: streak.metric.accent
                )
            } else {
                weeklyBars
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
                .fill(Theme.cardSurface)
        )
    }

    private var weeklyBars: some View {
        let weeks = StreakEngine.weeklyHistory(for: streak.metric, threshold: streak.threshold, history: store.history)
        let maxVal = max(streak.threshold * 1.4, weeks.map(\.total).max() ?? streak.threshold)
        return HStack(alignment: .bottom, spacing: 3) {
            ForEach(Array(weeks.enumerated()), id: \.offset) { _, w in
                RoundedRectangle(cornerRadius: 2)
                    .fill(w.met ? streak.metric.accent : streak.metric.accent.opacity(0.25))
                    .frame(height: max(4, CGFloat(w.total / maxVal) * 80))
            }
        }
        .frame(height: 80)
    }

    private var statsCard: some View {
        HStack(spacing: 0) {
            statCell(title: "Current", value: "\(streak.current)", unit: streak.cadence.pluralLabel)
            Divider().frame(height: 40).background(Theme.ringTrack)
            statCell(title: "Best ever", value: "\(streak.best)", unit: streak.cadence.pluralLabel)
            Divider().frame(height: 40).background(Theme.ringTrack)
            statCell(
                title: streak.cadence == .daily ? "Today" : "This week",
                value: streak.metric.format(value: streak.currentUnitValue),
                unit: streak.metric.unitLabel
            )
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
                .fill(Theme.cardSurface)
        )
    }

    private func statCell(title: String, value: String, unit: String) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.textPrimary)
                .monospacedDigit()
            Text(unit)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(Theme.textTertiary)
            Text(title)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(Theme.textSecondary)
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
    }

    private var thresholdLadder: some View {
        let thresholds = streak.cadence == .daily
            ? streak.metric.dailyThresholds
            : (streak.metric.weeklyThresholds ?? [])

        return VStack(alignment: .leading, spacing: 10) {
            Text("All your streaks for \(streak.metric.displayName.lowercased())")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(Theme.textTertiary)
                .textCase(.uppercase)

            ForEach(thresholds, id: \.self) { t in
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
                HStack {
                    Text(streak.metric.thresholdLabel(t, cadence: streak.cadence))
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(t == streak.threshold ? streak.metric.accent : Theme.textPrimary)
                    Spacer()
                    Text("\(s.current) / best \(s.best)")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(Theme.textSecondary)
                        .monospacedDigit()
                }
                .padding(.vertical, 6)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
                .fill(Theme.cardSurface)
        )
    }

    private var progressLabel: String {
        let pct = Int(min(1.0, streak.currentUnitProgress) * 100)
        return "\(pct)% of today"
    }
}

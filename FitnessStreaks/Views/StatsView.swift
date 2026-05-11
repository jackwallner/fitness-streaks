import SwiftUI

/// The "Stats" tab — aggregate view across every tracked streak. Per-streak rows
/// push to `StreakDetailView` for the full history/heatmap drill-down.
struct StatsView: View {
    @EnvironmentObject var store: StreakStore
    @EnvironmentObject var settings: StreakSettings

    @State private var selectedStreak: Streak? = nil

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if store.streaks.isEmpty {
                        emptyState
                    } else {
                        topRow
                        completionRateCard
                        streakList
                    }
                }
                .padding(.horizontal, 14)
                .padding(.top, 14)
                .padding(.bottom, 24)
            }
            .background(Theme.retroBg.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("STATS")
                        .font(RetroFont.pixel(12))
                        .tracking(2)
                        .foregroundStyle(Theme.retroCyan)
                }
            }
            .toolbarBackground(Theme.retroBg, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .navigationDestination(item: $selectedStreak) { streak in
                StreakDetailView(streak: streak)
            }
        }
    }

    // MARK: - Top row: 3 aggregate stat cells

    private var topRow: some View {
        HStack(spacing: 8) {
            cell(title: "ACTIVE", value: "\(activeCount)", unit: "STREAKS", color: Theme.retroLime)
            cell(title: "TOTAL", value: "\(totalCurrentDays)", unit: "DAYS COMBINED", color: Theme.retroMagenta)
            cell(title: "BEST", value: "\(longestEver)", unit: longestEverLabel, color: Theme.retroAmber)
        }
    }

    private func cell(title: String, value: String, unit: String, color: Color) -> some View {
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
                .minimumScaleFactor(0.7)
        }
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity)
        .pixelPanel(color: Theme.retroInkFaint)
    }

    private var activeCount: Int { store.streaks.count }

    private var totalCurrentDays: Int {
        store.streaks.reduce(0) { $0 + $1.current }
    }

    private var longestEver: Int {
        store.streaks.map(\.best).max() ?? 0
    }

    private var longestEverLabel: String {
        guard let top = store.streaks.max(by: { $0.best < $1.best }) else { return "RECORD" }
        return top.metric.displayName.uppercased()
    }

    // MARK: - Completion rate

    private var avgCompletionRate: Double {
        guard !store.streaks.isEmpty else { return 0 }
        let sum = store.streaks.reduce(0.0) { $0 + $1.completionRate }
        return sum / Double(store.streaks.count)
    }

    private var totalSaves: Int { settings.gracePreservations.count }

    private var completionRateCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            PixelSectionHeader(title: "Across all streaks")
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("AVG COMPLETION")
                        .font(RetroFont.pixel(10))
                        .tracking(1)
                        .foregroundStyle(Theme.retroInkDim)
                    Spacer()
                    Text("\(Int(avgCompletionRate * 100))%")
                        .font(RetroFont.pixel(14))
                        .foregroundStyle(Theme.retroMagenta)
                }
                PixelProgressBar(progress: avgCompletionRate, accent: Theme.retroMagenta, segments: 24, height: 14)

                Rectangle()
                    .fill(Theme.retroInkFaint.opacity(0.6))
                    .frame(height: 1)

                HStack {
                    Text("PRO SAVES TO DATE")
                        .font(RetroFont.pixel(10))
                        .tracking(1)
                        .foregroundStyle(Theme.retroInkDim)
                    Spacer()
                    Text("\(totalSaves)")
                        .font(RetroFont.pixel(14))
                        .foregroundStyle(Theme.retroLime)
                }
            }
            .padding(14)
            .pixelPanel(color: Theme.retroInkFaint)
        }
    }

    // MARK: - Per-streak list

    private var streakList: some View {
        VStack(alignment: .leading, spacing: 10) {
            PixelSectionHeader(title: "Streak Breakdown")
            VStack(spacing: 0) {
                ForEach(Array(store.streaks.enumerated()), id: \.element.id) { idx, streak in
                    Button {
                        selectedStreak = streak
                    } label: {
                        streakRow(streak)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(streak.metric.displayName), \(streak.current) \(streak.cadence.pluralLabel), \(Int(streak.completionRate * 100)) percent completion")
                    if idx < store.streaks.count - 1 {
                        Rectangle()
                            .fill(Theme.retroInkFaint.opacity(0.6))
                            .frame(height: 1)
                            .padding(.horizontal, 14)
                    }
                }
            }
            .pixelPanel(color: Theme.retroInkFaint)
        }
    }

    private func streakRow(_ streak: Streak) -> some View {
        HStack(spacing: 12) {
            Image(systemName: streak.displaySymbol)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(streak.metric.accent)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(streak.displayName.uppercased())
                    .font(RetroFont.pixel(11))
                    .foregroundStyle(Theme.retroInk)
                Text("\(streak.current) \(streak.cadence.pluralLabel) · best \(streak.best) · \(Int(streak.completionRate * 100))%")
                    .font(RetroFont.mono(10))
                    .foregroundStyle(Theme.retroInkDim)
            }
            Spacer()
            Text("›")
                .font(RetroFont.mono(14, weight: .bold))
                .foregroundStyle(Theme.retroInkDim)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
        .contentShape(Rectangle())
    }

    // MARK: - Empty

    private var emptyState: some View {
        VStack(spacing: 14) {
            PixelFlame(size: 64, intensity: 0.5, tint: Theme.retroInkDim)
                .padding(.top, 60)
            Text("NO STATS YET")
                .font(RetroFont.pixel(12))
                .tracking(2)
                .foregroundStyle(Theme.retroInk)
            Text("Find some streaks on the Streaks tab and your stats will show up here.")
                .font(RetroFont.mono(11))
                .foregroundStyle(Theme.retroInkDim)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity)
    }
}

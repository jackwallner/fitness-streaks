import SwiftUI

/// Reusable list of candidate streaks with toggles. Used in onboarding and Settings.
///
/// `selection` is a Set of "metric-cadence" keys. Binding so callers can persist as they wish.
struct StreakPickerList: View {
    let candidates: [Streak]
    @Binding var selection: Set<String>

    /// Highlight the top N as "recommended" — engine already sorted by vibe score.
    let recommendedCount: Int

    var body: some View {
        VStack(spacing: 8) {
            ForEach(Array(candidates.enumerated()), id: \.element.id) { idx, streak in
                row(streak, recommended: idx < recommendedCount)
            }
        }
    }

    private func row(_ streak: Streak, recommended: Bool) -> some View {
        let key = StreakSettings.streakKey(metric: streak.metric, cadence: streak.cadence)
        let on = selection.contains(key)
        let accent = streak.metric.accent
        return Button {
            if on { selection.remove(key) } else { selection.insert(key) }
        } label: {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: streak.metric.symbol)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(accent)
                    .shadow(color: accent.opacity(0.6), radius: 4)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(streak.metric.displayName.uppercased())
                            .font(RetroFont.mono(11, weight: .bold))
                            .tracking(1)
                            .foregroundStyle(Theme.retroInk)
                        Text(streak.cadence == .daily ? "DAILY" : "WEEKLY")
                            .font(RetroFont.mono(9, weight: .bold))
                            .foregroundStyle(Theme.retroInkDim)
                        if recommended {
                            Text("★")
                                .font(RetroFont.mono(9, weight: .bold))
                                .foregroundStyle(Theme.retroAmber)
                        }
                    }
                    Text(subtitle(for: streak))
                        .font(RetroFont.mono(10))
                        .foregroundStyle(Theme.retroInkDim)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)

                Text(on ? "◉" : "○")
                    .font(RetroFont.mono(18, weight: .bold))
                    .foregroundStyle(on ? accent : Theme.retroInkFaint)
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .pixelPanel(color: on ? accent : Theme.retroInkFaint,
                        fill: on ? Theme.retroBgCard : Theme.retroBgRaised)
        }
        .buttonStyle(.plain)
    }

    private func subtitle(for streak: Streak) -> String {
        let label = streak.metric.thresholdLabel(streak.threshold, cadence: streak.cadence)
        let unit = streak.cadence == .daily ? "days" : "wks"
        return "\(streak.current) \(unit) · \(label)"
    }
}

/// Full-screen picker presented from Settings. Onboarding embeds StreakPickerList directly.
struct StreakPickerSheet: View {
    @EnvironmentObject var store: StreakStore
    @EnvironmentObject var settings: StreakSettings
    @Environment(\.dismiss) private var dismiss

    @State private var selection: Set<String> = []

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Pick the streaks you want on your dashboard. ★ are the most interesting for your current vibe.")
                        .font(RetroFont.mono(11))
                        .foregroundStyle(Theme.retroInkDim)
                        .lineSpacing(2)
                        .padding(.horizontal, 14)

                    StreakPickerList(
                        candidates: store.allCandidates,
                        selection: $selection,
                        recommendedCount: min(5, store.allCandidates.count)
                    )
                    .padding(.horizontal, 14)

                    if store.allCandidates.isEmpty {
                        Text("No streaks discovered yet — pull to refresh once Apple Health has some activity.")
                            .font(RetroFont.mono(11))
                            .foregroundStyle(Theme.retroInkDim)
                            .padding(.horizontal, 14)
                            .padding(.top, 40)
                    }
                }
                .padding(.vertical, 16)
            }
            .background(Theme.retroBg.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("TRACKED STREAKS")
                        .font(RetroFont.mono(12, weight: .bold))
                        .tracking(2)
                        .foregroundStyle(Theme.retroMagenta)
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button { dismiss() } label: {
                        Text("CANCEL")
                            .font(RetroFont.mono(10, weight: .bold))
                            .foregroundStyle(Theme.retroInkDim)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { save() } label: {
                        Text("SAVE")
                            .font(RetroFont.mono(10, weight: .bold))
                            .foregroundStyle(Theme.retroLime)
                    }
                }
            }
            .toolbarBackground(Theme.retroBg, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
        .onAppear {
            if let current = settings.trackedStreaks {
                selection = current
            } else {
                // First time — preselect the recommended top 5
                selection = Set(store.allCandidates.prefix(5).map {
                    StreakSettings.streakKey(metric: $0.metric, cadence: $0.cadence)
                })
            }
        }
    }

    private func save() {
        settings.trackedStreaks = selection
        store.refilter()
        dismiss()
    }
}

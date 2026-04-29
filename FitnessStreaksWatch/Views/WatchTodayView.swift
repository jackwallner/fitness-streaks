import SwiftUI

struct WatchTodayView: View {
    @EnvironmentObject var store: StreakStore

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                if let hero = store.hero {
                    heroView(hero)
                    Divider()
                    ForEach(Array(store.badges.prefix(6))) { b in
                        badgeRow(b)
                    }
                } else if store.isLoading {
                    ProgressView().padding(.top, 30)
                } else {
                    Text("No streaks yet.\nMove a bit today.")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.top, 30)
                }
            }
            .padding(.horizontal, 4)
        }
        .refreshable { await store.load() }
    }

    private func heroView(_ s: Streak) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: s.displaySymbol)
                    .foregroundStyle(Theme.streakHot)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                Text(s.displayName)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
            }
            Text("\(s.current)")
                .font(.system(size: 48, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.streakGradient)
                .monospacedDigit()
            Text(s.cadence == .daily ? (s.current == 1 ? "day" : "days") : (s.current == 1 ? "week" : "weeks"))
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
            Text(s.thresholdLabel)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(.vertical, 4)
    }

    private func badgeRow(_ s: Streak) -> some View {
        HStack(spacing: 8) {
            Image(systemName: s.displaySymbol)
                .foregroundStyle(s.metric.accent)
                .font(.system(size: 13, weight: .semibold))
                .frame(width: 18)
            Text(s.displayName)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
            Spacer()
            Text("\(s.current)")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .monospacedDigit()
            Text(s.cadence == .daily ? "d" : "w")
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}

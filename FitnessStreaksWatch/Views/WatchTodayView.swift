import SwiftUI

struct WatchTodayView: View {
    @EnvironmentObject var store: StreakStore
    @State private var showingDetail: Streak? = nil

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                if let hero = store.hero {
                    freshnessIndicator
                    heroView(hero)
                    Divider()
                    ForEach(Array(store.badges.prefix(6))) { b in
                        badgeRow(b)
                    }
                } else if store.isLoading {
                    ProgressView().padding(.top, 30)
                } else {
                    VStack(spacing: 8) {
                        Image(systemName: "iphone.and.arrow.forward")
                            .font(.system(size: 28))
                            .foregroundStyle(.secondary)
                        Text("Open the iPhone app\nto sync streaks")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 30)
                }
            }
            .padding(.horizontal, 4)
        }
        .refreshable { await store.load() }
    }

    private var freshnessIndicator: some View {
        let freshness = dataFreshness
        return HStack(spacing: 4) {
            Image(systemName: freshness.icon)
                .font(.system(size: 10))
            Text(freshness.text)
                .font(.system(size: 10, weight: .medium, design: .rounded))
        }
        .foregroundStyle(freshness.color)
        .padding(.top, 2)
    }

    private var dataFreshness: (icon: String, text: String, color: Color) {
        guard let updated = store.lastUpdated else {
            return ("exclamationmark.triangle", "Data age unknown", .orange)
        }
        let age = Date().timeIntervalSince(updated)
        if age < 300 { // < 5 minutes
            return ("checkmark.circle", "Just updated", .green)
        } else if age < 3600 { // < 1 hour
            return ("checkmark.circle", "Updated \(Int(age/60))m ago", .secondary)
        } else if age < 86400 { // < 24 hours
            return ("clock", "Updated \(Int(age/3600))h ago", .secondary)
        } else {
            return ("exclamationmark.circle", "Updated \(Int(age/86400))d ago", .orange)
        }
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

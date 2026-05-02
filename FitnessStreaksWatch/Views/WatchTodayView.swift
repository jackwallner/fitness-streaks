import SwiftUI

struct WatchTodayView: View {
    @EnvironmentObject var store: StreakStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                if let hero = store.hero {
                    header
                    heroCard(hero)

                    if !store.badges.isEmpty {
                        Text("More streaks")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(.secondary)
                            .padding(.top, 4)

                        ForEach(store.badges) { streak in
                            streakCard(streak)
                        }
                    }
                } else if store.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.top, 30)
                } else {
                    emptyState
                }
            }
            .padding(.horizontal, 2)
        }
    }

    private var header: some View {
        let freshness = dataFreshness
        return HStack(spacing: 4) {
            Image(systemName: freshness.icon)
                .font(.system(size: 10, weight: .semibold))
            Text(freshness.text)
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .lineLimit(1)
            Spacer(minLength: 0)
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

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "iphone.and.arrow.forward")
                .font(.system(size: 28))
                .foregroundStyle(.secondary)
            Text("Open Streak Finder on iPhone")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .multilineTextAlignment(.center)
            Text("Your watch will show the latest streak snapshot automatically.")
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 28)
    }

    private func heroCard(_ streak: Streak) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                metricIcon(streak, size: 17)
                Text(streak.displayName)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .lineLimit(1)
                Spacer(minLength: 0)
            }

            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Text("\(streak.current)")
                    .font(.system(size: 58, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.streakGradient)
                    .monospacedDigit()
                    .minimumScaleFactor(0.55)
                Text(unitLabel(for: streak, abbreviated: false))
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            VStack(alignment: .leading, spacing: 5) {
                ProgressView(value: min(max(streak.currentUnitProgress, 0), 1))
                    .tint(streak.metric.accent)
                Text(progressText(for: streak))
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            HStack(spacing: 6) {
                detailPill(streak.thresholdLabel, systemImage: "target")
                detailPill("Best \(streak.best)", systemImage: "crown.fill")
            }
        }
        .padding(10)
        .background(cardBackground)
    }

    private func streakCard(_ streak: Streak) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .firstTextBaseline, spacing: 7) {
                metricIcon(streak, size: 14)
                VStack(alignment: .leading, spacing: 1) {
                    Text(streak.displayName)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .lineLimit(1)
                    Text(streak.thresholdLabel)
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                VStack(alignment: .trailing, spacing: 0) {
                    Text("\(streak.current)")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .monospacedDigit()
                    Text(unitLabel(for: streak, abbreviated: true))
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }

            ProgressView(value: min(max(streak.currentUnitProgress, 0), 1))
                .tint(streak.metric.accent)

            HStack(spacing: 6) {
                Text(progressText(for: streak))
                    .lineLimit(1)
                Spacer(minLength: 0)
                Text("Best \(streak.best)")
                    .lineLimit(1)
            }
            .font(.system(size: 10, weight: .medium, design: .rounded))
            .foregroundStyle(.secondary)
        }
        .padding(9)
        .background(cardBackground)
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(.thinMaterial)
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(.white.opacity(0.08), lineWidth: 1)
            }
    }

    private func metricIcon(_ streak: Streak, size: CGFloat) -> some View {
        Image(systemName: streak.displaySymbol)
            .font(.system(size: size, weight: .semibold, design: .rounded))
            .foregroundStyle(streak.metric.accent)
            .frame(width: size + 7, height: size + 7)
    }

    private func detailPill(_ text: String, systemImage: String) -> some View {
        Label(text, systemImage: systemImage)
            .font(.system(size: 10, weight: .semibold, design: .rounded))
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(.white.opacity(0.08), in: Capsule())
    }

    private func unitLabel(for streak: Streak, abbreviated: Bool) -> String {
        switch streak.cadence {
        case .daily:
            return abbreviated ? "d" : (streak.current == 1 ? "day" : "days")
        case .weekly:
            return abbreviated ? "w" : (streak.current == 1 ? "week" : "weeks")
        }
    }

    private func progressText(for streak: Streak) -> String {
        if streak.currentUnitCompleted {
            return streak.cadence == .daily ? "Today is locked in" : "This week is locked in"
        }
        let current = streak.format(currentUnitValue: streak.currentUnitValue)
        return "\(current) / \(streak.thresholdLabel)"
    }
}

import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var store: StreakStore
    @EnvironmentObject var settings: StreakSettings
    @EnvironmentObject var healthKit: HealthKitService

    @State private var showSettings = false
    @State private var selectedStreak: Streak? = nil

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    topBar

                    if let hero = store.hero {
                        StreakHero(streak: hero)
                            .padding(.top, 10)
                            .onTapGesture { selectedStreak = hero }

                        heroMeta(for: hero)
                            .padding(.horizontal, 20)

                        divider

                        badgesSection
                    } else if store.isLoading {
                        loadingState
                    } else {
                        emptyState
                    }
                }
                .padding(.bottom, 32)
            }
            .background(Theme.background.ignoresSafeArea())
            .refreshable { await store.load() }
            .navigationDestination(item: $selectedStreak) { streak in
                StreakDetailView(streak: streak)
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
        }
    }

    private var topBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Fitness Streaks")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.textPrimary)
                if let updated = store.lastUpdated {
                    Text("Updated \(relative(updated))")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(Theme.textTertiary)
                }
            }
            Spacer()
            Button {
                Task { await store.load() }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.textSecondary)
                    .frame(width: 38, height: 38)
                    .background(Circle().fill(Theme.cardSurface))
            }
            Button { showSettings = true } label: {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.textSecondary)
                    .frame(width: 38, height: 38)
                    .background(Circle().fill(Theme.cardSurface))
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }

    @ViewBuilder
    private func heroMeta(for hero: Streak) -> some View {
        HStack(spacing: 10) {
            metaChip(
                icon: "trophy.fill",
                label: "Best \(hero.best) \(hero.cadence == .daily ? "days" : "weeks")"
            )
            if let start = hero.startDate {
                metaChip(icon: "calendar", label: "Since \(DateHelpers.shortDate(start))")
            }
            if hero.currentUnitCompleted {
                metaChip(icon: "checkmark.seal.fill", label: "Locked in today")
            } else {
                let pct = Int(min(1.0, hero.currentUnitProgress) * 100)
                metaChip(icon: "timer", label: "\(pct)% today")
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private func metaChip(icon: String, label: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
            Text(label)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .foregroundStyle(Theme.textSecondary)
        .background(Capsule().fill(Theme.cardSurface))
    }

    private var divider: some View {
        HStack {
            Text("Other streaks")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(Theme.textTertiary)
                .textCase(.uppercase)
            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.top, 8)
    }

    private var badgesSection: some View {
        LazyVStack(spacing: 10) {
            ForEach(store.badges) { streak in
                Button { selectedStreak = streak } label: {
                    StreakBadgeRow(streak: streak)
                }
                .buttonStyle(.plain)
            }
            if store.badges.isEmpty {
                Text("Build a few more days and more streaks will appear here.")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.textTertiary)
                    .multilineTextAlignment(.center)
                    .padding(.top, 12)
            }
        }
        .padding(.horizontal, 16)
    }

    private var loadingState: some View {
        VStack(spacing: 16) {
            ProgressView()
                .controlSize(.large)
                .padding(.top, 80)
            Text("Reading your Health history…")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(Theme.textSecondary)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "flame")
                .font(.system(size: 56, weight: .regular))
                .foregroundStyle(Theme.streakGradient)
                .padding(.top, 60)
            Text("No active streaks yet")
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .foregroundStyle(Theme.textPrimary)
            Text("Get moving today and your streaks will start building. Pull to refresh.")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }

    private func relative(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: .now)
    }
}

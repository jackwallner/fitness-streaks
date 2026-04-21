import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var store: StreakStore
    @EnvironmentObject var settings: StreakSettings
    @EnvironmentObject var healthKit: HealthKitService

    @State private var showSettings = false
    @State private var selectedStreak: Streak? = nil

    private let grid = [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    topBar
                        .padding(.top, 6)

                    if let hero = store.hero {
                        Button { selectedStreak = hero } label: {
                            StreakHero(streak: hero)
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 6)

                        if !hero.currentUnitCompleted {
                            atRiskBanner(for: hero)
                                .padding(.horizontal, 6)
                        }

                        PixelSectionHeader(title: "Other Streaks · \(store.badges.count) Active")
                            .padding(.top, 6)

                        badgeGrid
                            .padding(.horizontal, 6)
                    } else if store.isLoading {
                        loadingState
                    } else {
                        emptyState
                    }
                }
                .padding(.bottom, 32)
            }
            .background(Theme.retroBg.ignoresSafeArea())
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
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text("▶ STREAK FINDER")
                    .font(RetroFont.pixel(12))
                    .tracking(1)
                    .foregroundStyle(Theme.retroMagenta)
                if let updated = store.lastUpdated {
                    Text("updated \(relative(updated)) · from apple health")
                        .font(RetroFont.mono(10))
                        .foregroundStyle(Theme.retroInkDim)
                } else {
                    Text("from apple health")
                        .font(RetroFont.mono(10))
                        .foregroundStyle(Theme.retroInkDim)
                }
            }
            Spacer()
            Button { showSettings = true } label: {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.retroInkDim)
                    .frame(width: 36, height: 36)
                    .background(Theme.retroBgRaised)
                    .overlay(Rectangle().stroke(Theme.retroInkFaint, lineWidth: 2))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
    }

    private func atRiskBanner(for hero: Streak) -> some View {
        HStack(spacing: 10) {
            Text("! AT RISK")
                .font(RetroFont.pixel(9))
                .tracking(1)
                .foregroundStyle(Theme.retroRed)
            Text(riskText(for: hero))
                .font(RetroFont.mono(11))
                .foregroundStyle(Theme.retroInk)
                .lineLimit(1)
            Spacer()
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .pixelPanel(color: Theme.retroRed, fill: Theme.retroBg)
    }

    private func riskText(for hero: Streak) -> String {
        let remaining = max(0, hero.threshold - hero.currentUnitValue)
        let v = hero.metric.format(value: remaining)
        let unit = hero.metric.unitLabel
        let window = hero.cadence == .daily ? "today" : "this week"
        return "\(v) \(unit) to lock \(window) in"
    }

    private var badgeGrid: some View {
        LazyVGrid(columns: grid, spacing: 8) {
            ForEach(store.badges) { streak in
                Button { selectedStreak = streak } label: {
                    StreakBadgeCard(streak: streak)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var loadingState: some View {
        VStack(spacing: 16) {
            PixelFlame(size: 64, intensity: 0.7)
                .padding(.top, 80)
            Text("LOADING HEALTH...")
                .font(RetroFont.pixel(10))
                .tracking(2)
                .foregroundStyle(Theme.retroInkDim)
        }
        .frame(maxWidth: .infinity)
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            PixelFlame(size: 72, intensity: 0.5, tint: Theme.retroInkDim)
                .padding(.top, 60)
            Text("NO ACTIVE STREAKS")
                .font(RetroFont.pixel(12))
                .tracking(2)
                .foregroundStyle(Theme.retroInk)
            Text("Get moving and they'll start building.\nPull to refresh.")
                .font(RetroFont.mono(11))
                .foregroundStyle(Theme.retroInkDim)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity)
    }

    private func relative(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: .now)
    }
}

import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var store: StreakStore
    @EnvironmentObject var settings: StreakSettings
    @EnvironmentObject var healthKit: HealthKitService

    @State private var showSettings = false
    @State private var selectedStreak: Streak? = nil
    @State private var showPicker = false
    @State private var selectedBroken: BrokenStreak? = nil

    private let grid = [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)]
    private let maxBadges = 4

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 10) {
                topBar
                    .padding(.top, 4)

                if let broken = settings.recentlyBroken.first {
                    brokenBanner(broken)
                        .padding(.horizontal, 6)
                }

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

                    if !visibleBadges.isEmpty {
                        PixelSectionHeader(title: "Other Streaks · \(store.badges.count) Active")
                            .padding(.top, 2)

                        badgeGrid
                            .padding(.horizontal, 6)
                    }

                    findMoreButton
                        .padding(.horizontal, 6)

                    Spacer(minLength: 0)
                } else if store.isLoading {
                    loadingState
                    Spacer(minLength: 0)
                } else {
                    emptyState
                    Spacer(minLength: 0)
                }
            }
            .padding(.bottom, 8)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(Theme.retroBg.ignoresSafeArea())
            .navigationDestination(item: $selectedStreak) { streak in
                StreakDetailView(streak: streak)
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
            .sheet(isPresented: $showPicker) {
                StreakPickerSheet()
            }
            .sheet(item: $selectedBroken) { broken in
                BrokenStreakSheet(broken: broken) {
                    restart(broken)
                } pickNew: {
                    settings.dismissBroken(broken)
                    showPicker = true
                } dismiss: {
                    settings.dismissBroken(broken)
                    store.persistCurrentSnapshot()
                }
            }
        }
    }

    private var visibleBadges: [Streak] {
        Array(store.badges.prefix(maxBadges))
    }

    private var topBar: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text("▶ STREAK FINDER")
                    .font(RetroFont.mono(11, weight: .bold))
                    .tracking(1)
                    .foregroundStyle(Theme.retroMagenta)
                if let updated = store.lastUpdated {
                    Text("updated \(relative(updated)) · apple health")
                        .font(RetroFont.mono(10))
                        .foregroundStyle(Theme.retroInkDim)
                } else {
                    Text("from apple health")
                        .font(RetroFont.mono(10))
                        .foregroundStyle(Theme.retroInkDim)
                }
            }
            Spacer()
            Button {
                Task { await store.load() }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.retroInkDim)
                    .frame(width: 36, height: 36)
                    .background(Theme.retroBgRaised)
                    .overlay(Rectangle().stroke(Theme.retroInkFaint, lineWidth: 2))
            }
            .buttonStyle(.plain)
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
                .font(RetroFont.mono(9, weight: .bold))
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
        if let window = hero.window {
            return "\(v) \(unit) between \(window.label) to lock today in"
        }
        return "\(v) \(unit) to lock today in"
    }

    private func brokenBanner(_ broken: BrokenStreak) -> some View {
        Button {
            selectedBroken = broken
        } label: {
            HStack(spacing: 10) {
                Text("STREAK ENDED")
                    .font(RetroFont.mono(9, weight: .bold))
                    .tracking(1)
                    .foregroundStyle(Theme.retroRed)
                Text("\(broken.brokenLength)-day \(broken.metric.displayName.lowercased()) run · TAP TO RESTART")
                    .font(RetroFont.mono(10))
                    .foregroundStyle(Theme.retroInk)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Spacer()
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .pixelPanel(color: Theme.retroRed, fill: Theme.retroBg)
        }
        .buttonStyle(.plain)
    }

    private var findMoreButton: some View {
        Button {
            showPicker = true
        } label: {
            HStack {
                Text("+ FIND MORE STREAKS")
                    .font(RetroFont.mono(10, weight: .bold))
                    .tracking(1)
                    .foregroundStyle(Theme.retroLime)
                Spacer()
                Text("›")
                    .font(RetroFont.mono(14, weight: .bold))
                    .foregroundStyle(Theme.retroInkDim)
            }
            .padding(12)
            .pixelPanel(color: Theme.retroInkFaint, fill: Theme.retroBgRaised)
        }
        .buttonStyle(.plain)
    }

    private var badgeGrid: some View {
        LazyVGrid(columns: grid, spacing: 8) {
            ForEach(visibleBadges) { streak in
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
                .font(RetroFont.mono(10, weight: .bold))
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
                .font(RetroFont.mono(12, weight: .bold))
                .tracking(2)
                .foregroundStyle(Theme.retroInk)
            Text("If you've been moving lately, double-check Streak Finder has Health access.")
                .font(RetroFont.mono(11))
                .foregroundStyle(Theme.retroInkDim)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            HStack(spacing: 10) {
                Button("+ FIND MORE STREAKS") {
                    showPicker = true
                }
                .buttonStyle(.plain)
                .font(RetroFont.mono(11, weight: .bold))
                .foregroundStyle(Theme.retroBg)
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .background(Theme.retroLime)

                Button("REFRESH") {
                    Task { await store.load() }
                }
                .buttonStyle(.plain)
                .font(RetroFont.mono(11, weight: .bold))
                .foregroundStyle(Theme.retroLime)
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .overlay(Rectangle().stroke(Theme.retroLime, lineWidth: 2))

                Button("HEALTH ACCESS") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                .buttonStyle(.plain)
                .font(RetroFont.mono(11, weight: .bold))
                .foregroundStyle(Theme.retroCyan)
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .overlay(Rectangle().stroke(Theme.retroCyan, lineWidth: 2))
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func relative(_ date: Date) -> String {
        let age = Date().timeIntervalSince(date)
        if age < 30 { return "just updated" }
        if age < 60 { return "<1 min ago" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: .now)
    }

    private func restart(_ broken: BrokenStreak) {
        var tracked = settings.trackedStreaks ?? Set(store.allCandidates.map(\.trackingKey))
        tracked.insert(broken.key)
        settings.trackedStreaks = tracked
        settings.dismissBroken(broken)
        store.refilter()
    }
}

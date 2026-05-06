import SwiftUI
import os

private let log = Logger(subsystem: "com.jackwallner.streaks", category: "Dashboard")

struct DashboardView: View {
    @EnvironmentObject var store: StreakStore
    @EnvironmentObject var settings: StreakSettings
    @EnvironmentObject var healthKit: HealthKitService

    @State private var showSettings = false
    @State private var selectedStreak: Streak? = nil
    @State private var showPicker = false
    @State private var selectedBroken: BrokenStreak? = nil
    @State private var requestingHealthAccess = false
    @State private var healthAccessErrorText: String? = nil

    private let grid = [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)]
    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter
    }()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    topBar
                        .padding(.top, 4)

                    if store.dataMaybeRevoked {
                        revokedBanner
                            .padding(.horizontal, 6)
                    }

                    if !visibleBrokenStreaks.isEmpty {
                        ForEach(visibleBrokenStreaks.prefix(3)) { broken in
                            brokenBanner(broken)
                                .padding(.horizontal, 6)
                        }
                    }

                    if let hero = store.hero {
                        Button { selectedStreak = hero } label: {
                            StreakHero(streak: hero)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(hero.metric.displayName) streak: \(hero.current) \(hero.cadence.pluralLabel), threshold \(Int(hero.threshold)) \(hero.metric.unitLabel)")
                        .accessibilityHint("View streak details")
                        .padding(.horizontal, 6)

                        if shouldShowAtRisk, let hero = store.hero, !hero.currentUnitCompleted, hero.current >= 2 {
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
                    } else if store.isLoading {
                        loadingState
                    } else {
                        emptyState
                    }
                }
                .padding(.bottom, 16)
                .frame(maxWidth: .infinity, alignment: .top)
            }
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
            .alert("Health Access", isPresented: Binding(
                get: { healthAccessErrorText != nil },
                set: { shown in
                    if !shown { healthAccessErrorText = nil }
                }
            )) {
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                Button("OK", role: .cancel) {}
            } message: {
                Text(healthAccessErrorText ?? "")
            }
        }
    }

    private var visibleBadges: [Streak] {
        store.badges
    }

    /// Hide broken-streak banners for metrics the user has turned off in Settings,
    /// or that are no longer in the tracked-set — keeping a "STREAK ENDED" banner
    /// for a metric the user already disabled would be confusing.
    private var visibleBrokenStreaks: [BrokenStreak] {
        settings.recentlyBroken.filter { broken in
            guard !settings.isHidden(broken.metric) else { return false }
            if let tracked = settings.trackedStreaks {
                return tracked.contains(broken.key)
            }
            return true
        }
    }

    private var shouldShowAtRisk: Bool {
        let now = Calendar.current.dateComponents([.hour, .minute], from: Date())
        guard let currentHour = now.hour, let currentMinute = now.minute else { return false }
        let thresholdHour = settings.notificationHour
        let thresholdMinute = settings.notificationMinute
        return currentHour > thresholdHour || (currentHour == thresholdHour && currentMinute >= thresholdMinute)
    }

    private var topBar: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text("▶ STREAK FINDER")
                    .font(RetroFont.mono(11, weight: .bold))
                    .tracking(1)
                    .foregroundStyle(Theme.retroMagenta)
                if let updated = store.lastUpdated {
                    Text("\(relative(updated)) · apple health")
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
            .accessibilityLabel("Refresh streaks from Apple Health")
            Button { showSettings = true } label: {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.retroInkDim)
                    .frame(width: 36, height: 36)
                    .background(Theme.retroBgRaised)
                    .overlay(Rectangle().stroke(Theme.retroInkFaint, lineWidth: 2))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Open settings")
        }
        .padding(.horizontal, 16)
    }

    private var revokedBanner: some View {
        Button {
            if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url)
            }
        } label: {
            HStack(spacing: 10) {
                Text("! NO RECENT DATA")
                    .font(RetroFont.mono(9, weight: .bold))
                    .tracking(1)
                    .foregroundStyle(Theme.retroCyan)
                Text("Apple Health may have revoked access · TAP TO FIX")
                    .font(RetroFont.mono(10))
                    .foregroundStyle(Theme.retroInk)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Spacer()
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .pixelPanel(color: Theme.retroCyan, fill: Theme.retroBg)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Apple Health may have revoked access. Tap to open Health Settings.")
    }

    private func atRiskBanner(for streak: Streak) -> some View {
        HStack(spacing: 10) {
            Text("! AT RISK")
                .font(RetroFont.mono(9, weight: .bold))
                .tracking(1)
                .foregroundStyle(Theme.retroRed)
            Text("\(streak.metric.displayName): \(riskText(for: streak))")
                .font(RetroFont.mono(11))
                .foregroundStyle(Theme.retroInk)
                .lineLimit(1)
            Spacer()
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity)
        .pixelPanel(color: Theme.retroRed, fill: Theme.retroBg)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("At risk: \(streak.metric.displayName). \(riskText(for: streak))")
    }

    private func riskText(for streak: Streak) -> String {
        let remaining = max(0, streak.threshold - streak.currentUnitValue)
        let v = streak.metric.format(value: remaining)
        let unit = streak.metric.unitLabel
        if let window = streak.window {
            return "\(v) \(unit) between \(window.label) to finish today"
        }
        return "\(v) \(unit) to finish today"
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
                Text("\(broken.brokenLength)-\(broken.cadence.label) \(broken.metric.displayName.lowercased()) run · TAP FOR OPTIONS")
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
        .accessibilityLabel("Streak ended: \(broken.brokenLength) \(broken.cadence.pluralLabel) \(broken.metric.displayName.lowercased()) run. Tap for recovery options.")
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
        .accessibilityLabel("Find more streaks")
    }

    private var badgeGrid: some View {
        LazyVGrid(columns: grid, spacing: 8) {
            ForEach(visibleBadges) { streak in
                VStack(spacing: 6) {
                    Button { selectedStreak = streak } label: {
                        StreakBadgeCard(streak: streak)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(streak.metric.displayName) streak: \(streak.current) \(streak.cadence.pluralLabel)")
                }
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
            Text("Connect Apple Health, refresh after activity, or build a custom streak to start.")
                .font(RetroFont.mono(11))
                .foregroundStyle(Theme.retroInkDim)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            VStack(spacing: 10) {
                Button("+ FIND MORE STREAKS") {
                    showPicker = true
                }
                .buttonStyle(.plain)
                .font(RetroFont.mono(11, weight: .bold))
                .foregroundStyle(Theme.retroBg)
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .background(Theme.retroLime)
                .accessibilityLabel("Find more streaks")

                Button("REFRESH") {
                    Task { await store.load() }
                }
                .buttonStyle(.plain)
                .font(RetroFont.mono(11, weight: .bold))
                .foregroundStyle(Theme.retroLime)
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .overlay(Rectangle().stroke(Theme.retroLime, lineWidth: 2))
                .accessibilityLabel("Refresh streaks from Apple Health")

                Button(requestingHealthAccess ? "REQUESTING..." : "REQUEST HEALTH ACCESS") {
                    Task { await requestHealthAccess() }
                }
                .buttonStyle(.plain)
                .font(RetroFont.mono(11, weight: .bold))
                .foregroundStyle(Theme.retroCyan)
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .overlay(Rectangle().stroke(Theme.retroCyan, lineWidth: 2))
                .disabled(requestingHealthAccess)
                .accessibilityLabel("Request Health access")

                Button("HEALTH SETTINGS") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                .buttonStyle(.plain)
                .font(RetroFont.mono(11, weight: .bold))
                .foregroundStyle(Theme.retroInkDim)
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .overlay(Rectangle().stroke(Theme.retroInkFaint, lineWidth: 2))
                .accessibilityLabel("Open iOS Settings for Health access")
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func relative(_ date: Date) -> String {
        let age = Date().timeIntervalSince(date)
        if age < 30 { return "just updated" }
        if age < 60 { return "<1 min ago" }
        return Self.relativeFormatter.localizedString(for: date, relativeTo: .now)
    }

    private func restart(_ broken: BrokenStreak) {
        var tracked = settings.trackedStreaks ?? Set(store.allCandidates.map(\.trackingKey))
        tracked.insert(broken.key)
        settings.trackedStreaks = tracked
        settings.dismissBroken(broken)
        store.refilter()
    }

    private func requestHealthAccess() async {
        guard !requestingHealthAccess else { return }
        requestingHealthAccess = true
        defer { requestingHealthAccess = false }

        let preStatus = await healthKit.authorizationRequestStatus()
        log.info("Manual health access request started from dashboard (preStatus=\(String(describing: preStatus)))")

        do {
            try await healthKit.requestAuthorization()
            let postStatus = await healthKit.authorizationRequestStatus()
            log.info("Manual health access request finished (postStatus=\(String(describing: postStatus)), hasRequestedAuthorization=\(self.healthKit.hasRequestedAuthorization))")
            await store.load()
        } catch is HealthKitError {
            log.error("Manual health access request failed with HealthKitError")
            healthAccessErrorText = "Could not request Health access from iOS. If the prompt does not appear, open Health or Settings and enable access for Streak Finder."
        } catch {
            log.error("Manual health access request failed: \(String(describing: error))")
            healthAccessErrorText = "Could not request Health access from iOS. Open Settings and enable Health access for Streak Finder."
        }
    }
}

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var settings: StreakSettings
    @EnvironmentObject var healthKit: HealthKitService
    @EnvironmentObject var store: StreakStore

    @Environment(\.dismiss) private var dismiss
    @State private var showingPicker = false
    @State private var notificationsBlockedBySystem = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    appearanceSection
                    vibeSection
                    notificationsSection
                    graceSection
                    metricsSection
                    dataSection
                    aboutSection

                    Text("Changes save automatically.")
                        .font(RetroFont.mono(10))
                        .foregroundStyle(Theme.retroInkDim)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 8)

                    Text("READ-ONLY · LOCAL-ONLY · NO NETWORK")
                        .font(RetroFont.pixel(8))
                        .tracking(2)
                        .foregroundStyle(Theme.retroInkFaint)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 20)
                        .padding(.bottom, 16)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 16)
            }
            .background(Theme.retroBg.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("SETTINGS")
                        .font(RetroFont.pixel(12))
                        .tracking(2)
                        .foregroundStyle(Theme.retroMagenta)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: {
                        Text("CLOSE")
                            .font(RetroFont.pixel(10))
                            .foregroundStyle(Theme.retroCyan)
                    }
                }
            }
            .toolbarBackground(Theme.retroBg, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .preferredColorScheme(settings.appearance.colorScheme)
            .sheet(isPresented: $showingPicker) {
                StreakPickerSheet()
                    .environmentObject(settings)
                    .environmentObject(store)
            }
        }
    }

    // MARK: - Appearance

    private var appearanceSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            PixelSectionHeader(title: "Appearance")
            HStack(spacing: 0) {
                ForEach(AppAppearance.allCases, id: \.rawValue) { a in
                    Button {
                        settings.appearance = a
                    } label: {
                        Text(a.label.uppercased())
                            .font(RetroFont.pixel(10))
                            .foregroundStyle(settings.appearance == a ? Theme.retroBg : Theme.retroInk)
                            .padding(.vertical, 10)
                            .frame(maxWidth: .infinity)
                            .background(settings.appearance == a ? Theme.retroCyan : Color.clear)
                            .overlay(Rectangle().stroke(settings.appearance == a ? Theme.retroCyan : Theme.retroInkFaint, lineWidth: 2))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Vibe

    private var vibeSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            PixelSectionHeader(title: "Streak Vibe")
            HStack(spacing: 0) {
                ForEach(DiscoveryVibe.allCases, id: \.rawValue) { v in
                    Button {
                        settings.vibe = v
                        Task { await store.load() }
                    } label: {
                        Text(v.short.uppercased())
                            .font(RetroFont.mono(9, weight: .bold))
                            .foregroundStyle(settings.vibe == v ? Theme.retroBg : Theme.retroInk)
                            .padding(.vertical, 10)
                            .padding(.horizontal, 4)
                            .frame(maxWidth: .infinity)
                            .background(settings.vibe == v ? Theme.retroMagenta : Color.clear)
                            .overlay(Rectangle().stroke(settings.vibe == v ? Theme.retroMagenta : Theme.retroInkFaint, lineWidth: 2))
                    }
                    .buttonStyle(.plain)
                }
            }
            Text(settings.vibe.tagline)
                .font(RetroFont.mono(10))
                .foregroundStyle(Theme.retroInkDim)
                .padding(.horizontal, 6)

            Button {
                showingPicker = true
            } label: {
                HStack {
                    Text("TRACKED STREAKS")
                        .font(RetroFont.mono(10, weight: .bold))
                        .foregroundStyle(Theme.retroInk)
                    Spacer()
                    Text(trackedSummary)
                        .font(RetroFont.mono(11, weight: .bold))
                        .foregroundStyle(Theme.retroCyan)
                    Text("›")
                        .font(RetroFont.mono(14, weight: .bold))
                        .foregroundStyle(Theme.retroInkDim)
                }
                .padding(14)
            }
            .buttonStyle(.plain)
            .pixelPanel(color: Theme.retroInkFaint)

            HStack {
                Text("DISCOVERY WINDOW")
                    .font(RetroFont.mono(10, weight: .bold))
                    .foregroundStyle(Theme.retroInk)
                Spacer()
                Text("\(settings.lookbackDays) days")
                    .font(RetroFont.mono(11, weight: .bold))
                    .foregroundStyle(Theme.retroMagenta)
            }
            .padding(.horizontal, 14)
            .padding(.top, 4)

            Slider(value: Binding(
                get: { Double(settings.lookbackDays) },
                set: { settings.lookbackDays = Int($0.rounded()) }
            ), in: 7...365, step: 1)
            .tint(Theme.retroMagenta)
            .padding(.horizontal, 14)
            .onChange(of: settings.lookbackDays) { _, _ in
                Task { await store.load() }
            }

            Text("How many days of history we use when suggesting new streak thresholds. Existing streaks stay locked at their committed value.")
                .font(RetroFont.mono(10))
                .foregroundStyle(Theme.retroInkDim)
                .padding(.horizontal, 14)
        }
    }

    private var trackedSummary: String {
        if let set = settings.trackedStreaks {
            return "\(set.count) PICKED"
        }
        return "ALL"
    }

    // MARK: - Notifications

    private var notificationsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            PixelSectionHeader(title: "Notifications")
            HStack {
                Text("AT-RISK REMINDER")
                    .font(RetroFont.pixel(10))
                    .foregroundStyle(Theme.retroInk)
                Spacer()
                PixelToggle(
                    isOn: Binding(
                        get: { settings.notificationsEnabled },
                        set: { newValue in
                            if newValue {
                                Task { await enableNotifications() }
                            } else {
                                settings.notificationsEnabled = false
                                notificationsBlockedBySystem = false
                                NotificationService.cancelAll()
                            }
                        }
                    ),
                    accent: Theme.retroMagenta
                )
            }
            .padding(14)
            .pixelPanel(color: Theme.retroInkFaint)

            if notificationsBlockedBySystem {
                Button {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    Text("BLOCKED IN IOS SETTINGS — TAP TO FIX")
                        .font(RetroFont.mono(10, weight: .bold))
                        .tracking(1)
                        .foregroundStyle(Theme.retroAmber)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .frame(maxWidth: .infinity)
                        .overlay(Rectangle().stroke(Theme.retroAmber, lineWidth: 2))
                }
                .buttonStyle(.plain)
            }

            DatePicker(
                "REMINDER TIME",
                selection: notificationTimeBinding,
                displayedComponents: .hourAndMinute
            )
            .font(RetroFont.mono(10, weight: .bold))
            .foregroundStyle(Theme.retroInk)
            .tint(Theme.retroMagenta)
            .padding(14)
            .pixelPanel(color: Theme.retroInkFaint)
            .disabled(!settings.notificationsEnabled)
            .onChange(of: settings.notificationHour) { _, _ in
                Task { await NotificationService.scheduleDailyReminder(for: store.hero) }
            }
            .onChange(of: settings.notificationMinute) { _, _ in
                Task { await NotificationService.scheduleDailyReminder(for: store.hero) }
            }

            Text("Daily nudge at \(notificationTimeLabel) if your primary streak isn't locked in yet. iOS will ask for notification permission the first time you turn this on.")
                .font(RetroFont.mono(10))
                .foregroundStyle(Theme.retroInkDim)
                .padding(.horizontal, 6)
        }
    }

    private var notificationTimeBinding: Binding<Date> {
        Binding(
            get: {
                DateHelpers.gregorian.date(from: DateComponents(
                    year: 2000,
                    month: 1,
                    day: 1,
                    hour: settings.notificationHour,
                    minute: settings.notificationMinute
                )) ?? .now
            },
            set: { date in
                let comps = DateHelpers.gregorian.dateComponents([.hour, .minute], from: date)
                settings.notificationHour = comps.hour ?? 19
                settings.notificationMinute = comps.minute ?? 0
            }
        )
    }

    private var notificationTimeLabel: String {
        let date = notificationTimeBinding.wrappedValue
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func enableNotifications() async {
        let outcome = await NotificationService.requestAuthorization()
        switch outcome {
        case .granted:
            settings.notificationsEnabled = true
            notificationsBlockedBySystem = false
            // Don't wait for the next refresh — schedule using the current hero immediately.
            await NotificationService.scheduleDailyReminder(for: store.hero)
        case .denied:
            settings.notificationsEnabled = false
            notificationsBlockedBySystem = false
        case .previouslyDenied:
            settings.notificationsEnabled = false
            notificationsBlockedBySystem = true
        }
    }

    private var graceSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            PixelSectionHeader(title: "Streak Protection")
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("EARN GRACE DAYS")
                        .font(RetroFont.pixel(10))
                        .foregroundStyle(Theme.retroInk)
                    Text("\(settings.earnedGraceDays) banked · +1 every 30 days")
                        .font(RetroFont.mono(10))
                        .foregroundStyle(Theme.retroInkDim)
                }
                Spacer()
                PixelToggle(isOn: $settings.graceDaysEnabled, accent: Theme.retroLime)
            }
            .padding(14)
            .pixelPanel(color: Theme.retroInkFaint)

            Text("When enabled, each 30-day run earns one grace day that can automatically preserve a streak after one missed day.")
                .font(RetroFont.mono(10))
                .foregroundStyle(Theme.retroInkDim)
                .padding(.horizontal, 6)
        }
    }

    // MARK: - Metrics

    private var metricsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            PixelSectionHeader(title: "Metrics Tracked")
            VStack(spacing: 0) {
                ForEach(Array(StreakMetric.allCases.enumerated()), id: \.offset) { idx, metric in
                    HStack(spacing: 10) {
                        Image(systemName: metric.symbol)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(metric.accent)
                            .shadow(color: metric.accent.opacity(0.6), radius: 4)
                            .frame(width: 24)
                        Text(metric.displayName.uppercased())
                            .font(RetroFont.pixel(10))
                            .foregroundStyle(Theme.retroInk)
                        Spacer()
                        PixelToggle(isOn: Binding(
                            get: { !settings.isHidden(metric) },
                            set: { on in
                                if on { settings.hiddenMetrics.remove(metric) }
                                else { settings.hiddenMetrics.insert(metric) }
                                Task { await store.load() }
                            }
                        ), accent: metric.accent)
                    }
                    .padding(.vertical, 12)
                    .padding(.horizontal, 14)
                    if idx < StreakMetric.allCases.count - 1 {
                        dashedLine
                    }
                }
            }
            .pixelPanel(color: Theme.retroInkFaint)
        }
    }

    private var dashedLine: some View {
        Rectangle()
            .fill(Theme.retroInkFaint)
            .frame(height: 1)
            .opacity(0.6)
            .padding(.horizontal, 14)
    }

    // MARK: - Data

    private var dataSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            PixelSectionHeader(title: "Data")
            Button {
                Task { await store.load() }
                dismiss()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.clockwise")
                    Text("REFRESH NOW")
                        .font(RetroFont.pixel(10))
                        .tracking(1)
                }
                .foregroundStyle(Theme.retroLime)
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            .pixelPanel(color: Theme.retroInkFaint)
        }
    }

    // MARK: - About

    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            PixelSectionHeader(title: "About")
            VStack(spacing: 0) {
                aboutRow(label: "VERSION",
                         value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                dashedLine
                if let url = URL(string: "https://jackwallner.github.io/fitness-streaks/privacy-policy.html") {
                    Link(destination: url) {
                        HStack {
                            Text("PRIVACY POLICY")
                                .font(RetroFont.pixel(10))
                                .foregroundStyle(Theme.retroInk)
                            Spacer()
                            Text("↗")
                                .font(RetroFont.pixel(11))
                                .foregroundStyle(Theme.retroCyan)
                        }
                        .padding(.vertical, 12)
                        .padding(.horizontal, 14)
                    }
                }
                dashedLine
                if let url = URL(string: "https://github.com/jackwallner/fitness-streaks") {
                    Link(destination: url) {
                        HStack {
                            Text("SOURCE")
                                .font(RetroFont.pixel(10))
                                .foregroundStyle(Theme.retroInk)
                            Spacer()
                            Text("↗")
                                .font(RetroFont.pixel(11))
                                .foregroundStyle(Theme.retroCyan)
                        }
                        .padding(.vertical, 12)
                        .padding(.horizontal, 14)
                    }
                }
                dashedLine
                if let url = URL(string: "mailto:jackwallner@gmail.com") {
                    Link(destination: url) {
                        HStack {
                            Text("SUPPORT")
                                .font(RetroFont.pixel(10))
                                .foregroundStyle(Theme.retroInk)
                            Spacer()
                            Text("↗")
                                .font(RetroFont.pixel(11))
                                .foregroundStyle(Theme.retroCyan)
                        }
                        .padding(.vertical, 12)
                        .padding(.horizontal, 14)
                    }
                }
            }
            .pixelPanel(color: Theme.retroInkFaint)
        }
    }

    private func aboutRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(RetroFont.pixel(10))
                .foregroundStyle(Theme.retroInk)
            Spacer()
            Text(value)
                .font(RetroFont.mono(11))
                .foregroundStyle(Theme.retroInkDim)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
    }
}

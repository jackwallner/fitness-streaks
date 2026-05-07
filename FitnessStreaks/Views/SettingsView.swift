import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var settings: StreakSettings
    @EnvironmentObject var healthKit: HealthKitService
    @EnvironmentObject var store: StreakStore
    @EnvironmentObject var storeKit: StoreKitService

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @State private var showingPicker = false
    @State private var notificationsBlockedBySystem = false
    @State private var showingRecalibrateAllConfirm = false
    @State private var recalibrateAllMessage: String? = nil
    @State private var showingLookbackRecalibratePrompt = false
    @State private var pendingLookbackDays: Int? = nil
    @State private var showingPaywall = false
    @State private var showingFreezeDatePicker = false
    @State private var newFreezeDate = Date()

    private static let lookbackOptions: [Int] = [7, 30, 90, 180, 365]
    private static let coachServicesURL = URL(string: "https://www.e3fit.me/#services")!
    private static let coachContactURL = URL(string: "https://www.e3fit.me/#contact")!
    private static let notificationTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    proSection
                    appearanceSection
                    intensitySection
                    notificationsSection
                    metricsSection
                    dataSection
                    plannedFreezesSection
                    coachSection
                    aboutSection

                    Text("Changes save automatically.")
                        .font(RetroFont.mono(10))
                        .foregroundStyle(Theme.retroInkDim)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 8)

                    Text("READ-ONLY · HEALTH DATA LOCAL-ONLY")
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
            .sheet(isPresented: $showingPaywall) {
                ProPaywallView()
                    .environmentObject(storeKit)
                    .environmentObject(settings)
            }
            .onChange(of: store.isLoading) { _, isLoading in
                if !isLoading { recalibrateAllMessage = nil }
            }
            .alert("Recalibrate Goals?", isPresented: $showingLookbackRecalibratePrompt) {
                Button("Recalibrate All", role: .destructive) {
                    if let days = pendingLookbackDays {
                        settings.lookbackDays = days
                        settings.committedThresholds = [:]
                        recalibrateAllMessage = "RECALIBRATING…"
                        Task { await store.load() }
                    }
                    pendingLookbackDays = nil
                }
                Button("Just Change Window", role: .cancel) {
                    if let days = pendingLookbackDays {
                        settings.lookbackDays = days
                        Task { await store.load() }
                    }
                    pendingLookbackDays = nil
                }
            } message: {
                Text("Would you like to recalibrate your goals based on this new lookback period? This will re-analyze your last \(pendingLookbackDays ?? 0) days and may suggest different goals.")
            }
        }
    }

    // MARK: - Pro / Grace Days

    private var proSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            PixelSectionHeader(title: storeKit.isPro ? "Pro · Grace Days" : "Grace Days · Pro")

            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 12) {
                    PixelFlame(size: 32, intensity: 0.7, tint: storeKit.isPro ? Theme.retroLime : Theme.retroMagenta)
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Text("GRACE DAYS")
                                .font(RetroFont.pixel(11))
                                .tracking(1)
                                .foregroundStyle(Theme.retroInk)
                            if storeKit.isPro {
                                PixelChip(text: "PRO", accent: Theme.retroLime)
                            } else {
                                PixelChip(text: "LOCKED", accent: Theme.retroMagenta)
                            }
                        }
                        Text("Banked: \(settings.earnedGraceDays) / 9")
                            .font(RetroFont.mono(11, weight: .bold))
                            .foregroundStyle(storeKit.isPro ? Theme.retroLime : Theme.retroAmber)
                    }
                    Spacer(minLength: 0)
                }

                Text(graceCopy)
                    .font(RetroFont.mono(10))
                    .foregroundStyle(Theme.retroInkDim)
                    .lineSpacing(2)

                if !storeKit.isPro {
                    Button {
                        showingPaywall = true
                    } label: {
                        HStack {
                            Text(settings.earnedGraceDays > 0 ? "UNLOCK PRO TO USE THEM" : "UNLOCK FITNESSSTREAKS PRO")
                                .font(RetroFont.mono(10, weight: .bold))
                                .tracking(1)
                                .foregroundStyle(Theme.retroBg)
                            Spacer()
                            Text("›")
                                .font(RetroFont.mono(14, weight: .bold))
                                .foregroundStyle(Theme.retroBg)
                        }
                        .padding(14)
                        .background(Theme.retroMagenta)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Unlock FitnessStreaks Pro")
                } else if !recentPreservations.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("RECENT SAVES")
                            .font(RetroFont.pixel(9))
                            .tracking(1)
                            .foregroundStyle(Theme.retroInkDim)
                        ForEach(recentPreservations, id: \.key) { p in
                            HStack(spacing: 8) {
                                Image(systemName: "shield.lefthalf.filled")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(Theme.retroLime)
                                Text("\(p.metric.displayName) · saved \(p.preservedLength)-day run")
                                    .font(RetroFont.mono(10))
                                    .foregroundStyle(Theme.retroInk)
                                Spacer()
                            }
                        }
                    }
                    .padding(.top, 4)

                    Button {
                        if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        HStack {
                            Text("MANAGE SUBSCRIPTION")
                                .font(RetroFont.mono(10, weight: .bold))
                                .tracking(1)
                                .foregroundStyle(Theme.retroCyan)
                            Spacer()
                            Text("↗")
                                .font(RetroFont.mono(11))
                                .foregroundStyle(Theme.retroCyan)
                        }
                        .padding(.vertical, 10)
                        .padding(.horizontal, 4)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(14)
            .pixelPanel(color: storeKit.isPro ? Theme.retroLime : Theme.retroMagenta, fill: Theme.retroBgRaised)
        }
    }

    private var graceCopy: String {
        if storeKit.isPro {
            if settings.earnedGraceDays == 0 {
                return "When you bank a Grace Day, FitnessStreaks will spend it automatically to save a streak you missed. You earn 1 every 30 days you keep your hero streak alive."
            }
            return "FitnessStreaks will automatically spend a Grace Day to preserve a streak you missed. They never expire — you can bank up to 9."
        }
        if settings.earnedGraceDays > 0 {
            return "You've banked \(settings.earnedGraceDays) Grace Day\(settings.earnedGraceDays == 1 ? "" : "s") from your streak progress. Unlock Pro to start using them automatically when life gets in the way."
        }
        return "Earn 1 Grace Day for every 30 days you keep your hero streak alive. Unlock Pro to spend them automatically and save streaks you'd otherwise lose."
    }

    private var recentPreservations: [GracePreservation] {
        let cutoff = Date().addingTimeInterval(-30 * 24 * 60 * 60)
        return settings.gracePreservations.values
            .filter { $0.grantedAt >= cutoff }
            .sorted { $0.grantedAt > $1.grantedAt }
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

    // MARK: - Intensity

    private var intensitySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            PixelSectionHeader(title: "Intensity")
            HStack(spacing: 0) {
                ForEach(DiscoveryIntensity.allCases, id: \.rawValue) { v in
                    Button {
                        settings.intensity = v
                        Task { await store.load() }
                    } label: {
                        Text(v.short.uppercased())
                            .font(RetroFont.mono(9, weight: .bold))
                            .foregroundStyle(settings.intensity == v ? Theme.retroBg : Theme.retroInk)
                            .padding(.vertical, 10)
                            .padding(.horizontal, 4)
                            .frame(maxWidth: .infinity)
                            .background(settings.intensity == v ? Theme.retroMagenta : Color.clear)
                            .overlay(Rectangle().stroke(settings.intensity == v ? Theme.retroMagenta : Theme.retroInkFaint, lineWidth: 2))
                    }
                    .buttonStyle(.plain)
                }
            }
            Text(settings.intensity.tagline)
                .font(RetroFont.mono(10))
                .foregroundStyle(Theme.retroInkDim)
                .padding(.horizontal, 6)

            Button {
                showingRecalibrateAllConfirm = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                    Text("RECALIBRATE ALL GOALS")
                        .font(RetroFont.mono(10, weight: .bold))
                        .tracking(1)
                    Spacer()
                    if recalibrateAllMessage != nil {
                        Text(recalibrateAllMessage ?? "")
                            .font(RetroFont.mono(9))
                            .foregroundStyle(Theme.retroInkDim)
                            .lineLimit(1)
                    }
                }
                .foregroundStyle(Theme.retroCyan)
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            .pixelPanel(color: Theme.retroCyan)
            .alert("Recalibrate All Goals?", isPresented: $showingRecalibrateAllConfirm) {
                Button("Recalibrate (Apple Health)", role: .destructive) {
                    settings.committedThresholds = [:]
                    recalibrateAllMessage = "RECALIBRATING…"
                    Task { await store.load() }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This re-derives every goal from your recent Apple Health activity. If new goals are higher than current ones, you may lose those streaks.")
            }

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

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("DISCOVERY WINDOW")
                        .font(RetroFont.mono(10, weight: .bold))
                        .foregroundStyle(Theme.retroInk)
                    Spacer()
                    Text("\(settings.lookbackDays) DAYS")
                        .font(RetroFont.mono(11, weight: .bold))
                        .foregroundStyle(Theme.retroMagenta)
                }
                HStack(spacing: 6) {
                    ForEach(Self.lookbackOptions, id: \.self) { value in
                        Button {
                            guard settings.lookbackDays != value else { return }
                            pendingLookbackDays = value
                            showingLookbackRecalibratePrompt = true
                        } label: {
                            Text("\(value)")
                                .font(RetroFont.mono(10, weight: .bold))
                                .foregroundStyle(settings.lookbackDays == value ? Theme.retroBg : Theme.retroInk)
                                .padding(.vertical, 8)
                                .frame(maxWidth: .infinity)
                                .background(settings.lookbackDays == value ? Theme.retroMagenta : Color.clear)
                                .overlay(Rectangle().stroke(settings.lookbackDays == value ? Theme.retroMagenta : Theme.retroInkFaint, lineWidth: 2))
                        }
                        .buttonStyle(.plain)
                    }
                }
                Text("How many days of history we use when suggesting new goals. Existing streaks stay locked at their committed value.")
                    .font(RetroFont.mono(10))
                    .foregroundStyle(Theme.retroInkDim)
            }
            .padding(.horizontal, 6)
            .padding(.top, 4)
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
            .accessibilityElement(children: .combine)
            .accessibilityLabel("At-risk reminder notifications")
            .accessibilityValue(settings.notificationsEnabled ? "On" : "Off")

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
                .accessibilityLabel("Notifications blocked in iOS settings. Tap to open Settings app.")
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
                Task { await NotificationService.scheduleDailyReminder(for: store.streaks) }
            }
            .onChange(of: settings.notificationMinute) { _, _ in
                Task { await NotificationService.scheduleDailyReminder(for: store.streaks) }
            }

            Text("Daily nudge at \(notificationTimeLabel) if a tracked streak isn't locked in yet. iOS will ask for notification permission the first time you turn this on.")
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
        return Self.notificationTimeFormatter.string(from: date)
    }

    private func enableNotifications() async {
        let outcome = await NotificationService.requestAuthorization()
        switch outcome {
        case .granted:
            settings.notificationsEnabled = true
            notificationsBlockedBySystem = false
            await NotificationService.scheduleDailyReminder(for: store.streaks)
        case .denied:
            settings.notificationsEnabled = false
            notificationsBlockedBySystem = false
        case .previouslyDenied:
            settings.notificationsEnabled = false
            notificationsBlockedBySystem = true
        }
    }

    // MARK: - Metrics

    private var metricsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            PixelSectionHeader(title: "Metrics Tracked")
            VStack(spacing: 0) {
                let visibleMetrics = StreakMetric.allCases.filter { $0 != .earlySteps }
                ForEach(Array(visibleMetrics.enumerated()), id: \.offset) { idx, metric in
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
                                if on {
                                    settings.hiddenMetrics.remove(metric)
                                } else {
                                    settings.hiddenMetrics.insert(metric)
                                    untrackStreaks(for: metric)
                                }
                                Task { await store.load() }
                            }
                        ), accent: metric.accent)
                    }
                    .padding(.vertical, 12)
                    .padding(.horizontal, 14)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("\(metric.displayName) tracking")
                    .accessibilityValue(!settings.isHidden(metric) ? "On" : "Off")
                    if idx < visibleMetrics.count - 1 {
                        dashedLine
                    }
                }
            }
            .pixelPanel(color: Theme.retroInkFaint)
        }
    }

    /// When the user hides a metric, drop any tracked streaks that depend on it
    /// so the broken-streak banner doesn't surface for a metric they've turned off.
    private func untrackStreaks(for metric: StreakMetric) {
        let keysToRemove = store.allCandidates
            .filter { $0.metric == metric }
            .map(\.trackingKey)
        guard !keysToRemove.isEmpty else { return }
        var tracked = settings.trackedStreaks ?? Set(store.allCandidates.map(\.trackingKey))
        for key in keysToRemove { tracked.remove(key) }
        settings.trackedStreaks = tracked
        for key in keysToRemove {
            settings.recentlyBroken.removeAll { $0.key == key }
            settings.committedThresholds.removeValue(forKey: key)
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

    // MARK: - Planned Freezes

    private var plannedFreezesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            PixelSectionHeader(title: "Planned Freezes")

            VStack(alignment: .leading, spacing: 8) {
                Text("Mark days you know you'll miss (vacation, travel, sick). Freeze days won't break your streaks or extend them.")
                    .font(RetroFont.mono(10))
                    .foregroundStyle(Theme.retroInkDim)
                    .lineSpacing(2)

                if settings.plannedFreezes.isEmpty {
                    Text("No freeze days set.")
                        .font(RetroFont.mono(10))
                        .foregroundStyle(Theme.retroInkFaint)
                        .padding(.vertical, 8)
                } else {
                    ForEach(sortedFreezes, id: \.self) { date in
                        HStack(spacing: 8) {
                            Image(systemName: "snowflake")
                                .font(.system(size: 12))
                                .foregroundStyle(Theme.retroCyan)
                            Text(formatFreezeDate(date))
                                .font(RetroFont.mono(10, weight: .bold))
                                .foregroundStyle(Theme.retroInk)
                            Spacer()
                            Button {
                                settings.removeFreezeDay(date)
                                Task { await store.load() }
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 14))
                                    .foregroundStyle(Theme.retroRed)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.vertical, 4)
                    }
                }

                Button {
                    newFreezeDate = Date()
                    showingFreezeDatePicker = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "plus.circle.fill")
                        Text("ADD FREEZE DAY")
                            .font(RetroFont.mono(10, weight: .bold))
                            .tracking(1)
                    }
                    .foregroundStyle(Theme.retroCyan)
                    .padding(.vertical, 8)
                }
                .buttonStyle(.plain)
            }
            .padding(14)
            .pixelPanel(color: Theme.retroCyan)
        }
        .sheet(isPresented: $showingFreezeDatePicker) {
            NavigationStack {
                VStack(spacing: 20) {
                    Text("Pick a day to freeze")
                        .font(RetroFont.mono(14, weight: .bold))
                        .foregroundStyle(Theme.retroInk)
                        .padding(.top, 20)

                    DatePicker(
                        "Freeze day",
                        selection: $newFreezeDate,
                        in: Date()...,
                        displayedComponents: .date
                    )
                    .datePickerStyle(.graphical)
                    .tint(Theme.retroCyan)
                    .padding(.horizontal, 20)

                    Button {
                        settings.addFreezeDay(newFreezeDate)
                        showingFreezeDatePicker = false
                        Task { await store.load() }
                    } label: {
                        Text("FREEZE THIS DAY")
                            .font(RetroFont.mono(12, weight: .bold))
                            .tracking(1)
                            .foregroundStyle(Theme.retroBg)
                            .padding(.vertical, 14)
                            .frame(maxWidth: .infinity)
                            .background(Theme.retroCyan)
                            .padding(.horizontal, 20)
                    }
                    .buttonStyle(.plain)

                    Spacer()
                }
                .background(Theme.retroBg.ignoresSafeArea())
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("CANCEL") {
                            showingFreezeDatePicker = false
                        }
                        .font(RetroFont.mono(10, weight: .bold))
                        .foregroundStyle(Theme.retroMagenta)
                    }
                }
            }
        }
    }

    private var sortedFreezes: [Date] {
        settings.plannedFreezes.sorted()
    }

    private func formatFreezeDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, MMM d"
        return formatter.string(from: date)
    }

    // MARK: - Coach (Elsa)

    private var coachSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            PixelSectionHeader(title: "Coaching")

            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 12) {
                    Image("ElsaCoach")
                        .resizable()
                        .scaledToFill()
                        .frame(width: 62, height: 78)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .strokeBorder(Color.white.opacity(colorScheme == .dark ? 0.08 : 0.45), lineWidth: 1)
                        }
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Need a coach?")
                            .font(.system(.headline, design: .rounded, weight: .bold))
                            .foregroundStyle(coachTitleColor)

                        Text("Live 1-on-1 virtual personal training and nutrition coaching with Elsa.")
                            .font(.system(.subheadline, design: .rounded))
                            .foregroundStyle(coachSecondaryColor)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                }

                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 8) {
                        coachTag(title: "1-on-1 live", systemImage: "video.fill", tint: CoachBrand.aquamarine)
                        coachTag(title: "Custom plans", systemImage: "checklist", tint: CoachBrand.dustyRose)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        coachTag(title: "1-on-1 live", systemImage: "video.fill", tint: CoachBrand.aquamarine)
                        coachTag(title: "Custom plans", systemImage: "checklist", tint: CoachBrand.dustyRose)
                    }
                }

                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 10) {
                        coachLinkButton(title: "Contact Elsa", systemImage: "arrow.up.right", destination: Self.coachContactURL, prominent: true)
                        coachLinkButton(title: "View services", systemImage: "list.bullet.clipboard", destination: Self.coachServicesURL, prominent: false)
                    }

                    VStack(spacing: 10) {
                        coachLinkButton(title: "Contact Elsa", systemImage: "arrow.up.right", destination: Self.coachContactURL, prominent: true)
                        coachLinkButton(title: "View services", systemImage: "list.bullet.clipboard", destination: Self.coachServicesURL, prominent: false)
                    }
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(coachBackgroundGradient, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(coachBorderColor, lineWidth: 1)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Need a coach? Live one-on-one virtual personal training and nutrition coaching with Elsa.")
        }
    }

    private var coachBackgroundGradient: LinearGradient {
        LinearGradient(
            colors: colorScheme == .dark
                ? [CoachBrand.nearBlack, CoachBrand.nearBlack.opacity(0.88)]
                : [CoachBrand.coconutCream, .white],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var coachTitleColor: Color {
        colorScheme == .dark ? CoachBrand.coconutCream : CoachBrand.nearBlack
    }

    private var coachSecondaryColor: Color {
        colorScheme == .dark ? CoachBrand.coconutCream.opacity(0.72) : CoachBrand.nearBlack.opacity(0.68)
    }

    private var coachBorderColor: Color {
        colorScheme == .dark ? CoachBrand.aquamarine.opacity(0.24) : CoachBrand.dustyRose.opacity(0.18)
    }

    private func coachTag(title: String, systemImage: String, tint: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
                .font(.system(.caption, design: .rounded, weight: .bold))
            Text(title)
                .font(.system(.caption, design: .rounded, weight: .medium))
        }
        .foregroundStyle(coachTitleColor)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(tint.opacity(colorScheme == .dark ? 0.18 : 0.12), in: Capsule())
    }

    private func coachLinkButton(title: String, systemImage: String, destination: URL, prominent: Bool) -> some View {
        Link(destination: destination) {
            HStack(spacing: 8) {
                Text(title)
                Image(systemName: systemImage)
                    .font(.system(.caption, design: .rounded, weight: .bold))
            }
            .font(.system(.subheadline, design: .rounded, weight: .semibold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .padding(.horizontal, 14)
            .background(coachLinkBackground(prominent: prominent), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                if !prominent {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(coachLinkBorder, lineWidth: 1)
                }
            }
            .foregroundStyle(coachLinkForeground(prominent: prominent))
        }
        .buttonStyle(.plain)
    }

    private func coachLinkBackground(prominent: Bool) -> Color {
        if prominent { return CoachBrand.dustyRose }
        return colorScheme == .dark ? CoachBrand.nearBlack.opacity(0.24) : .white.opacity(0.7)
    }

    private func coachLinkForeground(prominent: Bool) -> Color {
        if prominent { return .white }
        return coachTitleColor
    }

    private var coachLinkBorder: Color {
        colorScheme == .dark ? CoachBrand.aquamarine.opacity(0.22) : CoachBrand.nearBlack.opacity(0.08)
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
                if let url = URL(string: "mailto:jackwallner+fs@gmail.com") {
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
                dashedLine
                Button {
                    settings.hasSeenTutorial = false
                    dismiss()
                } label: {
                    HStack {
                        Text("REPLAY TUTORIAL")
                            .font(RetroFont.pixel(10))
                            .foregroundStyle(Theme.retroInk)
                        Spacer()
                        Text("▶")
                            .font(RetroFont.pixel(11))
                            .foregroundStyle(Theme.retroLime)
                    }
                    .padding(.vertical, 12)
                    .padding(.horizontal, 14)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Replay tutorial")
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

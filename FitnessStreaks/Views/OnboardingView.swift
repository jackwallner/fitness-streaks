import SwiftUI
import Combine

struct OnboardingView: View {
    @EnvironmentObject var healthKit: HealthKitService
    @EnvironmentObject var settings: StreakSettings
    @EnvironmentObject var store: StreakStore
    @EnvironmentObject var storeKit: StoreKitService

    enum Phase {
        case intro       // welcome + privacy notice (Health auth happens at intensity step)
        case intensity   // pick discovery intensity (after auth)
        case loading     // running discovery
        case selecting   // pick which discovered streaks to track
        case empty       // no streaks discovered
    }

    @State private var phase: Phase = .intro
    @State private var requesting = false
    @State private var errorText: String? = nil
    @State private var tipIndex: Int = 0
    @State private var loadTask: Task<Void, Never>? = nil
    @State private var flameVisible = true
    @State private var selection: Set<String> = []
    @State private var authProgress: Double = 0
    /// Full "see all plans" paywall — reached from the trial offer or as a fallback.
    @State private var showingPaywall = false
    /// Personalized loss-aversion trial pitch shown at Start for over-cap free users.
    @State private var showingTrialOffer = false
    @State private var trialPurchaseInFlight = false
    @State private var trialPurchaseError: String? = nil
    /// Set when the user opts into the full paywall from inside the trial sheet so
    /// the full paywall is presented *after* the trial sheet finishes dismissing —
    /// presenting both in the same tick is racy in SwiftUI.
    @State private var pendingPaywallAfterTrialDismiss = false

    private static let tips: [String] = [
        "Streaks update automatically from Apple Health. No manual logging.",
        "Sleep streaks are credited to the day a sleep sample ends.",
        "Weekly streaks reset on Mondays, ISO-style.",
        "Today doesn't break your streak until the day actually ends.",
        "Add the widget for a glanceable streak count on your home screen.",
        "Per-workout-type streaks let you track yoga, runs, and lifts separately."
    ]
    private static let privacyPolicyURL = URL(string: "https://jackwallner.github.io/fitness-streaks/privacy-policy.html")!

    /// Free accounts track at most this many discovered streaks. Onboarding
    /// pre-selects *more* than this (all core metrics) and lets the user keep
    /// them all through the selection step. The paywall at Start is the gate:
    /// pay to keep everything, or dismiss and we trim down to the top N.
    static let freeTrackedLimit = 3

    // Timer publishers - stored to allow proper cleanup
    private let tipTimerPublisher = Timer.publish(every: 3.5, on: .main, in: .common)
    private let progressTimerPublisher = Timer.publish(every: 0.35, on: .main, in: .common)
    @State private var tipTimerCancellable: AnyCancellable?
    @State private var progressTimerCancellable: AnyCancellable?

    var body: some View {
        ZStack {
            Theme.retroBg.ignoresSafeArea()

            switch phase {
            case .intro:     introScreen
            case .intensity: intensityScreen
            case .loading:   loadingScreen
            case .selecting: selectingScreen
            case .empty:     emptyScreen
            }
        }
        .sheet(isPresented: $showingTrialOffer, onDismiss: {
            trialPurchaseInFlight = false
            trialPurchaseError = nil
            // If a purchase succeeded inside the trial sheet, the entitlement
            // (or pending grant) makes any further paywall pointless. Skip the
            // hand-off and finish onboarding directly.
            if storeKit.grantsUnlimitedTrackedStreaks {
                pendingPaywallAfterTrialDismiss = false
                settings.hasSeenTrialOffer = true
                finishOnboardingAfterPaywallDismiss()
            } else if pendingPaywallAfterTrialDismiss {
                // They chose "see all plans" — hand off to the full paywall, which
                // owns the trim-and-complete on its own dismiss.
                pendingPaywallAfterTrialDismiss = false
                showingPaywall = true
            } else {
                settings.hasSeenTrialOffer = true
                finishOnboardingAfterPaywallDismiss()
            }
        }) {
            TrialOfferSheet(
                offerLabel: trialOfferLabel,
                priceLabel: trialPriceLabel,
                directPurchase: hasDirectTrialPackage,
                isPurchasing: trialPurchaseInFlight,
                errorMessage: trialPurchaseError,
                pickedCount: selection.count,
                freeCap: Self.freeTrackedLimit,
                longestStreak: longestSelectedStreak(),
                onStartTrial: startTrialPurchase,
                onSeeAllPlans: {
                    pendingPaywallAfterTrialDismiss = true
                    showingTrialOffer = false
                },
                onDismiss: { showingTrialOffer = false }
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
            .interactiveDismissDisabled(trialPurchaseInFlight)
        }
        .sheet(isPresented: $showingPaywall, onDismiss: {
            // Soft paywall: swipe-to-dismiss is intentionally allowed so a failed
            // or slow RevenueCat load can never brick first launch.
            settings.hasSeenTrialOffer = true
            finishOnboardingAfterPaywallDismiss()
        }) {
            PaywallView(paywallImpressionId: "streaks_onboarding_sheet")
        }
        .onChange(of: storeKit.grantsUnlimitedTrackedStreaks) { _, granted in
            // Entitlement (or pending entitlement) landed — kill any pitch surface
            // so the user never sees a second paywall after paying.
            guard granted else { return }
            pendingPaywallAfterTrialDismiss = false
            showingTrialOffer = false
            showingPaywall = false
            settings.hasSeenTrialOffer = true
        }
        .onAppear {
            // Start timers on appear
            tipTimerCancellable = tipTimerPublisher
                .sink { _ in
                    guard phase == .loading else { return }
                    withAnimation(.easeInOut(duration: 0.4)) {
                        tipIndex = (tipIndex + 1) % Self.tips.count
                    }
                }
            progressTimerCancellable = progressTimerPublisher
                .sink { _ in
                    guard phase == .loading, requesting else { return }
                    withAnimation(.linear(duration: 0.3)) {
                        authProgress = min(0.42, authProgress + 0.035)
                    }
                }
        }
        .onDisappear {
            // Cancel timers to prevent memory/CPU leak
            tipTimerCancellable?.cancel()
            progressTimerCancellable?.cancel()
        }
    }

    // MARK: - Intro

    private var introScreen: some View {
        VStack(spacing: 24) {
            VStack(spacing: 18) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 88))
                    .foregroundStyle(Theme.retroMagenta)
                    .retroGlow(Theme.retroMagenta)
                    .opacity(flameVisible ? 1 : 0.25)
                    .padding(.top, 30)
                    .onAppear {
                        withAnimation(.linear(duration: 0.6).repeatForever(autoreverses: true)) {
                            flameVisible = false
                        }
                    }

                VStack(spacing: 10) {
                    Text("STREAK\nFINDER")
                        .font(RetroFont.mono(32, weight: .bold))
                        .tracking(2)
                        .foregroundStyle(Theme.retroMagenta)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                        .retroGlow(Theme.retroMagenta)
                        .minimumScaleFactor(0.7)

                    Text("Discover the fitness streaks you've already built.")
                        .font(RetroFont.mono(13))
                        .foregroundStyle(Theme.retroInkDim)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                }

                streakPreview
                    .padding(.horizontal, 20)
                    .padding(.top, 4)
            }

            Spacer(minLength: 8)

            VStack(spacing: 8) {
                connectButton
                compactPrivacyNotice
            }
            .padding(.horizontal, 20)
        }
    }

    private var streakPreview: some View {
        VStack(spacing: 10) {
            Text("DISCOVER YOUR STREAKS")
                .font(RetroFont.mono(10, weight: .bold))
                .tracking(1)
                .foregroundStyle(Theme.retroCyan)

            HStack(spacing: 14) {
                streakPreviewItem(icon: "figure.walk", label: "STEPS")
                streakPreviewItem(icon: "figure.run", label: "EXERCISE")
                streakPreviewItem(icon: "figure.stand", label: "STAND")
                streakPreviewItem(icon: "flame.fill", label: "WORKOUTS")
            }
            .padding(.horizontal, 4)
        }
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .pixelPanel(color: Theme.retroCyan)
    }

    private func streakPreviewItem(icon: String, label: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 22))
                .foregroundStyle(Theme.retroMagenta)
            Text(label)
                .font(RetroFont.mono(8, weight: .bold))
                .tracking(1)
                .foregroundStyle(Theme.retroInkDim)
        }
        .frame(minWidth: 52)
    }

    private var compactPrivacyNotice: some View {
        HStack(spacing: 6) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 10))
                .foregroundStyle(Theme.retroLime)
            Text("Read-only Apple Health access. Everything stays on device.")
                .font(RetroFont.mono(9))
                .foregroundStyle(Theme.retroInkDim)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Link(destination: Self.privacyPolicyURL) {
                HStack(spacing: 3) {
                    Text("POLICY")
                    Text("↗")
                }
                .font(RetroFont.mono(9, weight: .bold))
                .foregroundStyle(Theme.retroCyan)
            }
        }
        .padding(.bottom, 6)
    }

    private var connectButton: some View {
        Button {
            withAnimation { phase = .intensity }
        } label: {
            Text("▶ GET STARTED")
                .font(RetroFont.mono(13, weight: .bold))
                .foregroundStyle(Theme.retroBg)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Theme.retroLime)
        }
        .buttonStyle(.plain)
    }

    private func errorBlock(_ err: String) -> some View {
        VStack(spacing: 8) {
            Text(err)
                .font(RetroFont.mono(11))
                .foregroundStyle(Theme.retroRed)
                .multilineTextAlignment(.center)
            HStack(spacing: 10) {
                Button {
                    openHealthAccess()
                } label: {
                    Text("OPEN SETTINGS")
                        .font(RetroFont.mono(11, weight: .bold))
                        .tracking(1)
                        .foregroundStyle(Theme.retroCyan)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 14)
                        .overlay(Rectangle().stroke(Theme.retroCyan, lineWidth: 2))
                }
                .buttonStyle(.plain)
                Button {
                    finishWithoutTracking()
                } label: {
                    Text("SKIP")
                        .font(RetroFont.mono(11, weight: .bold))
                        .tracking(1)
                        .foregroundStyle(Theme.retroInkDim)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 14)
                        .overlay(Rectangle().stroke(Theme.retroInkFaint, lineWidth: 2))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Intensity

    private var intensityScreen: some View {
        VStack(spacing: 20) {
            VStack(spacing: 8) {
                Text("PICK YOUR INTENSITY")
                    .font(RetroFont.mono(22, weight: .bold))
                    .tracking(2)
                    .foregroundStyle(Theme.retroMagenta)
                    .retroGlow(Theme.retroMagenta)
                Text("How hard should your streaks push you?")
                    .font(RetroFont.mono(12))
                    .foregroundStyle(Theme.retroInkDim)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 24)

            VStack(spacing: 10) {
                ForEach(DiscoveryIntensity.allCases, id: \.rawValue) { intensity in
                    intensityRow(intensity)
                }
            }
            .padding(.horizontal, 20)

            Spacer(minLength: 8)

            if let err = errorText {
                errorBlock(err)
                    .padding(.bottom, 12)
            }

            Button {
                Task { await beginDiscoveryWithAuth() }
            } label: {
                Text(requesting ? "CONNECTING..." : "▶ FIND MY STREAKS")
                    .font(RetroFont.mono(13, weight: .bold))
                    .foregroundStyle(Theme.retroBg)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(requesting ? Theme.retroInkFaint : Theme.retroLime)
            }
            .buttonStyle(.plain)
            .disabled(requesting)
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
    }

    private func intensityRow(_ intensity: DiscoveryIntensity) -> some View {
        let selected = settings.intensity == intensity
        return Button {
            settings.intensity = intensity
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Text(selected ? "▶" : " ")
                    .font(RetroFont.mono(14, weight: .bold))
                    .foregroundStyle(Theme.retroLime)
                VStack(alignment: .leading, spacing: 4) {
                    Text(intensity.label.uppercased())
                        .font(RetroFont.mono(13, weight: .bold))
                        .tracking(1)
                        .foregroundStyle(selected ? Theme.retroLime : Theme.retroInk)
                    Text(intensity.tagline)
                        .font(RetroFont.mono(11))
                        .foregroundStyle(Theme.retroInkDim)
                        .multilineTextAlignment(.leading)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(selected ? Theme.retroBgCard : Color.clear)
            .overlay(Rectangle().stroke(selected ? Theme.retroLime : Theme.retroInkFaint, lineWidth: 2))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Loading

    private var loadingScreen: some View {
        VStack(spacing: 24) {
            VStack(spacing: 12) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(Theme.retroMagenta)
                    .retroGlow(Theme.retroMagenta)

                Text("FINDING YOUR\nSTREAKS")
                    .font(RetroFont.mono(22, weight: .bold))
                    .tracking(2)
                    .foregroundStyle(Theme.retroMagenta)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .retroGlow(Theme.retroMagenta)
            }
            .padding(.top, 24)

            progressBlock
                .padding(.horizontal, 20)

            tipBlock
                .padding(.horizontal, 20)

            Spacer(minLength: 8)
        }
    }

    private var progressBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(currentStageLabel)
                    .font(RetroFont.mono(11, weight: .bold))
                    .tracking(1)
                    .foregroundStyle(Theme.retroCyan)
                Spacer()
                Text("\(Int(displayedProgress * 100))%")
                    .font(RetroFont.mono(11, weight: .bold))
                    .foregroundStyle(Theme.retroCyan)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Theme.retroBgCard)
                        .overlay(Rectangle().stroke(Theme.retroCyan, lineWidth: 2))
                    ZStack {
                        Rectangle()
                            .fill(Theme.retroCyan)
                        AnimatedStripes(stripeWidth: 6, gap: 8, speed: 18)
                            .blendMode(.plusLighter)
                    }
                    .frame(width: max(0, geo.size.width * CGFloat(displayedProgress)))
                    .padding(2)
                    .clipped()
                }
            }
            .frame(height: 18)
        }
    }

    private var tipBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("DID YOU KNOW")
                .font(RetroFont.mono(10, weight: .bold))
                .tracking(1)
                .foregroundStyle(Theme.retroMagenta)
            Text(Self.tips[tipIndex])
                .font(RetroFont.mono(11))
                .foregroundStyle(Theme.retroInkDim)
                .multilineTextAlignment(.leading)
                .lineSpacing(2)
                .frame(maxWidth: .infinity, alignment: .leading)
                .animation(.easeInOut(duration: 0.4), value: tipIndex)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .pixelPanel(color: Theme.retroMagenta)
    }

    private var currentStageLabel: String {
        if requesting {
            return "CONNECTING TO APPLE HEALTH"
        }
        let label = store.loadStage.label
        return label.isEmpty ? "CONNECTING…" : label
    }

    private var displayedProgress: Double {
        if requesting {
            return max(0.08, authProgress)
        }
        if phase == .loading {
            return max(authProgress, store.loadProgress)
        }
        return store.loadProgress
    }

    // MARK: - Selecting

    private var selectingScreen: some View {
        VStack(spacing: 0) {
            VStack(spacing: 6) {
                Text("YOUR STREAKS")
                    .font(RetroFont.mono(20, weight: .bold))
                    .tracking(2)
                    .foregroundStyle(Theme.retroMagenta)
                    .retroGlow(Theme.retroMagenta)
                Text("\(store.allCandidates.count) discovered · pick the ones you want to track")
                    .font(RetroFont.mono(11))
                    .foregroundStyle(Theme.retroInkDim)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 24)
            .padding(.bottom, 12)

            HStack(spacing: 10) {
                Text("\(selection.count) SELECTED")
                    .font(RetroFont.mono(11, weight: .bold))
                    .tracking(1)
                    .foregroundStyle(Theme.retroLime)
                Spacer()
                Button { selection = Set(store.allCandidates.map(\.trackingKey)) } label: {
                    Text("SELECT ALL")
                        .font(RetroFont.mono(10, weight: .bold))
                        .tracking(1)
                        .foregroundStyle(Theme.retroCyan)
                        .padding(.vertical, 6)
                        .padding(.horizontal, 12)
                        .overlay(Rectangle().stroke(Theme.retroCyan, lineWidth: 2))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 10)

            ScrollView {
                StreakPickerList(
                    candidates: store.allCandidates,
                    selection: $selection,
                    recommendedCount: min(5, store.allCandidates.count)
                )
                .padding(.horizontal, 14)
                .padding(.bottom, 16)
            }

            if !storeKit.isPro {
                proContextCard
                    .padding(.horizontal, 20)
                    .padding(.bottom, 8)
            }

            Button {
                finishWithSelection()
            } label: {
                Text(startButtonLabel)
                    .font(RetroFont.mono(13, weight: .bold))
                    .foregroundStyle(Theme.retroBg)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(selection.isEmpty ? Theme.retroInkFaint : Theme.retroLime)
            }
            .buttonStyle(.plain)
            .disabled(selection.isEmpty)
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
    }

    // MARK: - Empty

    private var emptyScreen: some View {
        VStack(spacing: 20) {
            Spacer(minLength: 0)

            Image(systemName: "flame")
                .font(.system(size: 72))
                .foregroundStyle(Theme.retroInkDim)

            VStack(spacing: 10) {
                Text("NO STREAKS YET")
                    .font(RetroFont.mono(20, weight: .bold))
                    .tracking(2)
                    .foregroundStyle(Theme.retroMagenta)
                Text("We didn't find any active streaks in your Apple Health history. Once you log a few days of activity, we'll surface them here.")
                    .font(RetroFont.mono(12))
                    .foregroundStyle(Theme.retroInkDim)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
                    .padding(.horizontal, 24)
            }

            Spacer(minLength: 0)

            Button {
                finishWithoutTracking()
            } label: {
                Text("▶ CONTINUE")
                    .font(RetroFont.mono(13, weight: .bold))
                    .foregroundStyle(Theme.retroBg)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Theme.retroLime)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
    }

    // MARK: - Flow

    private func beginDiscoveryWithAuth() async {
        errorText = nil
        authProgress = 0.08
        withAnimation { phase = .loading }
        await requestAuth()
        guard errorText == nil else {
            withAnimation { phase = .intensity }
            return
        }
        startDiscovery()
    }

    private func startDiscovery() {
        withAnimation { phase = .loading }
        loadTask?.cancel()
        loadTask = Task {
            await store.load()
            await MainActor.run { handleLoadFinished() }
        }
    }

    private func handleLoadFinished() {
        if store.allCandidates.isEmpty {
            withAnimation { phase = .empty }
            return
        }
        // Pre-select Apple's Activity-ring core metrics for a familiar onboarding
        // experience. Both free and Pro users start with all available core
        // metrics selected. Free users land over the cap on purpose — the Start
        // button routes them through the paywall (pay to keep all, or we trim to
        // `freeTrackedLimit` on dismiss). This is the self-force funnel.
        let coreMetrics: [StreakMetric] = [.steps, .exerciseMinutes, .standHours, .activeEnergy, .workouts]
        let core = store.allCandidates
            .filter { coreMetrics.contains($0.metric) }
            .sorted { a, b in
                let ai = coreMetrics.firstIndex(of: a.metric) ?? Int.max
                let bi = coreMetrics.firstIndex(of: b.metric) ?? Int.max
                return ai < bi
            }
        selection = Set(core.map(\.trackingKey))
        withAnimation { phase = .selecting }
    }

    private func finishWithSelection() {
        guard !selection.isEmpty else { return }
        // Record the user's *intended* count before any free-tier cap is applied,
        // so the post-onboarding trial offer can pitch "keep all N you just earned"
        // when the user picked more than the free cap allows.
        settings.lastOnboardingPickedCount = selection.count
        settings.trackedStreaks = selection
        // Manual order = engine order, filtered to selection. This preserves the
        // user's chosen intensity ranking for the hero rather than overriding it
        // with a hardcoded steps-first assumption.
        let order = store.allCandidates
            .map(\.trackingKey)
            .filter { selection.contains($0) }
        settings.manualStreakOrder = order
        settings.lastOnboardingTrackedKeys = order
        store.refilter()
        advanceFromSelection()
    }

    /// After any onboarding paywall/trial sheet closes, enforce the free cap only
    /// when the user did not purchase. Restores the full onboarding pick list when
    /// they did (including pending entitlement activation).
    private func finishOnboardingAfterPaywallDismiss() {
        Task {
            await storeKit.refreshEntitlement()
            if storeKit.grantsUnlimitedTrackedStreaks {
                settings.restoreOnboardingTrackedStreaksIfNeeded()
                store.refilter()
            } else {
                trimSelectionToFreeCap()
            }
            completeSetup()
        }
    }

    /// Free user dismissed the paywall without upgrading. Trim their over-cap
    /// selection down to `freeTrackedLimit`, keeping the highest-ranked picks in
    /// the order already recorded in `manualStreakOrder`.
    private func trimSelectionToFreeCap() {
        guard settings.trackedStreaks != nil else { return }
        let order = settings.manualStreakOrder
        let kept = Array(order.prefix(Self.freeTrackedLimit))
        guard !kept.isEmpty else { return }
        settings.trackedStreaks = Set(kept)
        settings.manualStreakOrder = kept
        store.refilter()
    }

    private func finishWithoutTracking() {
        settings.trackedStreaks = nil
        store.refilter()
        advanceFromSelection(showPaywall: false)
    }

    /// After the user picks (or skips) streaks, route non-Pro users through
    /// the paywall directly as the natural next step. Pro users skip through.
    private func advanceFromSelection(showPaywall: Bool = true) {
        // Only gate on the paywall when there's actually an offering to show. If
        // RevenueCat hasn't loaded (offline / slow / misconfigured), proceed into
        // the app rather than presenting an empty, non-actionable paywall.
        if storeKit.grantsUnlimitedTrackedStreaks || !showPaywall || storeKit.offerings?.current == nil {
            if storeKit.grantsUnlimitedTrackedStreaks {
                settings.restoreOnboardingTrackedStreaksIfNeeded()
                store.refilter()
            } else {
                trimSelectionToFreeCap()
            }
            completeSetup()
        } else {
            showingTrialOffer = true
        }
    }

    private var startButtonLabel: String {
        if selection.isEmpty { return "PICK AT LEAST ONE" }
        return "▶ START · \(selection.count) STREAK\(selection.count == 1 ? "" : "S")"
    }

    private func completeSetup() {
        withAnimation { settings.hasCompletedSetup = true }
    }

    // MARK: - Trial Offer

    /// Strongest streak the *free cap would drop* from the user's selection.
    /// The loss-aversion pitch must reference a streak Streaks+ would save —
    /// not one the user keeps under the free tier anyway. Returns nil when the
    /// selection fits inside the free cap (nothing would be lost).
    private func longestSelectedStreak() -> TrialOfferSheet.LongestStreakInfo? {
        guard selection.count > Self.freeTrackedLimit else { return nil }
        // Determine which of the user's picks would survive the free-tier trim,
        // mirroring `trimSelectionToFreeCap`. Anything outside `kept` is at risk.
        let orderedKeys = settings.manualStreakOrder.filter { selection.contains($0) }
        let pickOrder = orderedKeys.isEmpty ? Array(selection) : orderedKeys
        let kept = Set(pickOrder.prefix(Self.freeTrackedLimit))
        let atRisk = store.allCandidates.filter {
            selection.contains($0.trackingKey) && !kept.contains($0.trackingKey)
        }
        guard let top = atRisk.max(by: { $0.current < $1.current }), top.current > 0 else {
            return nil
        }
        return .init(displayName: top.displayName, current: top.current, cadenceLabel: top.cadence.label)
    }

    /// True when a trial-bearing package loaded, so the trial sheet can buy it
    /// directly rather than punting to the full paywall.
    private var hasDirectTrialPackage: Bool {
        storeKit.products.contains { $0.streaksIntroOfferLabel != nil }
    }

    private var trialOfferLabel: String? {
        let trials = storeKit.products.filter { $0.streaksIntroOfferLabel != nil }
        let best = trials.first(where: { $0.packageType == .annual }) ?? trials.first
        return best?.streaksIntroOfferLabel ?? storeKit.products.compactMap(\.streaksIntroOfferLabel).first
    }

    private var trialPriceLabel: String? {
        let trials = storeKit.products.filter { $0.streaksIntroOfferLabel != nil }
        let best = trials.first(where: { $0.packageType == .annual }) ?? trials.first
        return best?.streaksRecurringPriceLabel
    }

    /// Buy the trial-bearing package directly. Yearly is preferred (longer
    /// commitment, better trial value). Falls through to the full paywall when no
    /// trial product is available.
    private func startTrialPurchase() {
        let trials = storeKit.products.filter { $0.streaksIntroOfferLabel != nil }
        guard let package = trials.first(where: { $0.packageType == .annual }) ?? trials.first else {
            pendingPaywallAfterTrialDismiss = true
            showingTrialOffer = false
            return
        }
        trialPurchaseError = nil
        trialPurchaseInFlight = true
        Task { @MainActor in
            defer { trialPurchaseInFlight = false }
            switch await storeKit.purchase(package: package) {
            case .purchased, .pending:
                settings.hasSeenTrialOffer = true
                showingTrialOffer = false
            case .cancelled:
                trialPurchaseError = "Trial wasn't started. Tap again, or pick a different plan."
            case .failed:
                trialPurchaseError = storeKit.lastError ?? "Couldn't start your trial. Please try again."
            }
        }
    }

    // MARK: - Pro Context

    /// How many extra streaks the user could be tracking but can't (free cap).
    private var lockedCount: Int {
        max(0, store.allCandidates.count - selection.count)
    }

    private var proContextCard: some View {
        HStack(spacing: 10) {
            Image(systemName: "shield.lefthalf.filled")
                .font(.system(size: 18))
                .foregroundStyle(Theme.retroMagenta)
            VStack(alignment: .leading, spacing: 2) {
                Text("FREE TRACKS \(Self.freeTrackedLimit) · \(lockedCount) MORE WITH STREAKS+")
                    .font(RetroFont.mono(10, weight: .bold))
                    .tracking(1)
                    .foregroundStyle(Theme.retroMagenta)
                Text(lockedCount > 0
                     ? "Tap any locked streak to start a free trial and add it."
                     : "Streaks+ unlocks custom streaks, auto-save, and travel freezes.")
                    .font(RetroFont.mono(9))
                    .foregroundStyle(Theme.retroInkDim)
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .pixelPanel(color: Theme.retroMagenta, fill: Theme.retroBgRaised)
    }

    private func requestAuth() async {
        requesting = true
        withAnimation(.linear(duration: 0.2)) {
            authProgress = max(authProgress, 0.14)
        }
        defer { requesting = false }

        do {
            try await healthKit.requestAuthorization()
            withAnimation(.linear(duration: 0.2)) {
                authProgress = max(authProgress, 0.45)
            }
        } catch is HealthKitError {
            errorText = "Couldn't request Health access from iOS. Open the Health app or Settings and enable access for Streaks."
            return
        } catch {
            errorText = "Couldn't connect to Apple Health. Open the Health app and enable access for Streaks."
            return
        }

        // We can't detect read-permission denial (Apple privacy). The one signal we
        // do get: if post-request status is still `.shouldRequest`, the prompt was
        // suppressed (almost always because the user previously denied). Direct
        // them to Settings rather than parking on a data-less dashboard.
        let postStatus = await healthKit.authorizationRequestStatus()
        if postStatus == .shouldRequest {
            errorText = "Health access needed. Open the Health app or Settings to enable Streaks's access to Apple Health."
        }
    }

    private func openHealthAccess() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
}

/// Bottom sheet shown the moment a free user taps an unselected streak past the
/// cap. Frames the pitch around the *specific* streak they just tried to add,
/// then hosts the native `PaywallView`.
struct CapPaywallSheet<Paywall: View>: View {
    let streak: Streak?
    let freeCap: Int
    @ViewBuilder let paywall: () -> Paywall

    @Environment(\.dismiss) private var dismiss

    private var streakName: String {
        streak?.displayName.uppercased() ?? "THIS STREAK"
    }

    private var headline: String {
        if let streak, streak.current >= 3 {
            return "KEEP YOUR \(streak.current)-\(streak.cadence.label.uppercased()) \(streakName) STREAK"
        }
        return "ADD \(streakName) TO YOUR STREAKS+ LINEUP"
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 8) {
                Text("FREE TRACKS \(freeCap)")
                    .font(RetroFont.mono(10, weight: .bold))
                    .tracking(2)
                    .foregroundStyle(Theme.retroInkDim)
                Text(headline)
                    .font(RetroFont.mono(15, weight: .bold))
                    .tracking(1)
                    .foregroundStyle(Theme.retroMagenta)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
                    .retroGlow(Theme.retroMagenta)
            }
            .padding(.top, 18)
            .padding(.horizontal, 24)
            .padding(.bottom, 12)
            .frame(maxWidth: .infinity)
            .background(Theme.retroBg)

            paywall()
        }
    }
}

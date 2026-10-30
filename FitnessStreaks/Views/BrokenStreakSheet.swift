import SwiftUI
#if REVENUECAT
import RevenueCat
#endif

struct BrokenStreakSheet: View {
    let broken: BrokenStreak
    let restart: () -> Void
    let pickNew: () -> Void
    let dismiss: () -> Void

    @EnvironmentObject var storeKit: StoreKitService
    @EnvironmentObject var settings: StreakSettings
    @EnvironmentObject var store: StreakStore

    @Environment(\.dismiss) private var close
    @State private var showingPaywall = false
    @State private var showingTrialOffer = false
    @State private var trialInFlight = false
    @State private var trialError: String?
    @State private var pendingPaywallAfterTrial = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    PixelFlame(size: 64, intensity: 0.5, tint: Theme.retroRed)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 20)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("STREAK ENDED")
                            .font(RetroFont.mono(12, weight: .bold))
                            .tracking(2)
                            .foregroundStyle(Theme.retroRed)
                        Text(endedSentence)
                            .font(RetroFont.mono(12))
                            .foregroundStyle(Theme.retroInk)
                            .lineSpacing(3)
                    }
                    .padding(14)
                    .pixelPanel(color: Theme.retroRed, fill: Theme.retroBgRaised)

                    if shouldShowUpsell {
                        revivalUpsell
                    }

                    Button {
                        restart()
                        close()
                    } label: {
                        Text("KEEP SAME GOAL")
                            .font(RetroFont.mono(11, weight: .bold))
                            .tracking(1)
                            .foregroundStyle(Theme.retroBg)
                            .padding(14)
                            .frame(maxWidth: .infinity)
                            .background(Theme.retroLime)
                    }
                    .buttonStyle(.plain)

                    Button {
                        pickNew()
                        close()
                    } label: {
                        Text("PICK A NEW GOAL")
                            .font(RetroFont.mono(11, weight: .bold))
                            .tracking(1)
                            .foregroundStyle(Theme.retroCyan)
                            .padding(14)
                            .frame(maxWidth: .infinity)
                            .overlay(Rectangle().stroke(Theme.retroCyan, lineWidth: 2))
                    }
                    .buttonStyle(.plain)

                    Spacer(minLength: 0)
                }
                .padding(16)
            }
            .background(Theme.retroBg.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("RECOVERY")
                        .font(RetroFont.mono(12, weight: .bold))
                        .tracking(2)
                        .foregroundStyle(Theme.retroMagenta)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                        close()
                    } label: {
                        Text("CLOSE")
                            .font(RetroFont.mono(10, weight: .bold))
                            .foregroundStyle(Theme.retroInkDim)
                    }
                }
            }
            .toolbarBackground(Theme.retroBg, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .sheet(isPresented: $showingPaywall, onDismiss: handlePaywallDismiss) {
                PaywallView(paywallImpressionId: "streaks_broken_sheet")
            }
            .sheet(isPresented: $showingTrialOffer, onDismiss: {
                trialInFlight = false
                trialError = nil
                // Hand off to the full plan list only if the user explicitly asked
                // for it; a plain dismiss just closes the revive pitch.
                if pendingPaywallAfterTrial {
                    pendingPaywallAfterTrial = false
                    showingPaywall = true
                }
            }) {
                TrialOfferSheet(
                    isPurchasing: trialInFlight,
                    errorMessage: trialError,
                    pickedCount: 0,
                    freeCap: 3,
                    longestStreak: .init(
                        displayName: broken.metric.displayName,
                        inlineName: broken.metric.inlineName,
                        current: broken.brokenLength,
                        cadence: broken.cadence
                    ),
                    headlineOverride: reviveHeadline,
                    subheadlineOverride: hasTrialOffer
                        ? String(localized: "Your run just ended. Start a Streaks+ trial and we'll restore it on the spot. Then auto-save every future miss so it can't happen again.")
                        : String(localized: "Your run just ended. Subscribe to Streaks+ and we'll restore it on the spot. Then auto-save every future miss so it can't happen again."),
                    onStartTrial: { startReviveTrialPurchase() },
                    onSeeAllPlans: {
                        pendingPaywallAfterTrial = true
                        showingTrialOffer = false
                    },
                    onDismiss: { showingTrialOffer = false }
                )
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .interactiveDismissDisabled(trialInFlight)
            }
        }
    }

    // MARK: - Direct trial purchase (revive context)

    private var hasTrialOffer: Bool {
        #if REVENUECAT
        return storeKit.eligibleTrialPackage?.streaksIntroOfferDays != nil
        #else
        return false
        #endif
    }

    private var endedSentence: String {
        let n = broken.brokenLength
        let name = broken.metric.inlineName
        switch broken.cadence {
        case .daily: return String(localized: "Your \(name) run ended at \(n) days.")
        case .weekly: return String(localized: "Your \(name) run ended at \(n) weeks.")
        }
    }

    private var reviveHeadline: String {
        let n = broken.brokenLength
        let name = broken.metric.inlineName.uppercased()
        switch broken.cadence {
        case .daily: return String(localized: "REVIVE YOUR \(n)-DAY \(name) STREAK.")
        case .weekly: return String(localized: "REVIVE YOUR \(n)-WEEK \(name) STREAK.")
        }
    }

    private var revivalBody: String {
        let n = broken.brokenLength
        let name = broken.metric.inlineName
        switch (broken.cadence, hasTrialOffer) {
        case (.daily, true):
            return String(localized: "Start a Streaks+ trial and we'll restore your \(n)-day \(name) run on the spot. Streaks+ auto-saves every missed day so this doesn't happen again.")
        case (.weekly, true):
            return String(localized: "Start a Streaks+ trial and we'll restore your \(n)-week \(name) run on the spot. Streaks+ auto-saves every missed day so this doesn't happen again.")
        case (.daily, false):
            return String(localized: "Subscribe to Streaks+ and we'll restore your \(n)-day \(name) run on the spot. Streaks+ auto-saves every missed day so this doesn't happen again.")
        case (.weekly, false):
            return String(localized: "Subscribe to Streaks+ and we'll restore your \(n)-week \(name) run on the spot. Streaks+ auto-saves every missed day so this doesn't happen again.")
        }
    }

    private var revivalAccessibility: String {
        let n = broken.brokenLength
        let name = broken.metric.inlineName
        switch (broken.cadence, hasTrialOffer) {
        case (.daily, true): return String(localized: "Start a Streaks+ trial to revive your \(n)-day \(name) streak")
        case (.weekly, true): return String(localized: "Start a Streaks+ trial to revive your \(n)-week \(name) streak")
        case (.daily, false): return String(localized: "Subscribe to Streaks+ to revive your \(n)-day \(name) streak")
        case (.weekly, false): return String(localized: "Subscribe to Streaks+ to revive your \(n)-week \(name) streak")
        }
    }

    /// Buy the resolved offer in-context and revive the broken run on success.
    /// Falls back to the full paywall when no subscription product is available.
    private func startReviveTrialPurchase() {
        #if REVENUECAT
        guard let package = storeKit.preferredOfferPackage else {
            pendingPaywallAfterTrial = true
            showingTrialOffer = false
            return
        }
        let startsTrial = storeKit.isEligibleForIntroOffer(package)
        trialError = nil
        trialInFlight = true
        Task { @MainActor in
            defer { trialInFlight = false }
            switch await storeKit.purchase(package: package) {
            case .purchased, .pending:
                await store.reviveBrokenStreak(broken)
                showingTrialOffer = false
                close()
            case .cancelled:
                trialError = startsTrial
                    ? String(localized: "Trial wasn't started. Tap again, or see all plans.")
                    : String(localized: "Purchase wasn't completed. Tap again, or see all plans.")
            case .failed:
                trialError = storeKit.lastError ?? (startsTrial
                    ? String(localized: "Couldn't start your trial. Please try again.")
                    : String(localized: "Couldn't complete the purchase. Please try again."))
            }
        }
        #else
        pendingPaywallAfterTrial = true
        showingTrialOffer = false
        #endif
    }

    private var shouldShowUpsell: Bool {
        !storeKit.isPro && canRevive
    }

    /// We can only bridge a single missed day. If the break is older than
    /// yesterday, an upgrade still gets them Pro but can't retroactively revive
    /// this particular run, so we fall back to the standard recovery options.
    private var canRevive: Bool {
        let missed = DateHelpers.startOfDay(broken.brokenAt)
        let today = DateHelpers.startOfDay(.now)
        let days = DateHelpers.gregorian.dateComponents([.day], from: missed, to: today).day ?? 0
        return days <= 1
    }

    private func handlePaywallDismiss() {
        guard storeKit.isPro else { return }
        Task {
            await store.reviveBrokenStreak(broken)
            close()
        }
    }

    private var revivalUpsell: some View {
        Button {
            showingTrialOffer = true
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "shield.lefthalf.filled")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.retroLime)
                    Text(hasTrialOffer ? "REVIVE WITH STREAKS+ TRIAL" : "REVIVE WITH STREAKS+")
                        .font(RetroFont.pixel(10))
                        .tracking(1)
                        .foregroundStyle(Theme.retroLime)
                    Spacer()
                    PixelChip(text: "STREAKS+", accent: Theme.retroMagenta)
                }
                Text(revivalBody)
                    .font(RetroFont.mono(11))
                    .foregroundStyle(Theme.retroInk)
                    .lineSpacing(3)
                    .multilineTextAlignment(.leading)
                HStack {
                    Text(hasTrialOffer ? "START TRIAL · REVIVE STREAK" : "SUBSCRIBE · REVIVE STREAK")
                        .font(RetroFont.mono(10, weight: .bold))
                        .tracking(1)
                        .foregroundStyle(Theme.retroMagenta)
                    Spacer()
                    Text("›")
                        .font(RetroFont.mono(14, weight: .bold))
                        .foregroundStyle(Theme.retroMagenta)
                }
                .padding(.top, 4)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .pixelPanel(color: Theme.retroLime, fill: Theme.retroBgRaised)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(revivalAccessibility)
    }
}

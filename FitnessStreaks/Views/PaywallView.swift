#if REVENUECAT
import SwiftUI
import RevenueCat

/// Apple-required legal URLs shared across paywall surfaces.
enum PaywallLinks {
    static let privacyPolicy = URL(string: "https://jackwallner.github.io/fitness-streaks/privacy-policy.html")!
    static let standardEULA = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!
}

/// App Store 3.1.2 subscription disclosure copy (Guideline 3.1.2).
enum PaywallDisclosure {
    static func trialChipDays(from introLabel: String) -> String? {
        guard let first = introLabel.split(separator: "-").first,
              let days = Int(first) else { return nil }
        return "\(days) DAYS FREE"
    }

    static func subscriptionFootnote(
        package: Package,
        displayPrice: String,
        isEligibleForIntro: Bool
    ) -> String {
        let recurring = package.streaksRecurringPriceLabel
        if package.packageType == .lifetime {
            return "\(displayPrice). One-time purchase, no subscription."
        }
        if isEligibleForIntro, let trial = package.streaksIntroOfferLabel {
            return "\(trial.capitalized), then \(recurring). Renews automatically unless you cancel at least 24 hours before the trial ends."
        }
        return "\(recurring). Renews automatically; cancel in Settings → Subscriptions."
    }
}

/// Native FitnessStreaks Pro paywall.
///
/// Designed to fit a single screen without scrolling on any device: compact
/// hero, four one-line feature rows, a dominant annual plan with two
/// de-emphasised alternates, one adaptive CTA, and a slim trust + legal row.
/// A ScrollView remains as a safety net for large Dynamic Type only.
struct PaywallView: View {
    @EnvironmentObject private var storeKit: StoreKitService
    @Environment(\.dismiss) private var dismiss

    /// Optional context above the hero ("Save your 45-day streak…").
    var context: String? = nil
    var displayCloseButton: Bool = true
    /// RevenueCat custom paywall impression id; omit to skip tracking.
    var paywallImpressionId: String? = nil
    var impressionOncePerSession: Bool = false

    @State private var selectedProductID: String = StoreKitService.yearlyID
    @State private var statusMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if let context {
                        contextBanner(context)
                    }
                    heroBlock
                    featureBlock
                    productBlock
                    trustBar
                }
                .padding(.horizontal, 14)
                .padding(.top, 12)
                .padding(.bottom, 8)
            }
            .background(Theme.retroBg.ignoresSafeArea())
            .safeAreaInset(edge: .bottom, spacing: 0) {
                stickyCTABlock
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("STREAKS+")
                        .font(RetroFont.pixel(11))
                        .tracking(2)
                        .foregroundStyle(Theme.retroMagenta)
                }
                if displayCloseButton {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button { dismiss() } label: {
                            Text("CLOSE")
                                .font(RetroFont.pixel(10))
                                .foregroundStyle(Theme.retroInkDim)
                        }
                    }
                }
            }
            .toolbarBackground(Theme.retroBg, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
        .task {
            // Already entitled when the paywall opens? onChange won't fire (no
            // transition), so dismiss here — otherwise a subscriber who reaches
            // this surface is trapped with no way past it.
            if storeKit.grantsUnlimitedTrackedStreaks {
                dismiss()
                return
            }
            if let id = paywallImpressionId {
                storeKit.trackPaywallImpression(id: id, oncePerSession: impressionOncePerSession)
            }
            if storeKit.products.isEmpty {
                await storeKit.loadProducts()
            }
            selectDefaultPackageIfNeeded()
        }
        // Dismiss the moment access is granted. Keyed on grantsUnlimitedTrackedStreaks
        // (isPro || purchaseGrantsFullStreakAccess), not isPro alone: a completed
        // StoreKit purchase grants access immediately, before RevenueCat reports the
        // 'pro' entitlement — without this the buyer is trapped on the paywall during
        // that window. Mirrors OnboardingView.
        .onChange(of: storeKit.grantsUnlimitedTrackedStreaks) { _, granted in
            if granted { dismiss() }
        }
        .onChange(of: storeKit.products.count) { _, _ in
            selectDefaultPackageIfNeeded()
        }
    }

    // MARK: - Context

    private func contextBanner(_ text: String) -> some View {
        HStack(spacing: 10) {
            Text("!")
                .font(RetroFont.pixel(14))
                .foregroundStyle(Theme.retroAmber)
            Text(text)
                .font(RetroFont.mono(11))
                .foregroundStyle(Theme.retroInk)
                .lineSpacing(2)
            Spacer(minLength: 0)
        }
        .padding(10)
        .pixelPanel(color: Theme.retroAmber, fill: Theme.retroBgRaised)
    }

    // MARK: - Hero

    private var heroBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center) {
                PixelFlame(size: 40, intensity: 1.0, tint: Theme.retroMagenta)
                Spacer()
                PixelChip(text: trialHeadline, accent: Theme.retroLime)
            }
            Text("DON'T BREAK THE STREAK.")
                .font(RetroFont.pixel(14))
                .foregroundStyle(Theme.retroInk)
            Text("Auto-save every streak and track every habit you build.")
                .font(RetroFont.mono(11))
                .foregroundStyle(Theme.retroInkDim)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .pixelPanel(color: Theme.retroMagenta, fill: Theme.retroBgRaised)
    }

    /// Dynamic trial chip from the storefront intro offer (never hardcoded).
    private var trialHeadline: String {
        if let package = storeKit.yearly ?? storeKit.monthly,
           storeKit.isEligibleForIntroOffer(package),
           let label = package.streaksIntroOfferLabel,
           let chip = PaywallDisclosure.trialChipDays(from: label) {
            return chip
        }
        return "STREAKS+"
    }

    // MARK: - Features

    private var featureBlock: some View {
        VStack(alignment: .leading, spacing: 0) {
            featureRow(accent: Theme.retroLime, symbol: "shield.lefthalf.filled",
                       title: "Unlimited auto-saves", first: true)
            featureRow(accent: Theme.retroCyan, symbol: "snowflake",
                       title: "Planned freeze days")
            featureRow(accent: Theme.retroAmber, symbol: "infinity",
                       title: "Unlimited custom streaks")
            featureRow(accent: Theme.retroMagenta, symbol: "bell.badge.fill",
                       title: "At-risk alerts")
        }
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .pixelPanel(color: Theme.retroInkFaint, fill: Theme.retroBgRaised)
    }

    private func featureRow(accent: Color, symbol: String, title: String, first: Bool = false) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(accent)
                .shadow(color: accent.opacity(0.6), radius: 4)
                .frame(width: 22, alignment: .center)
            Text(title)
                .font(RetroFont.mono(11, weight: .bold))
                .foregroundStyle(Theme.retroInk)
            Spacer(minLength: 0)
        }
        .padding(.vertical, 9)
        .padding(.horizontal, 12)
    }

    // MARK: - Products

    private var productBlock: some View {
        VStack(spacing: 8) {
            if storeKit.sortedPackages.isEmpty {
                if storeKit.isLoadingProducts {
                    HStack(spacing: 8) {
                        ProgressView().tint(Theme.retroInkDim)
                        Text("LOADING PRICES…")
                            .font(RetroFont.mono(10, weight: .bold))
                            .tracking(1)
                            .foregroundStyle(Theme.retroInkDim)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                } else if let error = storeKit.lastError {
                    productLoadErrorBlock(error)
                }
            } else {
                if let yearly = storeKit.yearly {
                    yearlyHeroCard(for: yearly)
                }
                let others = storeKit.sortedPackages.filter { $0.packageType != .annual }
                if !others.isEmpty {
                    VStack(spacing: 8) {
                        ForEach(others, id: \.identifier) { package in
                            secondaryProductRow(for: package)
                        }
                    }
                }
            }
        }
    }

    /// Visually dominant annual card. The per-day micro-price + SAVE-vs-monthly
    /// chip + trial badge stack work together as the primary anchor.
    private func yearlyHeroCard(for package: Package) -> some View {
        let productID = package.storeProduct.productIdentifier
        let isSelected = selectedProductID == productID
        let showsTrial = storeKit.isEligibleForIntroOffer(package)
        let savings = storeKit.yearlyVsMonthlySavingsPercent
        let perDay = storeKit.yearlyDailyEquivalent
        let priceLabel = "\(storeKit.displayPrice(for: package)) / yr"
        let perMonth = storeKit.yearlyMonthlyEquivalent

        return Button {
            selectedProductID = productID
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Text("YEARLY")
                        .font(RetroFont.pixel(12))
                        .tracking(1)
                        .foregroundStyle(Theme.retroInk)
                    Spacer()
                    if showsTrial, let label = package.streaksIntroOfferLabel,
                       let chip = PaywallDisclosure.trialChipDays(from: label) {
                        PixelChip(text: chip, accent: Theme.retroMagenta)
                    }
                    if let savings, savings >= 10 {
                        PixelChip(text: "SAVE \(savings)%", accent: Theme.retroLime)
                    }
                }
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    if let perDay {
                        Text(perDay)
                            .font(RetroFont.pixel(20))
                            .foregroundStyle(isSelected ? Theme.retroMagenta : Theme.retroInk)
                        Text("/ DAY")
                            .font(RetroFont.pixel(10))
                            .tracking(1)
                            .foregroundStyle(Theme.retroInkDim)
                    } else {
                        Text(priceLabel)
                            .font(RetroFont.pixel(18))
                            .foregroundStyle(isSelected ? Theme.retroMagenta : Theme.retroInk)
                    }
                    Spacer()
                    Text(priceLabel)
                        .font(RetroFont.mono(11, weight: .bold))
                        .foregroundStyle(Theme.retroInkDim)
                }
                if let perMonth {
                    Text("Just \(perMonth), billed yearly.")
                        .font(RetroFont.mono(10))
                        .foregroundStyle(Theme.retroInkDim)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .pixelPanel(
                color: isSelected ? Theme.retroMagenta : Theme.retroInkFaint,
                fill: Theme.retroBgRaised,
                lineWidth: isSelected ? 3 : 2
            )
        }
        .buttonStyle(.plain)
    }

    private func secondaryProductRow(for package: Package) -> some View {
        let productID = package.storeProduct.productIdentifier
        let isSelected = selectedProductID == productID
        let isLifetime = package.packageType == .lifetime
        let priceLabel: String = {
            switch package.packageType {
            case .monthly: return "\(storeKit.displayPrice(for: package)) / mo"
            default: return storeKit.displayPrice(for: package)
            }
        }()
        let detail: String = isLifetime ? "One-time · Forever yours" : "Billed monthly"

        return Button {
            selectedProductID = productID
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(packageTitle(package).uppercased())
                            .font(RetroFont.pixel(11))
                            .tracking(1)
                            .foregroundStyle(Theme.retroInk)
                        if isLifetime {
                            PixelChip(text: "BEST VALUE", accent: Theme.retroAmber)
                        }
                    }
                    Text(detail)
                        .font(RetroFont.mono(9))
                        .foregroundStyle(Theme.retroInkDim)
                }
                Spacer()
                Text(priceLabel)
                    .font(RetroFont.pixel(12))
                    .foregroundStyle(isSelected ? Theme.retroMagenta : Theme.retroInk)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .frame(maxWidth: .infinity)
            .pixelPanel(
                color: isSelected ? Theme.retroMagenta : Theme.retroInkFaint,
                fill: Theme.retroBgRaised
            )
        }
        .buttonStyle(.plain)
    }

    private func packageTitle(_ package: Package) -> String {
        switch package.packageType {
        case .annual: return "Yearly"
        case .monthly: return "Monthly"
        case .lifetime: return "Lifetime"
        default: return package.storeProduct.localizedTitle
        }
    }

    private func productLoadErrorBlock(_ error: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("PRICES DIDN'T LOAD")
                .font(RetroFont.pixel(10))
                .tracking(1)
                .foregroundStyle(Theme.retroAmber)
            Text(error)
                .font(RetroFont.mono(10))
                .foregroundStyle(Theme.retroInkDim)
                .lineSpacing(2)
            HStack(spacing: 14) {
                Button {
                    Task { await storeKit.loadProducts() }
                } label: {
                    Text("TRY AGAIN")
                        .font(RetroFont.mono(10, weight: .bold))
                        .tracking(1)
                        .foregroundStyle(Theme.retroLime)
                }
                .buttonStyle(.plain)

                Button { dismiss() } label: {
                    Text("NOT NOW")
                        .font(RetroFont.mono(10, weight: .bold))
                        .tracking(1)
                        .foregroundStyle(Theme.retroInkDim)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .pixelPanel(color: Theme.retroAmber, fill: Theme.retroBgRaised)
    }

    // MARK: - Purchase

    /// Pinned bottom CTA so the purchase button is always visible regardless of
    /// scroll position — fixes the prior layout where features + product cards
    /// pushed the CTA off-screen on smaller phones.
    private var stickyCTABlock: some View {
        VStack(spacing: 8) {
            if let statusMessage {
                Text(statusMessage)
                    .font(RetroFont.mono(10))
                    .foregroundStyle(Theme.retroAmber)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            PixelButton(title: ctaTitle, accent: Theme.retroLime) {
                guard let package = selectedPackage, !storeKit.purchaseInProgress else { return }
                Task { await purchase(package) }
            }
            .disabled(selectedPackage == nil || storeKit.purchaseInProgress)
            .opacity(selectedPackage == nil ? 0.5 : 1)

            if let reassurance = primaryReassurance {
                Text(reassurance)
                    .font(RetroFont.mono(10, weight: .bold))
                    .tracking(1)
                    .foregroundStyle(Theme.retroLime)
                    .frame(maxWidth: .infinity)
            }

            if let disclosure = selectedPlanDisclosure {
                Text(disclosure)
                    .font(RetroFont.mono(9))
                    .foregroundStyle(Theme.retroInkDim)
                    .lineSpacing(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack(spacing: 14) {
                Link(destination: PaywallLinks.standardEULA) {
                    Text("TERMS")
                        .font(RetroFont.mono(9, weight: .bold))
                        .tracking(1)
                        .foregroundStyle(Theme.retroCyan)
                }
                Link(destination: PaywallLinks.privacyPolicy) {
                    Text("PRIVACY")
                        .font(RetroFont.mono(9, weight: .bold))
                        .tracking(1)
                        .foregroundStyle(Theme.retroCyan)
                }
                Spacer()
                Button("RESTORE") {
                    Task { await restore() }
                }
                .font(RetroFont.mono(9, weight: .bold))
                .tracking(1)
                .foregroundStyle(Theme.retroCyan)
                .buttonStyle(.plain)
                .disabled(storeKit.purchaseInProgress)
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 10)
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity)
        .background(
            Theme.retroBg
                .overlay(Rectangle().fill(Theme.retroInkFaint).frame(height: 1), alignment: .top)
                .ignoresSafeArea(edges: .bottom)
        )
    }

    /// CTA copy must name the plan and recurring price (Apple 3.1.2) so the user
    /// knows exactly what they're buying before tapping. Plain "START FREE TRIAL"
    /// has been rejected for ambiguity on subscription term.
    private var ctaTitle: String {
        if storeKit.purchaseInProgress { return "PROCESSING…" }
        guard let package = selectedPackage else { return "UNAVAILABLE" }
        if package.packageType == .lifetime {
            return "UNLOCK LIFETIME · \(storeKit.displayPrice(for: package))"
        }
        let termSuffix: String = {
            switch package.packageType {
            case .annual:  return "YEARLY"
            case .monthly: return "MONTHLY"
            default: return package.streaksRecurringPriceLabel.uppercased()
            }
        }()
        if storeKit.isEligibleForIntroOffer(package),
           let label = package.streaksIntroOfferLabel,
           let chip = PaywallDisclosure.trialChipDays(from: label) {
            return "START \(chip) · \(termSuffix) \(storeKit.displayPrice(for: package))"
        }
        return "SUBSCRIBE · \(termSuffix) \(storeKit.displayPrice(for: package))"
    }

    /// Short, confident reassurance directly under the CTA.
    private var primaryReassurance: String? {
        guard let package = selectedPackage else { return nil }
        if package.packageType == .lifetime { return "ONE-TIME PURCHASE · NEVER RENEWS" }
        if storeKit.isEligibleForIntroOffer(package) { return "$0.00 DUE TODAY" }
        return nil
    }

    /// Apple 3.1.2: price and auto-renew disclosure for the selected plan.
    private var selectedPlanDisclosure: String? {
        guard let package = selectedPackage else { return nil }
        return PaywallDisclosure.subscriptionFootnote(
            package: package,
            displayPrice: storeKit.displayPrice(for: package),
            isEligibleForIntro: storeKit.isEligibleForIntroOffer(package)
        )
    }

    private var selectedPackage: Package? {
        storeKit.sortedPackages.first { $0.storeProduct.productIdentifier == selectedProductID }
            ?? storeKit.yearly
            ?? storeKit.monthly
            ?? storeKit.lifetime
    }

    private func selectDefaultPackageIfNeeded() {
        guard storeKit.yearly != nil || storeKit.monthly != nil || storeKit.lifetime != nil else { return }
        if storeKit.sortedPackages.contains(where: { $0.storeProduct.productIdentifier == selectedProductID }) {
            return
        }
        selectedProductID = storeKit.yearly?.storeProduct.productIdentifier
            ?? storeKit.monthly?.storeProduct.productIdentifier
            ?? storeKit.lifetime?.storeProduct.productIdentifier
            ?? StoreKitService.yearlyID
    }

    private func purchase(_ package: Package) async {
        statusMessage = nil
        switch await storeKit.purchase(package: package) {
        case .purchased:
            statusMessage = "WELCOME TO STREAKS+."
        case .pending:
            statusMessage = "PURCHASE PENDING APPROVAL."
        case .cancelled:
            break
        case .failed:
            statusMessage = storeKit.lastError ?? "PURCHASE FAILED. TRY AGAIN."
        }
    }

    private func restore() async {
        statusMessage = "RESTORING…"
        await storeKit.restore()
        if storeKit.isPro {
            statusMessage = "STREAKS+ RESTORED."
            // isPro was already true (restore confirmed an existing sub), so the
            // onChange dismiss never fires — dismiss explicitly so the user isn't
            // stuck staring at a paywall they've already paid for.
            dismiss()
        } else {
            statusMessage = storeKit.lastError ?? "NO ACTIVE PURCHASES FOUND."
        }
    }

    // MARK: - Trust bar

    /// Honest credibility signals: data privacy and Apple-billed (not a
    /// third-party payment form). No fabricated testimonials or review counts.
    private var trustBar: some View {
        HStack(spacing: 8) {
            trustItem(icon: "lock.shield.fill", tint: Theme.retroCyan, text: "Privacy-first")
            trustDivider
            trustItem(icon: "applelogo", tint: Theme.retroLime, text: "Apple-billed")
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
    }

    private func trustItem(icon: String, tint: Color, text: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(tint)
            Text(text.uppercased())
                .font(RetroFont.mono(9, weight: .bold))
                .tracking(1)
                .foregroundStyle(Theme.retroInkDim)
        }
    }

    private var trustDivider: some View {
        Rectangle()
            .fill(Theme.retroInkFaint)
            .frame(width: 1, height: 10)
    }

}
#endif

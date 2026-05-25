#if REVENUECAT
import SwiftUI
import RevenueCat

/// Apple-required legal URLs shared across paywall surfaces.
enum PaywallLinks {
    static let privacyPolicy = URL(string: "https://jackwallner.github.io/fitness-streaks/privacy-policy.html")!
    static let standardEULA = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!
}

/// Native FitnessStreaks Pro paywall.
///
/// Layout follows the patterns most consistently linked to higher trial-start
/// and paid conversion across consumer subscription apps (Cal AI, Headspace,
/// Blinkist, Opal, Rise, Duolingo Super):
///
/// 1. Outcome headline + trial chip above the fold.
/// 2. Explicit trial timeline (Today → reminder → first charge) — the single
///    highest-impact addition for trial-start rate; removes the "when will I
///    be charged?" anxiety that drives bail-outs.
/// 3. Feature block ordered by perceived loss-aversion value.
/// 4. One visually dominant primary plan (annual w/ trial) with per-day
///    price anchoring and SAVE-vs-monthly badge; secondary plans are still
///    selectable but de-emphasised to remove choice paralysis.
/// 5. Single primary CTA whose label adapts to the selection ("Try free
///    for 7 days" / "Subscribe" / "Unlock lifetime"). "$0.00 due today"
///    reassurance directly under it when a trial is selected.
/// 6. Trust bar (privacy / cancel anytime / Apple-billed) — credibility
///    signals without fabricated testimonials.
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
                VStack(alignment: .leading, spacing: 16) {
                    if let context {
                        contextBanner(context)
                    }
                    heroBlock
                    if showTimeline { timelineBlock }
                    featureBlock
                    productBlock
                    purchaseButton
                    if let statusMessage {
                        Text(statusMessage)
                            .font(RetroFont.mono(10))
                            .foregroundStyle(Theme.retroAmber)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                    trustBar
                    legalBlock
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 16)
            }
            .background(Theme.retroBg.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("FITNESSSTREAKS PRO")
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
            if let id = paywallImpressionId {
                storeKit.trackPaywallImpression(id: id, oncePerSession: impressionOncePerSession)
            }
            if storeKit.products.isEmpty {
                await storeKit.loadProducts()
            }
            selectDefaultPackageIfNeeded()
        }
        .onChange(of: storeKit.isPro) { _, isPro in
            if isPro { dismiss() }
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
        .padding(12)
        .pixelPanel(color: Theme.retroAmber, fill: Theme.retroBgRaised)
    }

    // MARK: - Hero

    private var heroBlock: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                PixelFlame(size: 52, intensity: 1.0, tint: Theme.retroMagenta)
                Spacer()
                PixelChip(text: trialHeadline, accent: Theme.retroLime)
            }
            VStack(alignment: .leading, spacing: 6) {
                Text("DON'T BREAK THE STREAK.")
                    .font(RetroFont.pixel(15))
                    .foregroundStyle(Theme.retroInk)
                    .lineSpacing(4)
                Text("Auto-save every streak, plan ahead for travel and rest days, and track every fitness habit you build.")
                    .font(RetroFont.mono(11))
                    .foregroundStyle(Theme.retroInkDim)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .pixelPanel(color: Theme.retroMagenta, fill: Theme.retroBgRaised)
    }

    /// "7 DAYS FREE" when a trial is available, else a neutral "PRO" chip.
    private var trialHeadline: String {
        if let package = storeKit.yearly ?? storeKit.monthly,
           storeKit.isEligibleForIntroOffer(package),
           let label = package.streaksIntroOfferLabel,
           let days = label.split(separator: "-").first {
            return "\(days) DAYS FREE"
        }
        return "PRO"
    }

    // MARK: - Trial timeline

    /// Visible whenever the user has an eligible trial — drives the highest
    /// share of the page's conversion lift. Hidden once they've already used
    /// their intro offer or no trial product is available, since the timeline
    /// would otherwise misrepresent the billing schedule.
    private var showTimeline: Bool {
        guard let package = storeKit.yearly ?? storeKit.monthly else { return false }
        return storeKit.isEligibleForIntroOffer(package)
    }

    private var timelineBlock: some View {
        let trialPkg = storeKit.yearly ?? storeKit.monthly
        let days = trialPkg.flatMap { pkg -> Int? in
            guard let intro = pkg.storeProduct.introductoryDiscount,
                  intro.paymentMode == .freeTrial else { return nil }
            let period = intro.subscriptionPeriod
            switch period.unit {
            case .day: return period.value
            case .week: return period.value * 7
            default: return nil
            }
        } ?? 7
        let priceLabel = trialPkg?.streaksRecurringPriceLabel
        return TrialTimeline(trialDays: days, priceLabel: priceLabel)
    }

    // MARK: - Features

    private var featureBlock: some View {
        VStack(alignment: .leading, spacing: 12) {
            featureRow(accent: Theme.retroLime,
                       symbol: "shield.lefthalf.filled",
                       title: "Unlimited auto-saves",
                       detail: "Miss a day, keep your streak.")
            featureRow(accent: Theme.retroCyan,
                       symbol: "snowflake",
                       title: "Planned freezes",
                       detail: "Schedule travel, sick, and vacation days in advance.")
            featureRow(accent: Theme.retroAmber,
                       symbol: "infinity",
                       title: "Unlimited custom streaks",
                       detail: "Free stops at 3 — Pro tracks every metric you've earned.")
            featureRow(accent: Theme.retroMagenta,
                       symbol: "bell.badge.fill",
                       title: "At-risk alerts",
                       detail: "Get a nudge before a streak slips away.")
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .pixelPanel(color: Theme.retroInkFaint, fill: Theme.retroBgRaised)
    }

    private func featureRow(accent: Color, symbol: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(accent)
                .shadow(color: accent.opacity(0.6), radius: 4)
                .frame(width: 22, alignment: .center)
                .padding(.top, 1)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(RetroFont.mono(11, weight: .bold))
                    .foregroundStyle(Theme.retroInk)
                Text(detail)
                    .font(RetroFont.mono(10))
                    .foregroundStyle(Theme.retroInkDim)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
    }

    // MARK: - Products

    private var productBlock: some View {
        VStack(spacing: 10) {
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
                    .padding(.vertical, 24)
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
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Text("YEARLY")
                        .font(RetroFont.pixel(12))
                        .tracking(1)
                        .foregroundStyle(Theme.retroInk)
                    Spacer()
                    if showsTrial {
                        PixelChip(text: "7 DAYS FREE", accent: Theme.retroMagenta)
                    }
                    if let savings, savings >= 10 {
                        PixelChip(text: "SAVE \(savings)%", accent: Theme.retroLime)
                    }
                }
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    if let perDay {
                        Text(perDay)
                            .font(RetroFont.pixel(22))
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
            .padding(16)
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
        let detail: String = isLifetime
            ? "One-time · Forever yours"
            : "Billed monthly · Cancel anytime"

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
            .padding(.vertical, 12)
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

    private var purchaseButton: some View {
        VStack(spacing: 10) {
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

            Button("RESTORE PURCHASES") {
                Task { await restore() }
            }
            .font(RetroFont.mono(10, weight: .bold))
            .tracking(1)
            .foregroundStyle(Theme.retroCyan)
            .buttonStyle(.plain)
            .disabled(storeKit.purchaseInProgress)
        }
    }

    private var ctaTitle: String {
        if storeKit.purchaseInProgress { return "PROCESSING…" }
        guard let package = selectedPackage else { return "UNAVAILABLE" }
        if package.packageType == .lifetime { return "UNLOCK LIFETIME" }
        if storeKit.isEligibleForIntroOffer(package) { return "TRY FREE FOR 7 DAYS" }
        return "SUBSCRIBE"
    }

    /// Short, confident reassurance directly under the CTA. Apple-spec
    /// disclosure still appears in `selectedPlanDisclosure` below it.
    private var primaryReassurance: String? {
        guard let package = selectedPackage else { return nil }
        if package.packageType == .lifetime { return "ONE-TIME PURCHASE · NEVER RENEWS" }
        if storeKit.isEligibleForIntroOffer(package) { return "$0.00 DUE TODAY · CANCEL ANYTIME" }
        return "CANCEL ANYTIME IN SETTINGS"
    }

    /// Apple 3.1.2: price, auto-renew, and cancel instructions for the selected plan.
    private var selectedPlanDisclosure: String? {
        guard let package = selectedPackage else { return nil }
        let price = package.streaksRecurringPriceLabel
        let cancel = "Payment is charged to your Apple ID at confirmation. Auto-renews unless cancelled at least 24 hours before the end of the current period. Manage or cancel in Settings → Apple ID → Subscriptions."
        if package.packageType == .lifetime {
            return "\(storeKit.displayPrice(for: package)). One-time purchase. No subscription."
        }
        if storeKit.isEligibleForIntroOffer(package), let trial = package.streaksIntroOfferLabel {
            return "\(trial.capitalized), then \(price). \(cancel)"
        }
        return "\(price). \(cancel)"
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
            statusMessage = "WELCOME TO PRO."
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
            statusMessage = "PRO RESTORED."
        } else {
            statusMessage = storeKit.lastError ?? "NO ACTIVE PURCHASES FOUND."
        }
    }

    // MARK: - Trust bar

    /// Honest credibility signals. Deliberately no fabricated testimonials or
    /// review counts — instead the three true claims that most reduce
    /// purchase friction for this app: data privacy, no-friction cancel,
    /// and Apple-billed (not a third-party payment form).
    private var trustBar: some View {
        HStack(spacing: 6) {
            trustItem(icon: "lock.shield.fill", tint: Theme.retroCyan, text: "Privacy-first")
            trustDivider
            trustItem(icon: "xmark.circle.fill", tint: Theme.retroAmber, text: "Cancel anytime")
            trustDivider
            trustItem(icon: "applelogo", tint: Theme.retroLime, text: "Apple-billed")
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
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

    // MARK: - Legal

    private var legalBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Lifetime is a one-time purchase that never renews.")
                .font(RetroFont.mono(9))
                .foregroundStyle(Theme.retroInkDim)
                .lineSpacing(2)
            HStack(spacing: 14) {
                Link(destination: PaywallLinks.standardEULA) {
                    Text("TERMS OF USE (EULA)")
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
            }
        }
        .padding(.top, 4)
    }
}
#endif

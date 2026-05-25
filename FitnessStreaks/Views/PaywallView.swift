#if REVENUECAT
import SwiftUI
import RevenueCat

/// Apple-required legal URLs shared across paywall surfaces.
enum PaywallLinks {
    static let privacyPolicy = URL(string: "https://jackwallner.github.io/fitness-streaks/privacy-policy.html")!
    static let standardEULA = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!
}

/// Native FitnessStreaks Pro paywall. Purchases flow through `StoreKitService`
/// → `Purchases.shared.purchase(package:)` so RevenueCat records transactions,
/// trials, and renewals. Dismisses when `isPro` becomes true.
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
                VStack(alignment: .leading, spacing: 14) {
                    if let context {
                        contextBanner(context)
                    }
                    heroBlock
                    featureBlock
                    productBlock
                    purchaseButton
                    if let statusMessage {
                        Text(statusMessage)
                            .font(RetroFont.mono(10))
                            .foregroundStyle(Theme.retroAmber)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
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
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                PixelFlame(size: 48, intensity: 1.0, tint: Theme.retroMagenta)
                Spacer()
                PixelChip(text: trialHeadline, accent: Theme.retroLime)
            }
            Text("NEVER LOSE A STREAK AGAIN.")
                .font(RetroFont.pixel(14))
                .foregroundStyle(Theme.retroInk)
                .lineSpacing(4)
        }
        .padding(16)
        .pixelPanel(color: Theme.retroMagenta, fill: Theme.retroBgRaised)
    }

    /// "7 DAYS FREE" when the annual plan offers a trial, else a neutral "PRO" chip.
    private var trialHeadline: String {
        if let package = storeKit.yearly ?? storeKit.monthly,
           storeKit.isEligibleForIntroOffer(package),
           let label = package.streaksIntroOfferLabel,
           let days = label.split(separator: "-").first {
            return "\(days) DAYS FREE"
        }
        return "PRO"
    }

    // MARK: - Features

    private var featureBlock: some View {
        VStack(alignment: .leading, spacing: 12) {
            featureRow(accent: Theme.retroLime,
                       symbol: "shield.lefthalf.filled",
                       text: "Unlimited auto-saves — miss a day, keep your streak.")
            featureRow(accent: Theme.retroCyan,
                       symbol: "snowflake",
                       text: "Planned freezes for travel, sick, and vacation days.")
            featureRow(accent: Theme.retroAmber,
                       symbol: "infinity",
                       text: "Unlimited custom streaks — free stops at 3.")
            featureRow(accent: Theme.retroMagenta,
                       symbol: "bell.badge.fill",
                       text: "At-risk alerts before a streak slips away.")
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .pixelPanel(color: Theme.retroInkFaint, fill: Theme.retroBgRaised)
    }

    private func featureRow(accent: Color, symbol: String, text: String) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(accent)
                .shadow(color: accent.opacity(0.6), radius: 4)
                .frame(width: 22)
            Text(text)
                .font(RetroFont.mono(11))
                .foregroundStyle(Theme.retroInk)
                .lineSpacing(2)
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
                ForEach(storeKit.sortedPackages, id: \.identifier) { package in
                    productCard(for: package)
                }
            }
        }
    }

    private func productCard(for package: Package) -> some View {
        let productID = package.storeProduct.productIdentifier
        let isSelected = selectedProductID == productID
        let isLifetime = package.packageType == .lifetime
        let showsTrial = storeKit.isEligibleForIntroOffer(package)
        let badge: (text: String, accent: Color)? = {
            if showsTrial, let _ = package.streaksIntroOfferLabel {
                return ("7 DAYS FREE", Theme.retroMagenta)
            }
            if isLifetime {
                return ("BEST VALUE", Theme.retroLime)
            }
            if package.packageType == .annual {
                return ("MOST POPULAR", Theme.retroMagenta)
            }
            return nil
        }()
        let priceLabel: String = {
            switch package.packageType {
            case .annual: return "\(storeKit.displayPrice(for: package)) / yr"
            case .monthly: return "\(storeKit.displayPrice(for: package)) / mo"
            default: return storeKit.displayPrice(for: package)
            }
        }()
        let detail: String = {
            if showsTrial, let intro = storeKit.introOfferDescription(for: package) {
                return intro
            }
            if package.packageType == .annual {
                return storeKit.yearlyMonthlyEquivalent.map { "Billed yearly · \($0)" } ?? "Billed yearly"
            }
            if isLifetime {
                return "One-time purchase · Forever yours"
            }
            return "Billed monthly · Cancel anytime"
        }()

        return Button {
            selectedProductID = productID
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(packageTitle(package).uppercased())
                            .font(RetroFont.pixel(11))
                            .tracking(1)
                            .foregroundStyle(Theme.retroInk)
                        Text(detail)
                            .font(RetroFont.mono(10))
                            .foregroundStyle(Theme.retroInkDim)
                            .lineLimit(3)
                    }
                    Spacer()
                    if let badge {
                        PixelChip(text: badge.text, accent: badge.accent)
                    }
                }
                HStack {
                    Spacer()
                    Text(priceLabel)
                        .font(RetroFont.pixel(14))
                        .foregroundStyle(isSelected ? Theme.retroMagenta : Theme.retroInk)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
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

            if let disclosure = selectedPlanDisclosure {
                Text(disclosure)
                    .font(RetroFont.mono(10))
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
        if storeKit.isEligibleForIntroOffer(package) { return "START FREE TRIAL" }
        return "SUBSCRIBE"
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

    // MARK: - Legal

    private var legalBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Lifetime is a one-time purchase that never renews.")
                .font(RetroFont.mono(10))
                .foregroundStyle(Theme.retroInkDim)
                .lineSpacing(2)
            HStack(spacing: 14) {
                Link(destination: PaywallLinks.standardEULA) {
                    Text("TERMS OF USE (EULA)")
                        .font(RetroFont.mono(10, weight: .bold))
                        .tracking(1)
                        .foregroundStyle(Theme.retroCyan)
                }
                Link(destination: PaywallLinks.privacyPolicy) {
                    Text("PRIVACY")
                        .font(RetroFont.mono(10, weight: .bold))
                        .tracking(1)
                        .foregroundStyle(Theme.retroCyan)
                }
                Spacer()
            }
        }
        .padding(.top, 8)
    }
}
#endif

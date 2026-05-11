import SwiftUI
import RevenueCat

struct ProPaywallView: View {
    @EnvironmentObject var storeKit: StoreKitService
    @EnvironmentObject var settings: StreakSettings
    @Environment(\.dismiss) private var dismiss

    var context: String? = nil

    @State private var selectedID: String = StoreKitService.yearlyID
    @State private var statusMessage: String? = nil

    private static let termsURL = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!
    private static let privacyURL = URL(string: "https://jackwallner.github.io/fitness-streaks/privacy-policy.html")!

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
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
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: {
                        Text("CLOSE")
                            .font(RetroFont.pixel(10))
                            .foregroundStyle(Theme.retroInkDim)
                    }
                }
            }
            .toolbarBackground(Theme.retroBg, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .task {
                if storeKit.products.isEmpty {
                    await storeKit.loadProducts()
                }
                if storeKit.yearly == nil {
                    selectedID = storeKit.lifetime?.storeProduct.productIdentifier ?? StoreKitService.monthlyID
                }
            }
            .onChange(of: storeKit.isPro) { _, isPro in
                if isPro { dismiss() }
            }
        }
    }

    // MARK: - Context banner

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
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                PixelFlame(size: 56, intensity: 1.0, tint: Theme.retroMagenta)
                Spacer()
                PixelChip(text: "PRO", accent: Theme.retroMagenta)
            }
            Text("NEVER LOSE A STREAK AGAIN.")
                .font(RetroFont.pixel(14))
                .foregroundStyle(Theme.retroInk)
                .lineSpacing(4)
            Text("Pro watches your active streaks, warns you before one slips, and automatically spends a Grace Day to save it when life still gets in the way.")
                .font(RetroFont.mono(11))
                .foregroundStyle(Theme.retroInkDim)
                .lineSpacing(3)
        }
        .padding(16)
        .pixelPanel(color: Theme.retroMagenta, fill: Theme.retroBgRaised)
    }

    // MARK: - Features

    private var featureBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            featureRow(
                accent: Theme.retroLime,
                symbol: "bell.badge.fill",
                title: "STREAK AT-RISK ALERTS",
                detail: "Pro warns you when your longest active streak isn't locked in yet — before the day gets away."
            )
            featureRow(
                accent: Theme.retroCyan,
                symbol: "shield.lefthalf.filled",
                title: "AUTOMATIC STREAK SAVES",
                detail: "Miss anyway? Pro instantly spends a Grace Day to save your streak. You don't lift a finger."
            )
            featureRow(
                accent: Theme.retroAmber,
                symbol: "calendar.badge.plus",
                title: "BUILD YOUR SAFETY NET",
                detail: "Earn 1 Grace Day every 30 days you keep your hero streak alive. Bank up to 9 — that's 9 misses covered."
            )
        }
    }

    private func featureRow(accent: Color, symbol: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(accent)
                .shadow(color: accent.opacity(0.6), radius: 4)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(RetroFont.pixel(10))
                    .tracking(1)
                    .foregroundStyle(Theme.retroInk)
                Text(detail)
                    .font(RetroFont.mono(10))
                    .foregroundStyle(Theme.retroInkDim)
                    .lineSpacing(2)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .pixelPanel(color: Theme.retroInkFaint)
    }

    // MARK: - Products

    private var productBlock: some View {
        VStack(spacing: 10) {
            if let yearly = storeKit.yearly {
                let intro = storeKit.introOfferDescription(for: yearly)
                productCard(
                    package: yearly,
                    isSelected: selectedID == yearly.storeProduct.productIdentifier,
                    badge: intro.map { _ in "7 DAYS FREE" } ?? "MOST POPULAR",
                    badgeAccent: Theme.retroMagenta,
                    priceLabel: "\(storeKit.displayPrice(for: yearly)) / yr",
                    detail: intro
                        ?? (storeKit.yearlyMonthlyEquivalent.map { "Billed yearly · \($0)" } ?? "Billed yearly")
                ) { selectedID = yearly.storeProduct.productIdentifier }
            }
            if let monthly = storeKit.monthly {
                productCard(
                    package: monthly,
                    isSelected: selectedID == monthly.storeProduct.productIdentifier,
                    badge: nil,
                    badgeAccent: Theme.retroCyan,
                    priceLabel: "\(storeKit.displayPrice(for: monthly)) / mo",
                    detail: "Billed monthly · Cancel anytime"
                ) { selectedID = monthly.storeProduct.productIdentifier }
            }
            if let lifetime = storeKit.lifetime {
                productCard(
                    package: lifetime,
                    isSelected: selectedID == lifetime.storeProduct.productIdentifier,
                    badge: "BEST VALUE",
                    badgeAccent: Theme.retroLime,
                    priceLabel: storeKit.displayPrice(for: lifetime),
                    detail: "One-time purchase · Forever yours"
                ) { selectedID = lifetime.storeProduct.productIdentifier }
            }
            if storeKit.products.isEmpty {
                if let error = storeKit.lastError {
                    productLoadErrorBlock(error)
                } else {
                    HStack(spacing: 8) {
                        ProgressView().tint(Theme.retroInkDim)
                        Text("LOADING PRICES…")
                            .font(RetroFont.mono(10, weight: .bold))
                            .tracking(1)
                            .foregroundStyle(Theme.retroInkDim)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                }
            }
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

                Button {
                    dismiss()
                } label: {
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

    private func productCard(
        package: Package,
        isSelected: Bool,
        badge: String?,
        badgeAccent: Color,
        priceLabel: String,
        detail: String,
        select: @escaping () -> Void
    ) -> some View {
        Button(action: select) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(package.storeProduct.localizedTitle.uppercased())
                            .font(RetroFont.pixel(11))
                            .tracking(1)
                            .foregroundStyle(Theme.retroInk)
                        Text(detail)
                            .font(RetroFont.mono(10))
                            .foregroundStyle(Theme.retroInkDim)
                            .lineLimit(2)
                    }
                    Spacer()
                    if let badge {
                        PixelChip(text: badge, accent: badgeAccent)
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

    // MARK: - Purchase / restore

    private var purchaseButton: some View {
        let package = currentSelectedPackage
        let title: String = {
            if storeKit.purchaseInProgress { return "PROCESSING…" }
            guard let package else { return "UNAVAILABLE" }
            if let intro = storeKit.introOfferDescription(for: package),
               intro.contains("free") {
                return "START 7-DAY FREE TRIAL"
            }
            return "UNLOCK PRO"
        }()
        return VStack(spacing: 10) {
            PixelButton(title: title, accent: Theme.retroLime) {
                guard let package, !storeKit.purchaseInProgress else { return }
                Task { await purchase(package: package) }
            }
            .disabled(package == nil || storeKit.purchaseInProgress)
            .opacity(package == nil ? 0.5 : 1)

            HStack(spacing: 16) {
                Button("RESTORE PURCHASES") {
                    Task { await restore() }
                }
                .font(RetroFont.mono(10, weight: .bold))
                .tracking(1)
                .foregroundStyle(Theme.retroCyan)
                .buttonStyle(.plain)
            }
            .padding(.top, 4)
        }
    }

    private var currentSelectedPackage: Package? {
        storeKit.products.first { $0.storeProduct.productIdentifier == selectedID }
            ?? storeKit.yearly ?? storeKit.monthly ?? storeKit.lifetime
    }

    private func purchase(package: Package) async {
        statusMessage = nil
        let outcome = await storeKit.purchase(package: package)
        switch outcome {
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
            statusMessage = "NO ACTIVE PURCHASES FOUND."
        }
    }

    // MARK: - Legal

    private var legalBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(subscriptionDisclosure)
                .font(RetroFont.mono(10))
                .foregroundStyle(Theme.retroInkDim)
                .lineSpacing(2)
            Text("Lifetime is a one-time purchase that never renews.")
                .font(RetroFont.mono(10))
                .foregroundStyle(Theme.retroInkDim)
                .lineSpacing(2)
            HStack(spacing: 14) {
                Link(destination: Self.termsURL) {
                    Text("TERMS OF USE (EULA)")
                        .font(RetroFont.mono(10, weight: .bold))
                        .tracking(1)
                        .foregroundStyle(Theme.retroCyan)
                }
                Link(destination: Self.privacyURL) {
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

    private var subscriptionDisclosure: String {
        let yearlyText = storeKit.yearly.map { "\(storeKit.displayPrice(for: $0)) per year" } ?? "the listed yearly price"
        let monthlyText = storeKit.monthly.map { "\(storeKit.displayPrice(for: $0)) per month" } ?? "the listed monthly price"
        return "FitnessStreaks Pro auto-renews at \(yearlyText) (yearly) or \(monthlyText) (monthly). Free trials convert to a paid yearly subscription if not cancelled at least 24 hours before they end. Payment is charged to your Apple ID at confirmation of purchase. Manage or cancel anytime in iOS Settings → Apple ID → Subscriptions."
    }
}

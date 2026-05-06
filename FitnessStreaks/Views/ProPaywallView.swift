import SwiftUI
import StoreKit

struct ProPaywallView: View {
    @EnvironmentObject var storeKit: StoreKitService
    @EnvironmentObject var settings: StreakSettings
    @Environment(\.dismiss) private var dismiss

    /// Optional context shown above the hero ("Save your 45-day streak…").
    var context: String? = nil

    @State private var selectedID: String = StoreKitService.lifetimeID
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
                    selectedID = StoreKitService.lifetimeID
                }
            }
            .onChange(of: storeKit.isPro) { _, isPro in
                if isPro { dismiss() }
            }
        }
    }

    // MARK: - Context banner (high-intent path)

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
            Text("KEEP YOUR STREAKS ALIVE WITH GRACE DAYS.")
                .font(RetroFont.pixel(14))
                .foregroundStyle(Theme.retroInk)
                .lineSpacing(4)
            Text("Bad day? Travel? Sick? Pro spends a banked Grace Day automatically so your streak survives. You earn 1 Grace Day every 30 days you keep your hero streak alive.")
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
                symbol: "shield.lefthalf.filled",
                title: "AUTOMATIC STREAK SAVES",
                detail: "Miss a day? Pro silently spends a Grace Day to preserve your streak — no panic, no manual recovery."
            )
            featureRow(
                accent: Theme.retroCyan,
                symbol: "calendar.badge.plus",
                title: "EARN GRACE DAYS",
                detail: "1 Grace Day banked for every 30 days of streak. Up to 9 saved at once."
            )
            featureRow(
                accent: Theme.retroAmber,
                symbol: "sparkles",
                title: "FUTURE PRO PERKS",
                detail: "Buy once, get every Pro feature we add. Coaching is a separate service."
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
            if let lifetime = storeKit.lifetime {
                productCard(
                    product: lifetime,
                    isSelected: selectedID == lifetime.id,
                    badge: "BEST VALUE",
                    badgeAccent: Theme.retroLime,
                    priceLabel: storeKit.displayPrice(for: lifetime),
                    detail: "One-time purchase · Forever yours"
                ) { selectedID = lifetime.id }
            }
            if let yearly = storeKit.yearly {
                productCard(
                    product: yearly,
                    isSelected: selectedID == yearly.id,
                    badge: storeKit.introOfferDescription(for: yearly).map { _ in "FREE TRIAL" },
                    badgeAccent: Theme.retroCyan,
                    priceLabel: "\(storeKit.displayPrice(for: yearly)) / yr",
                    detail: storeKit.introOfferDescription(for: yearly)
                        ?? (storeKit.yearlyMonthlyEquivalent.map { "Billed yearly · \($0)" } ?? "Billed yearly")
                ) { selectedID = yearly.id }
            }
            if storeKit.products.isEmpty {
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

    private func productCard(
        product: Product,
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
                        Text(product.displayName.uppercased())
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
        let product = currentSelectedProduct
        let title: String = {
            if storeKit.purchaseInProgress { return "PROCESSING…" }
            guard let product else { return "UNAVAILABLE" }
            if let intro = storeKit.introOfferDescription(for: product),
               intro.contains("free") {
                return "START FREE TRIAL"
            }
            return "UNLOCK PRO"
        }()
        return VStack(spacing: 10) {
            PixelButton(title: title, accent: Theme.retroLime) {
                guard let product, !storeKit.purchaseInProgress else { return }
                Task { await purchase(product) }
            }
            .disabled(product == nil || storeKit.purchaseInProgress)
            .opacity(product == nil ? 0.5 : 1)

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

    private var currentSelectedProduct: Product? {
        storeKit.products.first { $0.id == selectedID } ?? storeKit.lifetime ?? storeKit.yearly
    }

    private func purchase(_ product: Product) async {
        statusMessage = nil
        let outcome = await storeKit.purchase(product)
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
        let priceText: String
        if let yearly = storeKit.yearly {
            priceText = "\(storeKit.displayPrice(for: yearly)) per year"
        } else {
            priceText = "the listed price per year"
        }
        return "FitnessStreaks Pro yearly subscription auto-renews at \(priceText). Payment is charged to your Apple ID at confirmation of purchase. The subscription renews automatically unless cancelled at least 24 hours before the end of the current period. Manage or cancel anytime in iOS Settings → Apple ID → Subscriptions."
    }
}

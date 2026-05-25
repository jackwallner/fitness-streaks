import Foundation

#if REVENUECAT
import RevenueCat

extension Package {
    /// Human-readable trial length, e.g. "7-day free trial". Nil unless this
    /// package's intro offer is a free trial (vs intro pricing).
    var streaksIntroOfferLabel: String? {
        guard let intro = storeProduct.introductoryDiscount, intro.paymentMode == .freeTrial else {
            return nil
        }
        let period = intro.subscriptionPeriod
        let unit: String
        switch period.unit {
        case .day:   unit = period.value == 1 ? "day"   : "days"
        case .week:  unit = period.value == 1 ? "week"  : "weeks"
        case .month: unit = period.value == 1 ? "month" : "months"
        case .year:  unit = period.value == 1 ? "year"  : "years"
        @unknown default: unit = ""
        }
        if period.unit == .week {
            return "\(period.value * 7)-day free trial"
        }
        return "\(period.value)-\(unit.dropLast(period.value == 1 ? 0 : 1)) free trial"
    }

    /// Recurring-price label, e.g. "$29.99 / year". Used in the trial-offer sheet's
    /// billing disclosure (Apple 3.1.2 requires price + terms before purchase).
    var streaksRecurringPriceLabel: String {
        guard let period = storeProduct.subscriptionPeriod else {
            return storeProduct.localizedPriceString
        }
        let unit: String
        switch period.unit {
        case .day:   unit = period.value == 1 ? "day"   : "days"
        case .week:  unit = period.value == 1 ? "week"  : "weeks"
        case .month: unit = period.value == 1 ? "month" : "months"
        case .year:  unit = period.value == 1 ? "year"  : "years"
        @unknown default: unit = ""
        }
        return period.value == 1
            ? "\(storeProduct.localizedPriceString) / \(unit)"
            : "\(storeProduct.localizedPriceString) / \(period.value) \(unit)"
    }
}

/// Manages RevenueCat purchases and entitlements for FitnessStreaks Pro.
/// Single source of truth for `isPro`. Persists entitlement to App Group UserDefaults
/// so widgets / watch can read the same value without running RevenueCat.
@MainActor
final class StoreKitService: ObservableObject {
    static let shared = StoreKitService()

    // Product identifiers — must match App Store Connect AND RevenueCat dashboard.
    static let lifetimeID = "com.jackwallner.streaks.lifetime"
    static let yearlyID = "com.jackwallner.streaks.yearly"
    static let monthlyID = "com.jackwallner.streaks.monthly"

    private static let entitlementKey = "isProEntitled.v1"

    @Published private(set) var offerings: Offerings? = nil
    @Published private(set) var isPro: Bool = false
    @Published private(set) var purchaseInProgress: Bool = false
    @Published private(set) var isLoadingProducts: Bool = false
    @Published private(set) var lastError: String? = nil
    /// Per-product intro/trial eligibility for native paywall copy (Apple 3.1.2).
    @Published private(set) var introEligibility: [String: Bool] = [:]

    private var paywallImpressionsThisSession: Set<String> = []

    var monthly: Package? { offerings?.current?.monthly }
    var yearly: Package? { offerings?.current?.annual }
    var lifetime: Package? { offerings?.current?.lifetime }

    var products: [Package] {
        offerings?.current?.availablePackages ?? []
    }

    /// Yearly → monthly → lifetime, matching paywall card order.
    var sortedPackages: [Package] {
        var ordered: [Package] = []
        if let yearly { ordered.append(yearly) }
        if let monthly { ordered.append(monthly) }
        if let lifetime { ordered.append(lifetime) }
        let known = Set(ordered.map(\.identifier))
        for package in products where !known.contains(package.identifier) {
            ordered.append(package)
        }
        return ordered
    }

    private var defaults: UserDefaults {
        UserDefaults(suiteName: streaksAppGroupID) ?? .standard
    }

    private init() {
        guard let apiKey = Self.loadAPIKey(), !apiKey.isEmpty, apiKey != "REVENUECAT_API_KEY" else {
            self.isPro = defaults.bool(forKey: Self.entitlementKey)
            return
        }
        self.isPro = defaults.bool(forKey: Self.entitlementKey)
        Purchases.logLevel = .error
        Purchases.configure(with: .init(withAPIKey: apiKey)
            .with(usesStoreKit2IfAvailable: true))
        Task { await refreshState() }
    }

    // MARK: - Public API

    func loadProducts() async {
        isLoadingProducts = true
        defer { isLoadingProducts = false }
        do {
            self.lastError = nil
            self.offerings = try await Purchases.shared.offerings()
            await refreshIntroEligibility()
        } catch {
            self.lastError = "Couldn't load products: \(error.localizedDescription)"
        }
    }

    func isEligibleForIntroOffer(_ package: Package) -> Bool {
        guard package.streaksIntroOfferLabel != nil else { return false }
        return introEligibility[package.storeProduct.productIdentifier] ?? true
    }

    /// Custom paywall impressions for RevenueCat analytics (hosted UI did this automatically).
    func trackPaywallImpression(id: String, oncePerSession: Bool = false) {
        #if DEBUG
        if CommandLine.arguments.contains("-UITestSetPro") { return }
        #endif
        if oncePerSession {
            guard !paywallImpressionsThisSession.contains(id) else { return }
            paywallImpressionsThisSession.insert(id)
        }
        Purchases.shared.trackCustomPaywallImpression(
            CustomPaywallImpressionParams(paywallId: id)
        )
    }

    private func refreshIntroEligibility() async {
        let identifiers = products
            .filter { $0.storeProduct.introductoryDiscount != nil }
            .map(\.storeProduct.productIdentifier)
        guard !identifiers.isEmpty else {
            introEligibility = [:]
            return
        }
        let result = await Purchases.shared.checkTrialOrIntroDiscountEligibility(
            productIdentifiers: identifiers
        )
        introEligibility = result.mapValues { $0.status == .eligible }
    }

    @discardableResult
    func purchase(package: Package) async -> PurchaseOutcome {
        guard !purchaseInProgress else { return .cancelled }
        purchaseInProgress = true
        defer { purchaseInProgress = false }
        do {
            let (_, customerInfo, userCancelled) = try await Purchases.shared.purchase(package: package)
            if userCancelled {
                return .cancelled
            }
            updateProStatus(from: customerInfo)
            return customerInfo.entitlements["pro"]?.isActive == true ? .purchased : .pending
        } catch {
            lastError = error.localizedDescription
            return .failed
        }
    }

    func restore() async {
        do {
            let customerInfo = try await Purchases.shared.restorePurchases()
            updateProStatus(from: customerInfo)
        } catch {
            lastError = error.localizedDescription
        }
    }

    func refreshState() async {
        await loadProducts()
        await refreshEntitlement()
    }

    func refreshEntitlement() async {
        do {
            let customerInfo = try await Purchases.shared.customerInfo()
            updateProStatus(from: customerInfo)
        } catch {
            lastError = error.localizedDescription
        }
    }

    enum PurchaseOutcome { case purchased, cancelled, pending, failed }

    // MARK: - Pricing helpers

    func displayPrice(for package: Package) -> String {
        package.storeProduct.localizedPriceString
    }

    var yearlyMonthlyEquivalent: String? {
        guard let product = yearly?.storeProduct,
              let price = product.priceDecimalNumber as? NSDecimalNumber else { return nil }
        let monthly = price.dividing(by: NSDecimalNumber(value: 12))
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = product.priceFormatter?.locale ?? .current
        formatter.maximumFractionDigits = 2
        guard let formatted = formatter.string(from: monthly) else { return nil }
        return "\(formatted) / mo"
    }

    func introOfferDescription(for package: Package) -> String? {
        guard let discount = package.storeProduct.introductoryDiscount else { return nil }
        let unit: String = {
            switch discount.subscriptionPeriod.unit {
            case .day: return discount.subscriptionPeriod.value == 1 ? "day" : "days"
            case .week: return discount.subscriptionPeriod.value == 1 ? "week" : "weeks"
            case .month: return discount.subscriptionPeriod.value == 1 ? "month" : "months"
            case .year: return discount.subscriptionPeriod.value == 1 ? "year" : "years"
            @unknown default: return ""
            }
        }()
        let qty = discount.subscriptionPeriod.value
        if discount.paymentMode == .freeTrial {
            return "\(qty) \(unit) free, then \(package.storeProduct.localizedPriceString)"
        }
        return "\(discount.localizedPriceString) for \(qty) \(unit), then \(package.storeProduct.localizedPriceString)"
    }

    // MARK: - Internals

    private func updateProStatus(from customerInfo: CustomerInfo) {
        let entitled = customerInfo.entitlements["pro"]?.isActive == true
        setIsPro(entitled)
    }

    private func setIsPro(_ value: Bool) {
        if isPro != value { isPro = value }
        defaults.set(value, forKey: Self.entitlementKey)
    }

    private static func loadAPIKey() -> String? {
        guard let url = Bundle.main.url(forResource: "RevenueCat", withExtension: "plist"),
              let data = try? Data(contentsOf: url),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] else {
            return nil
        }
        return plist["API_KEY"] as? String
    }

    #if DEBUG
    func debugSetPro(_ value: Bool) {
        setIsPro(value)
    }
    #endif
}

#else
// Stub for watch/widget targets that don't link RevenueCat.
// They read isPro from the shared App Group UserDefaults written by the main app.

@MainActor
final class StoreKitService: ObservableObject {
    static let shared = StoreKitService()

    static let lifetimeID = "com.jackwallner.streaks.lifetime"
    static let yearlyID = "com.jackwallner.streaks.yearly"
    static let monthlyID = "com.jackwallner.streaks.monthly"

    @Published private(set) var isPro: Bool = false
    @Published private(set) var purchaseInProgress: Bool = false
    @Published private(set) var lastError: String? = nil

    private var defaults: UserDefaults {
        UserDefaults(suiteName: streaksAppGroupID) ?? .standard
    }

    private init() {
        self.isPro = defaults.bool(forKey: "isProEntitled.v1")
    }

    func refreshEntitlement() {
        let value = defaults.bool(forKey: "isProEntitled.v1")
        if isPro != value { isPro = value }
    }

    func refreshState() async {
        refreshEntitlement()
    }

    #if DEBUG
    func debugSetPro(_ value: Bool) {
        isPro = value
        defaults.set(value, forKey: "isProEntitled.v1")
    }
    #endif
}
#endif

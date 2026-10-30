import Foundation

enum TrialOfferResolver {
    static func isEligible(productID: String, hasFreeTrial: Bool, introEligibility: [String: Bool]) -> Bool {
        hasFreeTrial && introEligibility[productID] == true
    }

    static func preferredPackage<Offer>(
        in packages: [Offer],
        introEligibility: [String: Bool],
        productID: (Offer) -> String,
        hasFreeTrial: (Offer) -> Bool,
        isAnnual: (Offer) -> Bool,
        isSubscription: (Offer) -> Bool
    ) -> Offer? {
        let trials = packages.filter {
            isEligible(productID: productID($0), hasFreeTrial: hasFreeTrial($0), introEligibility: introEligibility)
        }
        return trials.first(where: isAnnual) ?? trials.first
            ?? packages.first(where: isAnnual) ?? packages.first(where: isSubscription)
    }
}

#if REVENUECAT
import RevenueCat

extension Package {
    /// Free-trial length in days, nil unless this package's intro offer is a
    /// free trial (vs intro pricing). Copy branches on this count instead of
    /// splicing a label, so every language can inflect the sentence.
    var streaksIntroOfferDays: Int? {
        guard let intro = storeProduct.introductoryDiscount, intro.paymentMode == .freeTrial else {
            return nil
        }
        let period = intro.subscriptionPeriod
        switch period.unit {
        case .day: return period.value
        case .week: return period.value * 7
        case .month: return period.value * 30
        case .year: return period.value * 365
        @unknown default: return nil
        }
    }

    /// Human-readable trial length, e.g. "7-day free trial".
    var streaksIntroOfferLabel: String? {
        streaksIntroOfferDays.map { String(localized: "\($0)-day free trial") }
    }

    /// Recurring-price label, e.g. "$29.99 / year". Used in the trial-offer sheet's
    /// billing disclosure (Apple 3.1.2 requires price + terms before purchase).
    var streaksRecurringPriceLabel: String {
        let price = storeProduct.localizedPriceString
        guard let period = storeProduct.subscriptionPeriod else { return price }
        let n = period.value
        if n == 1 {
            switch period.unit {
            case .day: return String(localized: "\(price) / day")
            case .week: return String(localized: "\(price) / week")
            case .month: return String(localized: "\(price) / month")
            case .year: return String(localized: "\(price) / year")
            @unknown default: return price
            }
        }
        switch period.unit {
        case .day: return String(localized: "\(price) / \(n) days")
        case .week: return String(localized: "\(price) / \(n) weeks")
        case .month: return String(localized: "\(price) / \(n) months")
        case .year: return String(localized: "\(price) / \(n) years")
        @unknown default: return price
        }
    }

    /// "$0.00" in the package's own currency, for "due today" lines.
    var streaksZeroPriceLabel: String {
        let locale = storeProduct.priceFormatter?.locale ?? .current
        let code = storeProduct.currencyCode ?? locale.currency?.identifier ?? "USD"
        return Decimal(0).formatted(.currency(code: code).locale(locale))
    }
}

/// Manages RevenueCat purchases and entitlements for FitnessStreaks Pro.
/// Single source of truth for `isPro`. Persists entitlement to App Group UserDefaults
/// so widgets / watch can read the same value without running RevenueCat.
@MainActor
final class StoreKitService: NSObject, ObservableObject {
    static let shared = StoreKitService()

    // Product identifiers — must match App Store Connect AND RevenueCat dashboard.
    static let lifetimeID = "com.jackwallner.streaks.lifetime"
    static let yearlyID = "com.jackwallner.streaks.yearly"
    static let monthlyID = "com.jackwallner.streaks.monthly"

    private static let entitlementKey = "isProEntitled.v1"

    @Published private(set) var offerings: Offerings? = nil
    @Published private(set) var isPro: Bool = false
    /// True after a successful purchase until `isPro` becomes active. Covers the
    /// window where StoreKit completed but RevenueCat entitlement is still pending.
    @Published private(set) var purchaseGrantsFullStreakAccess: Bool = false
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

    /// True only when `Purchases.configure` actually ran.
    ///
    /// This app used to protect `Purchases.shared` on device purely by the fact
    /// that a bundled `RevenueCat.plist` is present: if that file were ever
    /// missing from a build, configure would silently skip and the next paywall
    /// call would trap. Every other app in the fleet gates on a runtime flag, so
    /// a missing key disables purchases instead of killing the app.
    private(set) var isConfigured = false

    private override init() {
        super.init()
        self.isPro = defaults.bool(forKey: Self.entitlementKey)
        #if targetEnvironment(simulator)
        // Agent and simulator runs must never create customers in the production
        // RevenueCat project. StoreKit Testing supplies products separately.
        #if DEBUG
        // The one exception, behind a launch argument: the Test Store key is a
        // separate RevenueCat app inside the same project, so a probe run cannot
        // touch App Store customers, revenue or charts. See RevenueCatProbe.
        if RevenueCatProbe.isEnabled {
            Purchases.logLevel = .debug
            Purchases.configure(
                with: Configuration.Builder(withAPIKey: RevenueCatProbe.testStoreKey)
                    .with(appUserID: RevenueCatProbe.appUserID)
                    .build()
            )
            Purchases.shared.delegate = self
            isConfigured = true
        }
        #endif
        return
        #else
        guard let apiKey = Self.loadAPIKey(), !apiKey.isEmpty, apiKey != "REVENUECAT_API_KEY" else {
            return
        }
        Purchases.logLevel = .error
        Purchases.configure(with: .init(withAPIKey: apiKey)
            .with(usesStoreKit2IfAvailable: true))
        Purchases.shared.delegate = self
        isConfigured = true
        Task { await refreshState() }
        #endif
    }

    /// Pro entitlement, or a purchase just completed (entitlement may still be pending).
    var grantsUnlimitedTrackedStreaks: Bool {
        isPro || purchaseGrantsFullStreakAccess
    }

    // MARK: - Public API

    func loadProducts() async {
        // The probe is the one simulator run that configures RevenueCat, and
        // against the project's Test Store rather than production. Without this
        // it returns here and the purchase it drives has nothing to buy.
        #if DEBUG
        let probing = RevenueCatProbe.isEnabled
        #else
        let probing = false
        #endif
        #if targetEnvironment(simulator)
        if !probing {
            lastError = String(localized: "Plans are available on device and TestFlight.")
            return
        }
        #endif
        isLoadingProducts = true
        defer { isLoadingProducts = false }
        do {
            self.lastError = nil
            self.offerings = try await Purchases.shared.offerings()
            await refreshIntroEligibility()
        } catch {
            self.lastError = String(localized: "Couldn't load products: \(error.localizedDescription)")
        }
    }

    func isEligibleForIntroOffer(_ package: Package) -> Bool {
        TrialOfferResolver.isEligible(
            productID: package.storeProduct.productIdentifier,
            hasFreeTrial: package.streaksIntroOfferLabel != nil,
            introEligibility: introEligibility
        )
    }

    /// One live offer for the returning and revival sheets, including paid fallback.
    var preferredOfferPackage: Package? {
        TrialOfferResolver.preferredPackage(
            in: products,
            introEligibility: introEligibility,
            productID: { $0.storeProduct.productIdentifier },
            hasFreeTrial: { $0.streaksIntroOfferLabel != nil },
            isAnnual: { $0.packageType == .annual },
            isSubscription: { $0.storeProduct.subscriptionPeriod != nil }
        )
    }

    var eligibleTrialPackage: Package? {
        guard let package = preferredOfferPackage, isEligibleForIntroOffer(package) else { return nil }
        return package
    }

    var hasEligibleTrial: Bool { eligibleTrialPackage != nil }

    /// Custom paywall impressions for RevenueCat analytics (hosted UI did this automatically).
    func trackPaywallImpression(id: String, oncePerSession: Bool = false) {
        #if targetEnvironment(simulator)
        #if DEBUG
        if RevenueCatProbe.isEnabled, isConfigured {
            ConversionDiagnostics.recordPitchView(impressionID: id)
            syncConversionAttributes()
        }
        #endif
        return
        #else
        #if DEBUG
        if CommandLine.arguments.contains("-UITestSetPro") { return }
        #endif
        if oncePerSession {
            guard !paywallImpressionsThisSession.contains(id) else { return }
            paywallImpressionsThisSession.insert(id)
        }
        guard isConfigured else { return }
        ConversionDiagnostics.recordPitchView(impressionID: id)
        syncConversionAttributes()
        Purchases.shared.trackCustomPaywallImpression(
            CustomPaywallImpressionParams(paywallId: id)
        )
        #endif
    }

    /// Mirrors the on-device paywall record onto the RevenueCat customer.
    ///
    /// Attributes rather than extra impressions: RevenueCat treats every
    /// impression id as a paywall encounter, so funnel steps sent that way would
    /// drive the encounter rate to 100% and destroy the one server-side number
    /// that currently works.
    ///
    /// `setAttributes` only queues. RevenueCat uploads when the app backgrounds
    /// or folds the queue into the POST that creates a customer, so a probe run
    /// has to background the app before reading anything back.
    func syncConversionAttributes() {
        guard isConfigured else { return }
        let attributes = ConversionDiagnostics.subscriberAttributes
        guard !attributes.isEmpty else { return }
        Purchases.shared.attribution.setAttributes(attributes)
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
        #if DEBUG
        let probing = RevenueCatProbe.isEnabled
        #else
        let probing = false
        #endif
        #if targetEnvironment(simulator)
        if !probing {
            lastError = String(localized: "Purchases are available on device and TestFlight.")
            return .failed
        }
        #endif
        guard !purchaseInProgress else { return .cancelled }
        purchaseInProgress = true
        defer { purchaseInProgress = false }
        do {
            let (_, customerInfo, userCancelled) = try await Purchases.shared.purchase(package: package)
            if userCancelled {
                return .cancelled
            }
            updateProStatus(from: customerInfo)
            let outcome: PurchaseOutcome = isEntitled(customerInfo) ? .purchased : .pending
            if outcome == .purchased {
                ConversionDiagnostics.recordConversion(
                    plan: package.storeProduct.productIdentifier,
                    startedTrial: isEligibleForIntroOffer(package),
                    offeringID: package.presentedOfferingContext.offeringIdentifier
                )
                syncConversionAttributes()
            }
            if outcome == .purchased || outcome == .pending {
                purchaseGrantsFullStreakAccess = true
            }
            return outcome
        } catch {
            lastError = error.localizedDescription
            return .failed
        }
    }

    func restore() async {
        #if targetEnvironment(simulator)
        lastError = String(localized: "Restore is available on device and TestFlight.")
        #else
        do {
            let customerInfo = try await Purchases.shared.restorePurchases()
            updateProStatus(from: customerInfo)
        } catch {
            lastError = error.localizedDescription
        }
        #endif
    }

    func refreshState() async {
        await loadProducts()
        await refreshEntitlement()
    }

    func refreshEntitlement() async {
        #if targetEnvironment(simulator)
        return
        #else
        do {
            let customerInfo = try await Purchases.shared.customerInfo()
            updateProStatus(from: customerInfo)
        } catch {
            lastError = error.localizedDescription
        }
        #endif
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
        return String(localized: "\(formatted) / mo")
    }

    /// Percent savings of the annual plan vs paying monthly for a year.
    /// Returns nil when either plan is missing. Floored to whole percent.
    var yearlyVsMonthlySavingsPercent: Int? {
        guard let yearlyPrice = yearly?.storeProduct.priceDecimalNumber as? NSDecimalNumber,
              let monthlyPrice = monthly?.storeProduct.priceDecimalNumber as? NSDecimalNumber else {
            return nil
        }
        let twelveMonths = monthlyPrice.multiplying(by: NSDecimalNumber(value: 12))
        guard twelveMonths.doubleValue > 0 else { return nil }
        let saved = twelveMonths.subtracting(yearlyPrice).doubleValue
        guard saved > 0 else { return nil }
        return Int((saved / twelveMonths.doubleValue) * 100)
    }

    // MARK: - Internals

    /// Whether the customer currently owns the paid tier. This project has a
    /// single entitlement, so any active RevenueCat entitlement means full access.
    /// We deliberately do NOT key on a specific entitlement identifier: the
    /// dashboard's is "Fitness Habits - Streak Finder Pro" (not "pro"), and
    /// matching a brittle display string is exactly how this silently failed —
    /// purchases charged but never activated.
    private func isEntitled(_ customerInfo: CustomerInfo) -> Bool {
        !customerInfo.entitlements.active.isEmpty
    }

    private func updateProStatus(from customerInfo: CustomerInfo) {
        setIsPro(isEntitled(customerInfo))
    }

    private func setIsPro(_ value: Bool) {
        if value { purchaseGrantsFullStreakAccess = false }
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

    func debugSetPurchaseGrantsFullStreakAccess(_ value: Bool) {
        purchaseGrantsFullStreakAccess = value
    }
    #endif
}

extension StoreKitService: PurchasesDelegate {
    nonisolated func purchases(_ purchases: Purchases, receivedUpdated customerInfo: CustomerInfo) {
        Task { @MainActor in
            updateProStatus(from: customerInfo)
        }
    }
}

#else
// Stub for watch/widget targets that don't link RevenueCat.
// They read isPro from the shared App Group UserDefaults written by the main app.

@MainActor
final class StoreKitService: ObservableObject {
    static let shared = StoreKitService()

    var hasEligibleTrial: Bool { false }

    static let lifetimeID = "com.jackwallner.streaks.lifetime"
    static let yearlyID = "com.jackwallner.streaks.yearly"
    static let monthlyID = "com.jackwallner.streaks.monthly"

    @Published private(set) var isPro: Bool = false
    @Published private(set) var purchaseGrantsFullStreakAccess: Bool = false
    @Published private(set) var purchaseInProgress: Bool = false
    @Published private(set) var lastError: String? = nil

    var grantsUnlimitedTrackedStreaks: Bool {
        isPro || purchaseGrantsFullStreakAccess
    }

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
        if value { purchaseGrantsFullStreakAccess = false }
        isPro = value
        defaults.set(value, forKey: "isProEntitled.v1")
    }

    func debugSetPurchaseGrantsFullStreakAccess(_ value: Bool) {
        purchaseGrantsFullStreakAccess = value
    }
    #endif
}
#endif

#if DEBUG
/// Simulator-only proof path for the fleet-wide funnel attributes.
///
/// Under the normal rules the attributes cannot be verified on a simulator: the
/// production key must never be configured there, so RevenueCat is never
/// configured, so nothing is ever sent, so a physical device is the only
/// witness. The Test Store key is a different RevenueCat app inside the same
/// project, so a probe run cannot touch App Store customers, revenue or charts.
///
/// DEBUG only, and only with the launch argument, so it cannot reach a Release
/// build or an ordinary simulator run.
enum RevenueCatProbe {
    static var isEnabled: Bool {
        ProcessInfo.processInfo.arguments.contains("-rcfunnelprobe")
    }

    static let testStoreKey = "test_SeuNsdauZkQBSKetcgcHxzGagnO"

    static var appUserID: String {
        ProcessInfo.processInfo.environment["RC_PROBE_USER"] ?? "funnel-probe-streaks"
    }

    static var impressionID: String {
        ProcessInfo.processInfo.environment["RC_PROBE_SURFACE"] ?? "streaks_dashboard_sheet"
    }

    /// Drives a Test Store purchase after the impression, so the `converted_*`
    /// half of the funnel record is exercised and not just the impression half.
    static var wantsPurchase: Bool {
        ProcessInfo.processInfo.arguments.contains("-rcfunnelprobepurchase")
    }
}
#endif

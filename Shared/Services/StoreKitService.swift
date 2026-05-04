import Foundation
import StoreKit

/// Manages StoreKit 2 purchases for FitnessStreaks Pro.
/// Single source of truth for `isPro`. Persists entitlement to App Group UserDefaults
/// so widgets / watch can read the same value without re-running StoreKit.
@MainActor
final class StoreKitService: ObservableObject {
    static let shared = StoreKitService()

    // Product identifiers — must match App Store Connect exactly.
    static let lifetimeID = "com.jackwallner.streaks.pro.lifetime"
    static let yearlyID = "com.jackwallner.streaks.pro.yearly"
    static let allProductIDs: Set<String> = [lifetimeID, yearlyID]

    private static let entitlementKey = "isProEntitled.v1"

    @Published private(set) var products: [Product] = []
    @Published private(set) var isPro: Bool = false
    @Published private(set) var purchaseInProgress: Bool = false
    @Published private(set) var lastError: String? = nil

    var lifetime: Product? { products.first { $0.id == Self.lifetimeID } }
    var yearly: Product? { products.first { $0.id == Self.yearlyID } }

    private var updatesTask: Task<Void, Never>? = nil

    private var defaults: UserDefaults {
        UserDefaults(suiteName: streaksAppGroupID) ?? .standard
    }

    private init() {
        // Restore cached entitlement immediately so the UI doesn't flash "free" on cold launch
        // before StoreKit's currentEntitlements iterator finishes.
        self.isPro = defaults.bool(forKey: Self.entitlementKey)
        startTransactionListener()
        Task { await refreshState() }
    }

    deinit { updatesTask?.cancel() }

    // MARK: - Public API

    func loadProducts() async {
        do {
            let fetched = try await Product.products(for: Array(Self.allProductIDs))
            self.products = fetched.sorted { $0.price < $1.price }
        } catch {
            self.lastError = "Couldn't load products: \(error.localizedDescription)"
        }
    }

    @discardableResult
    func purchase(_ product: Product) async -> PurchaseOutcome {
        guard !purchaseInProgress else { return .cancelled }
        purchaseInProgress = true
        defer { purchaseInProgress = false }
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await transaction.finish()
                await refreshEntitlement()
                return .purchased
            case .userCancelled:
                return .cancelled
            case .pending:
                return .pending
            @unknown default:
                return .cancelled
            }
        } catch {
            lastError = error.localizedDescription
            return .failed
        }
    }

    func restore() async {
        do {
            try await AppStore.sync()
            await refreshEntitlement()
        } catch {
            lastError = error.localizedDescription
        }
    }

    func refreshState() async {
        await loadProducts()
        await refreshEntitlement()
    }

    func refreshEntitlement() async {
        var entitled = false
        for await result in Transaction.currentEntitlements {
            guard case .verified(let txn) = result else { continue }
            guard Self.allProductIDs.contains(txn.productID) else { continue }
            if txn.revocationDate == nil {
                entitled = true
            }
        }
        setIsPro(entitled)
    }

    enum PurchaseOutcome { case purchased, cancelled, pending, failed }

    // MARK: - Internals

    private func startTransactionListener() {
        updatesTask = Task { [weak self] in
            for await update in Transaction.updates {
                guard let self else { continue }
                if case .verified(let txn) = update {
                    await txn.finish()
                    await self.refreshEntitlement()
                }
            }
        }
    }

    private func setIsPro(_ value: Bool) {
        if isPro != value { isPro = value }
        defaults.set(value, forKey: Self.entitlementKey)
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .verified(let safe): return safe
        case .unverified: throw StoreError.unverified
        }
    }

    enum StoreError: LocalizedError {
        case unverified
        var errorDescription: String? {
            switch self {
            case .unverified: "Purchase couldn't be verified by the App Store."
            }
        }
    }

    // MARK: - Pricing helpers

    /// Localized monthly cost equivalent of the yearly subscription, e.g. "$0.42 / mo".
    var yearlyMonthlyEquivalent: String? {
        guard let product = yearly else { return nil }
        let monthly = NSDecimalNumber(decimal: product.price)
            .dividing(by: NSDecimalNumber(value: 12))
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = product.priceFormatStyle.locale
        formatter.maximumFractionDigits = 2
        guard let formatted = formatter.string(from: monthly) else { return nil }
        return "\(formatted) / mo"
    }

    /// Display price for the given product (e.g. "$9.99").
    func displayPrice(for product: Product) -> String {
        product.displayPrice
    }

    /// Localized intro offer description ("7 days free, then $4.99/yr"), or nil if no intro.
    func introOfferDescription(for product: Product) -> String? {
        guard let sub = product.subscription else { return nil }
        guard let intro = sub.introductoryOffer else { return nil }
        let unit: String = {
            switch intro.period.unit {
            case .day: return intro.period.value == 1 ? "day" : "days"
            case .week: return intro.period.value == 1 ? "week" : "weeks"
            case .month: return intro.period.value == 1 ? "month" : "months"
            case .year: return intro.period.value == 1 ? "year" : "years"
            @unknown default: return ""
            }
        }()
        let qty = intro.period.value
        switch intro.paymentMode {
        case .freeTrial:
            return "\(qty) \(unit) free, then \(product.displayPrice)"
        case .payAsYouGo, .payUpFront:
            return "\(intro.displayPrice) for \(qty) \(unit), then \(product.displayPrice)"
        default:
            return nil
        }
    }

    #if DEBUG
    /// Debug-only override for screenshots / local QA. Not compiled in release.
    func debugSetPro(_ value: Bool) {
        setIsPro(value)
    }
    #endif
}

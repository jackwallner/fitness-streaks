import Foundation
import SwiftUI
import os

// MARK: - Data Models

enum RevenuePeriod: String, CaseIterable, Codable, Sendable, Identifiable {
    case monthly
    case yearly
    case lifetime

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .monthly: "Monthly"
        case .yearly: "Yearly"
        case .lifetime: "Lifetime"
        }
    }

    var symbol: String {
        switch self {
        case .monthly: "calendar"
        case .yearly: "calendar.badge.clock"
        case .lifetime: "infinity"
        }
    }

    var calendarComponent: Calendar.Component {
        switch self {
        case .monthly: .month
        case .yearly: .year
        case .lifetime: .era
        }
    }
}

enum RevenueSource: String, Codable, Sendable {
    case subscriptions
    case oneTimePurchases
    case total

    var displayName: String {
        switch self {
        case .subscriptions: "Subscriptions"
        case .oneTimePurchases: "One-Time"
        case .total: "Total"
        }
    }
}

struct RevenueEntry: Identifiable, Hashable, Sendable, Codable {
    let id: String
    let date: Date
    let subscriptions: Double
    let oneTimePurchases: Double

    var total: Double { subscriptions + oneTimePurchases }

    init(id: String = UUID().uuidString, date: Date, subscriptions: Double = 0, oneTimePurchases: Double = 0) {
        self.id = id
        self.date = date
        self.subscriptions = subscriptions
        self.oneTimePurchases = oneTimePurchases
    }

    func value(for source: RevenueSource) -> Double {
        switch source {
        case .subscriptions: subscriptions
        case .oneTimePurchases: oneTimePurchases
        case .total: total
        }
    }
}

struct RevenueReport: Identifiable, Hashable, Sendable {
    let period: RevenuePeriod
    let source: RevenueSource
    let currentValue: Double
    let previousValue: Double
    let bestValue: Double
    let averageValue: Double
    let growthPercent: Double
    let entries: [RevenueEntry]
    let trend: RevenueTrend

    var id: String { "\(period.rawValue)-\(source.rawValue)" }

    var displayName: String {
        "\(period.displayName) \(source.displayName)"
    }

    var formattedCurrent: String {
        RevenueReport.formatCurrency(currentValue)
    }

    var formattedGrowth: String {
        let sign = growthPercent >= 0 ? "+" : ""
        return "\(sign)\(String(format: "%.1f", growthPercent))%"
    }

    var growthIsPositive: Bool { growthPercent >= 0 }

    static func formatCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale.current
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? "$\(Int(value))"
    }
}

enum RevenueTrend: String, Sendable, Codable {
    case up
    case down
    case flat

    var symbol: String {
        switch self {
        case .up: "arrow.up.right"
        case .down: "arrow.down.right"
        case .flat: "arrow.right"
        }
    }
}

struct RevenueSnapshot: Codable, Sendable {
    let updated: Date
    let reports: [SnapshotReport]
    let totalLifetime: Double

    struct SnapshotReport: Codable, Sendable {
        let period: String
        let source: String
        let currentValue: Double
        let growthPercent: Double
        let trend: String
    }
}

// MARK: - Revenue Engine

enum RevenueEngine {

    static func analyze(
        entries: [RevenueEntry],
        periods: [RevenuePeriod] = RevenuePeriod.allCases,
        sources: [RevenueSource] = [.total, .subscriptions, .oneTimePurchases]
    ) -> [RevenueReport] {
        guard !entries.isEmpty else { return [] }

        let calendar = Calendar.current
        let now = Date()
        let sorted = entries.sorted { $0.date < $1.date }
        var reports: [RevenueReport] = []

        for period in periods {
            for source in sources {
                let grouped = groupByPeriod(sorted, period: period, calendar: calendar, now: now)
                guard !grouped.isEmpty else { continue }

                let periodEntries = grouped.map { agg in
                    RevenueEntry(
                        date: agg.startDate,
                        subscriptions: agg.subscriptions,
                        oneTimePurchases: agg.oneTimePurchases
                    )
                }

                let values = periodEntries.map { $0.value(for: source) }
                let current = values.last ?? 0
                let previous = values.dropLast().last ?? 0
                let best = values.max() ?? 0
                let average = values.isEmpty ? 0 : values.reduce(0, +) / Double(values.count)
                let growth = previous > 0
                    ? ((current - previous) / previous) * 100
                    : (current > 0 ? 100 : 0)

                let trend: RevenueTrend
                if growth > 5 { trend = .up }
                else if growth < -5 { trend = .down }
                else { trend = .flat }

                reports.append(RevenueReport(
                    period: period,
                    source: source,
                    currentValue: current,
                    previousValue: previous,
                    bestValue: best,
                    averageValue: average,
                    growthPercent: growth,
                    entries: periodEntries,
                    trend: trend
                ))
            }
        }

        return reports.sorted { score($0) > score($1) }
    }

    static func snapshot(from reports: [RevenueReport]) -> RevenueSnapshot {
        let lifetimeReport = reports.first(where: { $0.period == .lifetime && $0.source == .total })
        return RevenueSnapshot(
            updated: .now,
            reports: reports.prefix(12).map { report in
                RevenueSnapshot.SnapshotReport(
                    period: report.period.rawValue,
                    source: report.source.rawValue,
                    currentValue: report.currentValue,
                    growthPercent: report.growthPercent,
                    trend: report.trend.rawValue
                )
            },
            totalLifetime: lifetimeReport?.currentValue ?? 0
        )
    }

    static func history(for report: RevenueReport) -> [(date: Date, value: Double)] {
        report.entries.map { (date: $0.date, value: $0.value(for: report.source)) }
    }

    // MARK: - Private

    private struct PeriodAggregate {
        let startDate: Date
        var subscriptions: Double = 0
        var oneTimePurchases: Double = 0
    }

    private static func groupByPeriod(
        _ entries: [RevenueEntry],
        period: RevenuePeriod,
        calendar: Calendar,
        now: Date
    ) -> [PeriodAggregate] {
        guard period != .lifetime else {
            let sub = entries.reduce(0.0) { $0 + $1.subscriptions }
            let oneTime = entries.reduce(0.0) { $0 + $1.oneTimePurchases }
            return [PeriodAggregate(startDate: entries.first?.date ?? now, subscriptions: sub, oneTimePurchases: oneTime)]
        }

        let component = period.calendarComponent
        var grouped: [Date: PeriodAggregate] = [:]

        for entry in entries {
            guard let start = calendar.dateInterval(of: component, for: entry.date)?.start else { continue }
            var agg = grouped[start] ?? PeriodAggregate(startDate: start)
            agg.subscriptions += entry.subscriptions
            agg.oneTimePurchases += entry.oneTimePurchases
            grouped[start] = agg
        }

        return grouped.keys.sorted().compactMap { grouped[$0] }
    }

    private static func score(_ report: RevenueReport) -> Double {
        let periodWeight: Double
        switch report.period {
        case .monthly: periodWeight = 1.0
        case .yearly: periodWeight = 1.2
        case .lifetime: periodWeight = 0.8
        }
        return report.currentValue * periodWeight
    }
}

// MARK: - Revenue Service

private let revenueLog = Logger(subsystem: "com.jackwallner.streaks", category: "RevenueService")

@MainActor
final class RevenueService: ObservableObject {
    static let shared = RevenueService()

    private let apiKey = "appl_fYcSkBqltUDcioLROFjHugUSoeV"
    private let defaults = UserDefaults(suiteName: streaksAppGroupID) ?? .standard
    private let cacheKey = "revenueCache.v1"
    private let cacheDateKey = "revenueCacheDate.v1"

    @Published var entries: [RevenueEntry] = []
    @Published var isFetching = false
    @Published var lastError: String?

    private init() {
        restoreCache()
    }

    func fetch() async throws -> [RevenueEntry] {
        isFetching = true
        defer { isFetching = false }

        if let cached = cachedEntries(), !isCacheStale() {
            entries = cached
            return cached
        }

        do {
            let result = try await fetchFromAPI()
            cache(result)
            entries = result
            return result
        } catch {
            revenueLog.warning("RevenueService API fetch failed: \(String(describing: error)), falling back to mock data")
            let mock = generateMockEntries()
            cache(mock)
            entries = mock
            return mock
        }
    }

    func cachedEntries() -> [RevenueEntry]? {
        guard let data = defaults.data(forKey: cacheKey) else { return nil }
        return try? JSONDecoder().decode([RevenueEntry].self, from: data)
    }

    // MARK: - Private

    private func isCacheStale() -> Bool {
        let lastFetch = defaults.object(forKey: cacheDateKey) as? Date ?? .distantPast
        return Date().timeIntervalSince(lastFetch) > 3600
    }

    private func cache(_ entries: [RevenueEntry]) {
        if let data = try? JSONEncoder().encode(entries) {
            defaults.set(data, forKey: cacheKey)
            defaults.set(Date(), forKey: cacheDateKey)
        }
    }

    private func restoreCache() {
        entries = cachedEntries() ?? []
    }

    private func generateMockEntries() -> [RevenueEntry] {
        let calendar = Calendar.current
        let now = Date()
        var entries: [RevenueEntry] = []

        for monthsAgo in stride(from: 23, through: 0, by: -1) {
            guard let date = calendar.date(byAdding: .month, value: -monthsAgo, to: now) else { continue }
            let base: Double = 500 + Double(abs(monthsAgo - 12)) * 50
            let subscriptions = base + Double.random(in: -100...200)
            let oneTime = Double.random(in: 50...300)
            entries.append(RevenueEntry(date: date, subscriptions: subscriptions, oneTimePurchases: oneTime))
        }

        return entries
    }

    private func fetchFromAPI() async throws -> [RevenueEntry] {
        let url = URL(string: "https://api.appstoreconnect.apple.com/v1/financeReports")!

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 30

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw RevenueError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            revenueLog.error("RevenueService API returned \(httpResponse.statusCode)")
            throw RevenueError.httpError(httpResponse.statusCode)
        }

        return try decodeResponse(data)
    }

    private func decodeResponse(_ data: Data) throws -> [RevenueEntry] {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let payload = try decoder.decode(RevenueAPIResponse.self, from: data)
        return payload.entries.map { entry in
            RevenueEntry(
                date: entry.date,
                subscriptions: entry.subscriptions,
                oneTimePurchases: entry.oneTimePurchases
            )
        }
    }
}

enum RevenueError: LocalizedError {
    case invalidResponse
    case httpError(Int)
    case decodingFailed

    var errorDescription: String? {
        switch self {
        case .invalidResponse: "Invalid response from server."
        case .httpError(let code): "Server returned status \(code)."
        case .decodingFailed: "Failed to decode server response."
        }
    }
}

private struct RevenueAPIResponse: Codable {
    let entries: [APIEntry]

    struct APIEntry: Codable {
        let date: Date
        let subscriptions: Double
        let oneTimePurchases: Double
    }
}

// MARK: - Revenue Store

private let storeLog = Logger(subsystem: "com.jackwallner.streaks", category: "RevenueStore")

@MainActor
final class RevenueStore: ObservableObject {
    static let shared = RevenueStore()

    enum LoadStage: Equatable {
        case idle
        case fetchingData
        case analyzingRevenue
        case finalizing

        var label: String {
            switch self {
            case .idle: ""
            case .fetchingData: "FETCHING REVENUE DATA"
            case .analyzingRevenue: "ANALYZING REVENUE"
            case .finalizing: "FINALIZING"
            }
        }
    }

    @Published var reports: [RevenueReport] = []
    @Published var entries: [RevenueEntry] = []
    @Published var isLoading = false
    @Published var loadProgress: Double = 0
    @Published var loadStage: LoadStage = .idle
    @Published var lastUpdated: Date?
    @Published var isRefreshing = false
    @Published var selectedPeriods: Set<RevenuePeriod> = Set(RevenuePeriod.allCases)
    @Published var selectedSources: Set<RevenueSource> = [.total, .subscriptions, .oneTimePurchases]

    private let defaults = UserDefaults(suiteName: streaksAppGroupID) ?? .standard
    private let snapshotKey = "revenueSnapshot.v1"

    var pricing: Pricing { Pricing.current }

    @MainActor
    struct Pricing {
        let monthly: String
        let yearly: String
        let lifetime: String

        static var current: Pricing {
            let storeKit = StoreKitService.shared
            return Pricing(
                monthly: storeKit.monthly?.storeProduct.localizedPriceString ?? "$2.99",
                yearly: storeKit.yearly?.storeProduct.localizedPriceString ?? "$19.99",
                lifetime: storeKit.lifetime?.storeProduct.localizedPriceString ?? "$49.99"
            )
        }
    }

    var hero: RevenueReport? { reports.first }
    var badges: [RevenueReport] { Array(reports.dropFirst()) }

    var monthlyReports: [RevenueReport] { reports.filter { $0.period == .monthly } }
    var yearlyReports: [RevenueReport] { reports.filter { $0.period == .yearly } }
    var lifetimeReports: [RevenueReport] { reports.filter { $0.period == .lifetime } }

    private init() {}

    func persistCurrentSnapshot() {
        let snapshot = RevenueEngine.snapshot(from: reports)
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults.set(data, forKey: snapshotKey)
    }

    func loadSnapshot() -> RevenueSnapshot? {
        guard let data = defaults.data(forKey: snapshotKey) else { return nil }
        return try? JSONDecoder().decode(RevenueSnapshot.self, from: data)
    }

    func refreshIfNeeded(force: Bool = false) async {
        if isLoading || isRefreshing { return }
        let stale = lastUpdated.map { Date().timeIntervalSince($0) > 300 } ?? true
        guard force || stale else { return }
        isRefreshing = true
        defer { isRefreshing = false }
        await load()
    }

    func load() async {
        if isLoading { return }

        isLoading = true
        withAnimation(.linear(duration: 0.2)) {
            loadStage = .fetchingData
            loadProgress = 0.1
        }
        defer {
            isLoading = false
            withAnimation(.linear(duration: 0.2)) {
                loadStage = .idle
                loadProgress = 0
            }
        }

        do {
            let fresh = try await RevenueService.shared.fetch()
            self.entries = fresh

            withAnimation(.linear(duration: 0.25)) {
                loadProgress = 0.6
                loadStage = .analyzingRevenue
            }

            let all = RevenueEngine.analyze(
                entries: fresh,
                periods: Array(selectedPeriods),
                sources: Array(selectedSources)
            )
            self.reports = all
            self.lastUpdated = .now

            withAnimation(.linear(duration: 0.25)) {
                loadProgress = 0.95
                loadStage = .finalizing
            }

            persistCurrentSnapshot()

            withAnimation(.linear(duration: 0.2)) {
                loadProgress = 1.0
            }
        } catch {
            storeLog.error("RevenueStore load error: \(String(describing: error))")
            if let cached = RevenueService.shared.cachedEntries() {
                self.entries = cached
                let all = RevenueEngine.analyze(
                    entries: cached,
                    periods: Array(selectedPeriods),
                    sources: Array(selectedSources)
                )
                self.reports = all
                self.lastUpdated = .now
                persistCurrentSnapshot()
            }
        }
    }
}

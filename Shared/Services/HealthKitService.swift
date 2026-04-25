import Foundation
import HealthKit
import SwiftData
import WidgetKit
import os
#if os(watchOS)
import WatchKit
#endif

private let log = Logger(subsystem: "com.jackwallner.streaks", category: "HealthKit")

@MainActor
final class HealthKitService: ObservableObject {
    static let shared = HealthKitService()

    private let store = HKHealthStore()
    @Published var isAuthorized: Bool = false

    /// Quantity types we query as statistics collections.
    private let quantityTypes: [HKQuantityTypeIdentifier] = [
        .stepCount,
        .appleExerciseTime,
        .appleStandTime,           // stand MINUTES; we'll derive hours = minutes/60 as an approximation
        .activeEnergyBurned,
        .distanceWalkingRunning,
        .flightsClimbed,
    ]

    /// Category types (mindful session, sleep analysis) + workout type.
    private var categoryReadTypes: Set<HKObjectType> {
        var set: Set<HKObjectType> = [HKObjectType.workoutType()]
        if let mindful = HKObjectType.categoryType(forIdentifier: .mindfulSession) {
            set.insert(mindful)
        }
        if let sleep = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) {
            set.insert(sleep)
        }
        return set
    }

    private var allReadTypes: Set<HKObjectType> {
        var types: Set<HKObjectType> = categoryReadTypes
        for id in quantityTypes {
            types.insert(HKQuantityType(id))
        }
        // Apple Watch stand hours as a distinct "meeting the hour goal" count
        if let standHours = HKObjectType.quantityType(forIdentifier: .appleStandTime) {
            types.insert(standHours)
        }
        return types
    }

    private init() {
        Task {
            let status = await self.authorizationRequestStatus()
            if status == .unnecessary {
                self.isAuthorized = true
            }
        }
    }

    // MARK: - Authorization

    func requestAuthorization() async throws {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        log.info("Requesting HealthKit authorization for \(self.allReadTypes.count) read types")
        try await store.requestAuthorization(toShare: [], read: allReadTypes)
        isAuthorized = true
    }

    func authorizationRequestStatus() async -> HKAuthorizationRequestStatus? {
        guard HKHealthStore.isHealthDataAvailable() else { return nil }
        return await withCheckedContinuation { continuation in
            store.getRequestStatusForAuthorization(toShare: [], read: allReadTypes) { status, error in
                if let error {
                    log.error("auth request status error: \(String(describing: error))")
                    continuation.resume(returning: nil)
                } else {
                    continuation.resume(returning: status)
                }
            }
        }
    }

    /// Reflects current authorization state without ever prompting. The system permission
    /// sheet must only appear in response to a user-initiated action (App Store 5.1.1),
    /// so requesting is the caller's job — typically OnboardingView's "CONNECT HEALTH" tap.
    func synchronizeAuthorization() async {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        guard let status = await authorizationRequestStatus() else { return }
        // .unnecessary means we've asked at least once; treat that as "proceed to dashboard"
        // even if the user denied specific types — the empty state guides them to Settings.
        isAuthorized = (status == .unnecessary)
    }

    // MARK: - History fetch

    /// Fetch N days of activity back from today, inclusive.
    func fetchHistory(days: Int) async throws -> [ActivityDay] {
        let calendar = DateHelpers.gregorian
        let end = calendar.date(byAdding: .day, value: 1, to: DateHelpers.startOfDay())
            ?? DateHelpers.startOfDay()
        let start = DateHelpers.daysAgo(days - 1)

        async let steps = quantityDaily(.stepCount, unit: .count(), start: start, end: end)
        async let exercise = quantityDaily(.appleExerciseTime, unit: .minute(), start: start, end: end)
        async let standMinutes = quantityDaily(.appleStandTime, unit: .minute(), start: start, end: end)
        async let energy = quantityDaily(.activeEnergyBurned, unit: .kilocalorie(), start: start, end: end)
        async let distance = quantityDaily(.distanceWalkingRunning, unit: .mile(), start: start, end: end)
        async let flights = quantityDaily(.flightsClimbed, unit: .count(), start: start, end: end)
        async let workouts = workoutCounts(start: start, end: end)
        async let mindful = categoryMinutes(.mindfulSession, start: start, end: end)
        async let sleep = sleepHoursByDay(start: start, end: end)

        let (s, ex, sh, en, dist, fl, wo, mi, sl) = try await (steps, exercise, standMinutes, energy, distance, flights, workouts, mindful, sleep)

        var results: [ActivityDay] = []
        var cursor = start
        while cursor < end {
            let key = cursor
            let standHoursValue = (sh[key] ?? 0) / 60.0 // minutes → hours
            results.append(ActivityDay(
                date: cursor,
                steps: s[key] ?? 0,
                exerciseMinutes: ex[key] ?? 0,
                standHours: standHoursValue,
                activeEnergy: en[key] ?? 0,
                workoutCount: wo[key] ?? 0,
                mindfulMinutes: mi[key] ?? 0,
                sleepHours: sl[key] ?? 0,
                distanceMiles: dist[key] ?? 0,
                flightsClimbed: fl[key] ?? 0
            ))
            cursor = DateHelpers.addDays(1, to: cursor)
        }
        return results
    }

    // MARK: - Hourly steps (for time-of-day pattern mining)

    /// Returns [dayStart: [hour: stepCount]] for the given window.
    /// Used by StreakEngine.discoverHourWindows to find hidden time-of-day rhythms.
    func fetchHourlySteps(days: Int) async throws -> [Date: [Int: Double]] {
        let calendar = DateHelpers.gregorian
        let end = calendar.date(byAdding: .day, value: 1, to: DateHelpers.startOfDay())
            ?? DateHelpers.startOfDay()
        let start = DateHelpers.daysAgo(days - 1)

        let type = HKQuantityType(.stepCount)
        let interval = DateComponents(hour: 1)
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsCollectionQuery(
                quantityType: type,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum,
                anchorDate: start,
                intervalComponents: interval
            )
            query.initialResultsHandler = { _, collection, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                var out: [Date: [Int: Double]] = [:]
                collection?.enumerateStatistics(from: start, to: end) { stat, _ in
                    let dayKey = DateHelpers.startOfDay(stat.startDate)
                    let hour = calendar.component(.hour, from: stat.startDate)
                    let value = stat.sumQuantity()?.doubleValue(for: .count()) ?? 0
                    out[dayKey, default: [:]][hour] = value
                }
                continuation.resume(returning: out)
            }
            self.store.execute(query)
        }
    }

    // MARK: - Quantity (daily sum)

    private func quantityDaily(
        _ id: HKQuantityTypeIdentifier,
        unit: HKUnit,
        start: Date,
        end: Date
    ) async throws -> [Date: Double] {
        let type = HKQuantityType(id)
        let interval = DateComponents(day: 1)
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsCollectionQuery(
                quantityType: type,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum,
                anchorDate: start,
                intervalComponents: interval
            )
            query.initialResultsHandler = { _, collection, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                var out: [Date: Double] = [:]
                collection?.enumerateStatistics(from: start, to: end) { stat, _ in
                    let key = DateHelpers.startOfDay(stat.startDate)
                    let value = stat.sumQuantity()?.doubleValue(for: unit) ?? 0
                    out[key] = value
                }
                continuation.resume(returning: out)
            }
            store.execute(query)
        }
    }

    // MARK: - Workouts

    private func workoutCounts(start: Date, end: Date) async throws -> [Date: Double] {
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        let samples: [HKWorkout] = try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: HKObjectType.workoutType(),
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: nil
            ) { _, results, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: (results as? [HKWorkout]) ?? [])
                }
            }
            store.execute(query)
        }

        var out: [Date: Double] = [:]
        for w in samples {
            let key = DateHelpers.startOfDay(w.startDate)
            out[key, default: 0] += 1
        }
        return out
    }

    // MARK: - Category (mindful minutes)

    private func categoryMinutes(
        _ id: HKCategoryTypeIdentifier,
        start: Date,
        end: Date
    ) async throws -> [Date: Double] {
        guard let type = HKObjectType.categoryType(forIdentifier: id) else { return [:] }
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        let samples: [HKCategorySample] = try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: type,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: nil
            ) { _, results, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: (results as? [HKCategorySample]) ?? [])
                }
            }
            store.execute(query)
        }

        var out: [Date: Double] = [:]
        for s in samples {
            let minutes = s.endDate.timeIntervalSince(s.startDate) / 60.0
            let key = DateHelpers.startOfDay(s.startDate)
            out[key, default: 0] += minutes
        }
        return out
    }

    // MARK: - Sleep

    /// Sum "asleep" sample durations, attributing to the day each sample ended on.
    private func sleepHoursByDay(start: Date, end: Date) async throws -> [Date: Double] {
        guard let type = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else { return [:] }

        // Widen the query window on the start side: a sleep sample ending on day N may
        // have started the evening of N-1 (or earlier). The end window is already right.
        let wideStart = DateHelpers.daysAgo(1, from: start)
        let predicate = HKQuery.predicateForSamples(withStart: wideStart, end: end, options: .strictEndDate)

        let samples: [HKCategorySample] = try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: type,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: nil
            ) { _, results, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: (results as? [HKCategorySample]) ?? [])
                }
            }
            store.execute(query)
        }

        let asleepValues: Set<Int> = [
            HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue,
            HKCategoryValueSleepAnalysis.asleepCore.rawValue,
            HKCategoryValueSleepAnalysis.asleepDeep.rawValue,
            HKCategoryValueSleepAnalysis.asleepREM.rawValue,
        ]

        var out: [Date: Double] = [:]
        for s in samples where asleepValues.contains(s.value) {
            let key = DateHelpers.startOfDay(s.endDate)
            let hours = s.endDate.timeIntervalSince(s.startDate) / 3600.0
            out[key, default: 0] += hours
        }
        return out
    }

    // MARK: - Cache

    /// Pull a history window into SwiftData so widgets can render from cache.
    /// Also updates the StreakSnapshot for fast widget reads.
    @discardableResult
    func refreshCache(days: Int = 400) async throws -> [ActivityDay] {
        let history = try await fetchHistory(days: days)
        try upsert(history)

        // Compute & persist snapshot for widgets — widgets only see tracked streaks.
        let settings = StreakSettings.shared
        let hourly = (try? await fetchHourlySteps(days: 90)) ?? [:]
        let all = StreakEngine.discover(
            history: history,
            hourlySteps: hourly,
            hiddenMetrics: settings.hiddenMetrics,
            vibe: settings.vibe,
            minStreakLength: settings.minStreakLength,
            now: .now
        )
        let tracked = StreakStore.applyTrackedFilter(all)
        let snapshot = StreakEngine.snapshot(from: tracked)
        SnapshotStore.save(snapshot)
        return history
    }

    private func upsert(_ days: [ActivityDay]) throws {
        let container = DataService.sharedModelContainer
        let context = container.mainContext
        for day in days {
            let key = DateHelpers.dayKey(day.date)
            let descriptor = FetchDescriptor<DailyActivity>(
                predicate: #Predicate { $0.dateString == key }
            )
            if let existing = try? context.fetch(descriptor).first {
                existing.steps = day.steps
                existing.exerciseMinutes = day.exerciseMinutes
                existing.standHours = day.standHours
                existing.activeEnergy = day.activeEnergy
                existing.workoutCount = day.workoutCount
                existing.mindfulMinutes = day.mindfulMinutes
                existing.sleepHours = day.sleepHours
                existing.distanceMiles = day.distanceMiles
                existing.flightsClimbed = day.flightsClimbed
                existing.lastUpdated = Date()
            } else {
                let record = DailyActivity(
                    date: day.date,
                    steps: day.steps,
                    exerciseMinutes: day.exerciseMinutes,
                    standHours: day.standHours,
                    activeEnergy: day.activeEnergy,
                    workoutCount: day.workoutCount,
                    mindfulMinutes: day.mindfulMinutes,
                    sleepHours: day.sleepHours,
                    distanceMiles: day.distanceMiles,
                    flightsClimbed: day.flightsClimbed
                )
                context.insert(record)
            }
        }
        try context.save()
    }

    /// Read cached history (used by widgets when they can't re-run the engine cheaply).
    func cachedHistory(days: Int = 400) -> [ActivityDay] {
        let context = DataService.sharedModelContainer.mainContext
        let start = DateHelpers.daysAgo(days - 1)
        let descriptor = FetchDescriptor<DailyActivity>(
            predicate: #Predicate { $0.date >= start },
            sortBy: [SortDescriptor(\.date)]
        )
        return ((try? context.fetch(descriptor)) ?? []).map { $0.asActivityDay() }
    }
}

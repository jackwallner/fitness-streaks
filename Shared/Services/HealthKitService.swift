import Foundation
import HealthKit
import SwiftData
import WidgetKit
import os
#if os(watchOS)
import WatchKit
#endif

private let log = Logger(subsystem: "com.jackwallner.streaks", category: "HealthKit")

enum HealthKitError: Error {
    case timeout
}

@MainActor
final class HealthKitService: ObservableObject {
    static let shared = HealthKitService()

    private let store = HKHealthStore()
    @Published var hasRequestedAuthorization: Bool = false

    /// Quantity types we query as statistics collections.
    private let quantityTypes: [HKQuantityTypeIdentifier] = [
        .stepCount,
        .appleExerciseTime,
        .activeEnergyBurned,
        .distanceWalkingRunning,
        .flightsClimbed,
        .heartRate,
    ]

    /// Category types (mindful session, sleep analysis, stand hour) + workout type.
    private var categoryReadTypes: Set<HKObjectType> {
        var set: Set<HKObjectType> = [HKObjectType.workoutType()]
        if let mindful = HKObjectType.categoryType(forIdentifier: .mindfulSession) {
            set.insert(mindful)
        }
        if let sleep = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) {
            set.insert(sleep)
        }
        if let standHour = HKObjectType.categoryType(forIdentifier: .appleStandHour) {
            set.insert(standHour)
        }
        return set
    }

    private var allReadTypes: Set<HKObjectType> {
        var types: Set<HKObjectType> = categoryReadTypes
        for id in quantityTypes {
            types.insert(HKQuantityType(id))
        }
        return types
    }

    private init() {
        Task {
            let status = await self.authorizationRequestStatus()
            if status == .unnecessary {
                self.hasRequestedAuthorization = true
            }
        }
    }

    // MARK: - Authorization

    func requestAuthorization() async throws {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        log.info("Requesting HealthKit authorization for \(self.allReadTypes.count) read types")

        // Wrap in timeout to prevent indefinite hangs (HealthKit can hang in edge cases)
        try await withTimeout(seconds: 10) {
            try await self.store.requestAuthorization(toShare: [], read: self.allReadTypes)
        }

        // Verify actual status - request completing doesn't mean user granted permission
        if let status = await authorizationRequestStatus() {
            hasRequestedAuthorization = (status == .unnecessary)
        } else {
            hasRequestedAuthorization = true // Assume we asked if status check fails
        }
    }

    private func withTimeout(seconds: TimeInterval, operation: @escaping () async throws -> Void) async throws {
        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask {
                try await operation()
            }
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                throw HealthKitError.timeout
            }
            try await group.next()!
            group.cancelAll()
        }
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
        hasRequestedAuthorization = (status == .unnecessary)
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
        async let standHours = standHourCounts(start: start, end: end)
        async let energy = quantityDaily(.activeEnergyBurned, unit: .kilocalorie(), start: start, end: end)
        async let distance = quantityDaily(.distanceWalkingRunning, unit: .mile(), start: start, end: end)
        async let flights = quantityDaily(.flightsClimbed, unit: .count(), start: start, end: end)
        async let workouts = workoutBreakdown(start: start, end: end)
        async let mindful = categoryMinutes(.mindfulSession, start: start, end: end)
        async let sleep = sleepHoursByDay(start: start, end: end)
        async let hr = heartRateMinutesAbove(thresholdBPM: 100, start: start, end: end)

        let (s, ex, sh, en, dist, fl, wo, mi, sl, hrm) = try await (steps, exercise, standHours, energy, distance, flights, workouts, mindful, sleep, hr)

        var results: [ActivityDay] = []
        var cursor = start
        while cursor < end {
            let key = cursor
            results.append(ActivityDay(
                date: cursor,
                steps: s[key] ?? 0,
                exerciseMinutes: ex[key] ?? 0,
                standHours: sh[key] ?? 0,
                activeEnergy: en[key] ?? 0,
                workoutCount: wo.totals[key] ?? 0,
                mindfulMinutes: mi[key] ?? 0,
                sleepHours: sl[key] ?? 0,
                distanceMiles: dist[key] ?? 0,
                flightsClimbed: fl[key] ?? 0,
                earlySteps: 0,
                heartRateMinutes: hrm[key] ?? 0,
                workoutDetails: wo.details[key] ?? [:]
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

    /// Returns total workout count per day plus a per-type breakdown (count, minutes, miles).
    private func workoutBreakdown(start: Date, end: Date) async throws -> (totals: [Date: Double], details: [Date: [String: WorkoutDailyStat]]) {
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

        var totals: [Date: Double] = [:]
        var details: [Date: [String: WorkoutDailyStat]] = [:]
        for workout in samples {
            let day = DateHelpers.startOfDay(workout.startDate)
            totals[day, default: 0] += 1

            guard let entry = WorkoutTypeCatalog.entry(forActivityRaw: workout.workoutActivityType.rawValue) else { continue }
            let minutes = workout.duration / 60.0
            let miles = workout.totalDistance?.doubleValue(for: .mile()) ?? 0

            var byType = details[day] ?? [:]
            var stat = byType[entry.key] ?? .zero
            stat.count += 1
            stat.minutes += minutes
            stat.miles += miles
            byType[entry.key] = stat
            details[day] = byType
        }
        return (totals, details)
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

    private func standHourCounts(start: Date, end: Date) async throws -> [Date: Double] {
        guard let type = HKObjectType.categoryType(forIdentifier: .appleStandHour) else { return [:] }
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

        var stoodHoursByDay: [Date: Set<Date>] = [:]
        for sample in samples where sample.value == HKCategoryValueAppleStandHour.stood.rawValue {
            let day = DateHelpers.startOfDay(sample.startDate)
            if let hour = DateHelpers.gregorian.dateInterval(of: .hour, for: sample.startDate)?.start {
                stoodHoursByDay[day, default: []].insert(hour)
            }
        }
        return stoodHoursByDay.mapValues { Double($0.count) }
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

        let intervals = samples
            .filter { asleepValues.contains($0.value) }
            .map { (start: $0.startDate, end: $0.endDate) }
        return Self.mergedHoursByDay(intervals: intervals, start: start, end: end)
    }

    nonisolated static func mergedHoursByDay(intervals: [(start: Date, end: Date)], start: Date, end: Date) -> [Date: Double] {
        var grouped: [Date: [(Date, Date)]] = [:]
        for interval in intervals {
            let clippedStart = max(interval.start, start)
            let clippedEnd = min(interval.end, end)
            guard clippedEnd > clippedStart else { continue }
            grouped[DateHelpers.startOfDay(clippedEnd), default: []].append((clippedStart, clippedEnd))
        }

        var out: [Date: Double] = [:]
        for (day, dayIntervals) in grouped {
            let sorted = dayIntervals.sorted { $0.0 < $1.0 }
            var merged: [(Date, Date)] = []
            for interval in sorted {
                guard let last = merged.last else {
                    merged.append(interval)
                    continue
                }
                if interval.0 <= last.1 {
                    merged[merged.count - 1] = (last.0, max(last.1, interval.1))
                } else {
                    merged.append(interval)
                }
            }
            out[day] = merged.reduce(0) { total, interval in
                total + interval.1.timeIntervalSince(interval.0) / 3600.0
            }
        }
        return out
    }

    // MARK: - Heart Rate

    /// Approximate minutes per day with heart rate above `thresholdBPM`.
    /// Counts time between consecutive elevated samples (capped at 30s) to avoid
    /// overcounting sparse background readings, then converts to minutes.
    private func heartRateMinutesAbove(thresholdBPM: Double, start: Date, end: Date) async throws -> [Date: Double] {
        let type = HKQuantityType(.heartRate)
        let unit = HKUnit.count().unitDivided(by: .minute())

        // Filter at the HealthKit level so we never load millions of low-BPM samples.
        let thresholdQuantity = HKQuantity(unit: unit, doubleValue: thresholdBPM)
        let quantityPredicate = HKQuery.predicateForQuantitySamples(with: .greaterThan, quantity: thresholdQuantity)
        let datePredicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [datePredicate, quantityPredicate])

        // Cap at 50,000 samples (~14 h of 1 Hz workout data) as a safety valve.
        let sampleLimit = 50_000

        let samples: [HKQuantitySample] = try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: type,
                predicate: predicate,
                limit: sampleLimit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
            ) { _, results, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: (results as? [HKQuantitySample]) ?? [])
                }
            }
            store.execute(query)
        }
        var byDay: [Date: [HKQuantitySample]] = [:]
        for sample in samples {
            let day = DateHelpers.startOfDay(sample.startDate)
            byDay[day, default: []].append(sample)
        }

        var out: [Date: Double] = [:]
        for (day, daySamples) in byDay {
            let elevated = daySamples.filter { $0.quantity.doubleValue(for: unit) > thresholdBPM }
            guard !elevated.isEmpty else { continue }

            var totalSeconds: Double = 0
            var previous: Date? = nil
            for sample in elevated {
                if let prev = previous {
                    let gap = sample.startDate.timeIntervalSince(prev)
                    totalSeconds += min(gap, 30)
                } else {
                    totalSeconds += 5 // first sample in a burst
                }
                previous = sample.startDate
            }
            out[day] = totalSeconds / 60.0
        }
        return out
    }

    // MARK: - Cache

    @discardableResult
    func refreshCache(days: Int = 400) async throws -> [ActivityDay] {
        let history = try await fetchHistory(days: days)
        try cache(history)
        return history
    }

    func cache(_ history: [ActivityDay]) throws {
        try upsert(history)
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
                existing.earlySteps = day.earlySteps
                existing.heartRateMinutes = day.heartRateMinutes
                existing.workoutDetails = day.workoutDetails
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
                    flightsClimbed: day.flightsClimbed,
                    earlySteps: day.earlySteps,
                    heartRateMinutes: day.heartRateMinutes,
                    workoutDetails: day.workoutDetails
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

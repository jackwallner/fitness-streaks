import Foundation

/// Mines a history of daily activity values for streaks the user may not realize they have.
///
/// Algorithm (per metric):
///   1. Slice history to the last `lookbackDays`.
///   2. Generate candidate thresholds from the actual values seen in that window.
///   3. For each candidate, compute the daily completion rate and current streak.
///   4. Pick the threshold whose completion rate is CLOSEST to vibe.targetCompletionRate.
///   5. Only surface the metric if the best completion rate is within ±10pp of target.
///   6. Rank all surviving streaks by `intensityScore`.
///   7. The top-scoring streak becomes the hero; the next N are badges.
///
/// "Current" counts today only if it already met the threshold.
/// This keeps the streak from being "broken" mid-day.
enum StreakEngine {
    /// Minimum current length to surface a streak. Anything shorter is treated as trivia.
    static let minDailyLength = 3
    /// Hard floor — we never surface streaks shorter than this even if nothing else qualifies.
    static let absoluteFloor = 2

    /// Minimum length for an hour-window streak to be surfaced. These mine tighter rhythms,
    /// so we demand a longer run to trust the pattern.
    static let minHourWindowLength = 5

    /// How close the best completion rate must be to the vibe target to surface a metric.
    /// ±10 percentage points — e.g. 50% target → 40–60% qualifies.
    static let completionTolerance = 0.10

    /// Step thresholds evaluated for each hour of the day.
    /// 250 is a reasonable "you were doing something" floor.
    static let hourlyStepThresholds: [Double] = [250, 500, 1000, 1500, 2000, 3000]

    static func discover(
        history: [ActivityDay],
        hourlySteps: [Date: [Int: Double]] = [:],
        hiddenMetrics: Set<StreakMetric> = [],
        intensity: DiscoveryIntensity = .challenging,
        lookbackDays: Int = 30,
        committedThresholds: [String: Double] = [:],
        customStreaks: [CustomStreak] = [],
        gracePreservations: [String: GracePreservation] = [:],
        plannedFreezes: Set<Date> = [],
        now: Date = .now
    ) -> [Streak] {
        guard !history.isEmpty else { return [] }

        let byDay: [Date: ActivityDay] = Dictionary(uniqueKeysWithValues: history.map { ($0.date, $0) })
        let today = DateHelpers.startOfDay(now)

        // Only consider the last N days when computing completion rates.
        let recentHistory = Array(history.suffix(max(1, lookbackDays)))

        var found: [Streak] = []

        for metric in StreakMetric.allCases where !hiddenMetrics.contains(metric) && metric != .earlySteps {
            if let best = discoverBestThreshold(
                metric: metric,
                history: history,
                recentHistory: recentHistory,
                byDay: byDay,
                today: today,
                target: intensity.targetCompletionRate,
                tolerance: completionTolerance,
                committedThresholds: committedThresholds,
                gracePreservations: gracePreservations,
                plannedFreezes: plannedFreezes,
                requestedLookback: lookbackDays
            ) {
                found.append(best)
            }
        }

        // Hour-window streaks removed — daily streaks only per user request.

        let custom = customStreaks
            .filter { !hiddenMetrics.contains($0.metric) }
            .map { custom in
                customStreak(
                    custom,
                    byDay: byDay,
                    hourlySteps: hourlySteps,
                    today: today,
                    lookbackDays: lookbackDays,
                    gracePreservations: gracePreservations,
                    plannedFreezes: plannedFreezes
                )
            }
        found.append(contentsOf: custom)

        return found.sorted { intensityScore($0, intensity: intensity) > intensityScore($1, intensity: intensity) }
    }

    static func snapshot(from streaks: [Streak]) -> StreakSnapshot {
        let hero = streaks.first.map(item(from:))
        let badges = streaks.dropFirst().prefix(8).map(item(from:))
        return StreakSnapshot(updated: .now, hero: hero, badges: Array(badges))
    }

    static func item(from streak: Streak) -> StreakSnapshot.Item {
        StreakSnapshot.Item(
            metric: streak.metric.rawValue,
            cadence: streak.cadence.rawValue,
            threshold: streak.threshold,
            current: streak.current,
            best: streak.best,
            currentUnitCompleted: streak.currentUnitCompleted,
            currentUnitProgress: streak.currentUnitProgress,
            currentUnitValue: streak.currentUnitValue,
            hourWindow: streak.window?.startHour,
            customID: streak.customID,
            workoutType: streak.workoutType,
            workoutMeasure: streak.workoutMeasure?.rawValue
        )
    }

    private static func roundThreshold(_ value: Double, for metric: StreakMetric) -> Double {
        switch metric {
        case .steps:
            return (value / 100).rounded(.down) * 100
        case .activeEnergy:
            return (value / 10).rounded(.down) * 10
        case .distanceMiles:
            return (value * 10).rounded(.down) / 10
        default:
            return value.rounded(.down)
        }
    }

    // MARK: - Smart threshold discovery

    /// For a given metric, test every unique value seen in the lookback window as a threshold,
    /// and return the streak whose completion rate is closest to `target`.
    /// Only returns a streak if the best completion rate is within `tolerance` of target.
    private static func discoverBestThreshold(
        metric: StreakMetric,
        history: [ActivityDay],
        recentHistory: [ActivityDay],
        byDay: [Date: ActivityDay],
        today: Date,
        target: Double,
        tolerance: Double,
        committedThresholds: [String: Double],
        gracePreservations: [String: GracePreservation],
        plannedFreezes: Set<Date>,
        requestedLookback: Int
    ) -> Streak? {
        let key = StreakSettings.streakKey(metric: metric, cadence: .daily)
        if let committed = committedThresholds[key] {
            let rate = completionRate(metric: metric, threshold: committed, recentHistory: recentHistory)
            return applyingGrace(
                to: computeDailyStreak(metric: metric, threshold: committed, byDay: byDay, today: today, plannedFreezes: plannedFreezes),
                key: key,
                today: today,
                gracePreservations: gracePreservations,
                completionRate: rate,
                lookbackDays: requestedLookback
            )
        }

        let values = recentHistory.map { $0.value(for: metric) }
        guard !values.isEmpty else { return nil }

        // Discrete metrics (workouts, mindful) don't have meaningful unique continuous values;
        // fall back to the fixed tier list.
        let candidates: [Double]
        switch metric {
        case .workouts, .mindfulMinutes:
            candidates = metric.dailyThresholds
        case .steps:
            // Round each unique value to nearest 100 first, then deduplicate
            let rounded = Set(values.map { (($0 / 100).rounded(.down) * 100) })
            candidates = Array(rounded).filter { $0 > 0 }.sorted()
        default:
            // Use every unique non-zero value in the lookback window as a candidate threshold.
            // Threshold of 0 causes computeDailyStreak's `while true` loop to never terminate
            // (cursor walks into the past indefinitely because byDay[cursor] ?? 0 >= 0 is always true).
            candidates = Array(Set(values).filter { $0 > 0 }).sorted()
        }

        let windowDays = Double(values.count)
        var best: (streak: Streak, rate: Double, distance: Double)? = nil

        for threshold in candidates {
            let hitDays = values.filter { $0 >= threshold }.count
            let rate = Double(hitDays) / windowDays
            let distance = abs(rate - target)

            // Compute streak using FULL history (not just lookback) so current streak is accurate.
            let streak = applyingGrace(
                to: computeDailyStreak(metric: metric, threshold: threshold, byDay: byDay, today: today, plannedFreezes: plannedFreezes),
                key: key,
                today: today,
                gracePreservations: gracePreservations,
                completionRate: rate,
                lookbackDays: requestedLookback
            )

            // Surface only streaks with a meaningful current run.
            guard streak.current >= minDailyLength || streak.current >= absoluteFloor else { continue }

            if let current = best {
                if distance < current.distance {
                    best = (streak, rate, distance)
                }
            } else {
                best = (streak, rate, distance)
            }
        }

        if let result = best, result.distance <= tolerance {
            return result.streak
        }

        // Fallback: calibrated discovery found nothing within tolerance, but the user
        // may still be sustaining a low/easy goal every day. Walk the fixed tier list
        // descending and surface the highest tier with a meaningful active run, so
        // every tracked metric gets *some* streak when the user has data.
        //
        // Gate on coverage: if fewer than 30% of lookback days have a non-zero value,
        // the metric isn't really being tracked — skip rather than fabricating a goal.
        let nonZeroDays = values.filter { $0 > 0 }.count
        let coverage = Double(nonZeroDays) / windowDays
        guard coverage >= 0.3 else { return nil }

        for threshold in metric.dailyThresholds.sorted(by: >) {
            let rate = completionRate(metric: metric, threshold: threshold, recentHistory: recentHistory)
            let streak = applyingGrace(
                to: computeDailyStreak(metric: metric, threshold: threshold, byDay: byDay, today: today, plannedFreezes: plannedFreezes),
                key: key,
                today: today,
                gracePreservations: gracePreservations,
                completionRate: rate,
                lookbackDays: requestedLookback
            )
            if streak.current >= minDailyLength {
                return streak
            }
        }

        return nil
    }

    /// Score tuned per intensity — drives which streak becomes hero and badge ordering.
    /// Since smart discovery already targets the intensity's completion rate, the score
    /// mainly differentiates by streak length and metric weight, with a small
    /// bonus for lower completion rates (harder thresholds).
    static func intensityScore(_ s: Streak, intensity: DiscoveryIntensity) -> Double {
        let len = Double(s.current)
        let weight = s.metric.weight
        let difficulty = 1.0 + (1.0 - s.completionRate) * 0.5

        let thresholdBonus: Double
        if s.window != nil {
            if let idx = hourlyStepThresholds.firstIndex(where: { $0 >= s.threshold }) {
                thresholdBonus = 1.0 + Double(idx) * 0.15
            } else {
                thresholdBonus = 1.0 + Double(hourlyStepThresholds.count) * 0.15
            }
        } else {
            thresholdBonus = 1.0
        }

        return len * weight * difficulty * thresholdBonus
    }

    // MARK: - Hour-window miner

    /// For each hour 0..<24, build a per-day series of "steps in that hour", evaluate
    /// streaks across our tiered hourly thresholds, and return up to 3 non-adjacent
    /// hours ranked by vibe score.
    ///
    /// This is the "Streak Finder" magic — surface surprising rhythms like
    /// "you always get 1000+ steps between 5–6pm".
    static func discoverHourWindows(
        hourlySteps: [Date: [Int: Double]],
        today: Date,
        intensity: DiscoveryIntensity,
        committedThresholds: [String: Double] = [:],
        gracePreservations: [String: GracePreservation] = [:]
    ) -> [Streak] {
        var perHourBest: [(Int, Streak)] = []
        let target = intensity.targetCompletionRate

        for hour in 0..<24 {
            let window = HourWindow(startHour: hour)
            let key = StreakSettings.streakKey(metric: .steps, cadence: .daily, window: window)
            // Build a day→value map for just this hour.
            var byDay: [Date: Double] = [:]
            for (day, hours) in hourlySteps {
                byDay[day] = hours[hour] ?? 0
            }

            let values = Array(byDay.values)
            guard !values.isEmpty else { continue }
            let windowDays = Double(values.count)

            if let committed = committedThresholds[key] {
                let hitDays = values.filter { $0 >= committed }.count
                let rate = Double(hitDays) / windowDays
                let base = computeDailyStreakFromValues(
                    metric: .steps,
                    threshold: committed,
                    byDayValues: byDay,
                    today: today
                )
                let streak = applyingGrace(
                    to: Streak(
                        metric: .steps,
                        cadence: .daily,
                        threshold: committed,
                        window: window,
                        current: base.current,
                        best: base.best,
                        startDate: base.startDate,
                        lastHitDate: base.lastHitDate,
                        lastMissedDate: base.lastMissedDate,
                        currentUnitCompleted: base.currentUnitCompleted,
                        currentUnitProgress: base.currentUnitProgress,
                        currentUnitValue: base.currentUnitValue,
                        completionRate: rate,
                        lookbackDays: values.count
                    ),
                    key: key,
                    today: today,
                    gracePreservations: gracePreservations,
                    completionRate: rate,
                    lookbackDays: values.count
                )
                perHourBest.append((hour, streak))
                continue
            }

            // Evaluate every threshold tier for this hour.
            var best: (streak: Streak, rate: Double, distance: Double)? = nil
            for threshold in hourlyStepThresholds {
                let hitDays = values.filter { $0 >= threshold }.count
                let rate = Double(hitDays) / windowDays
                let distance = abs(rate - target)

                let computed = computeDailyStreakFromValues(
                    metric: .steps,
                    threshold: threshold,
                    byDayValues: byDay,
                    today: today
                )
                let base = applyingGrace(
                    to: computed,
                    key: key,
                    today: today,
                    gracePreservations: gracePreservations,
                    completionRate: rate,
                    lookbackDays: values.count
                )

                guard base.current >= minHourWindowLength || base.current >= absoluteFloor else { continue }

                if let current = best {
                    if distance < current.distance {
                        best = (base, rate, distance)
                    }
                } else {
                    best = (base, rate, distance)
                }
            }

            guard let result = best, result.distance <= completionTolerance else { continue }

            let streak = Streak(
                metric: .steps,
                cadence: .daily,
                threshold: result.streak.threshold,
                window: window,
                current: result.streak.current,
                best: result.streak.best,
                startDate: result.streak.startDate,
                lastHitDate: result.streak.lastHitDate,
                lastMissedDate: result.streak.lastMissedDate,
                currentUnitCompleted: result.streak.currentUnitCompleted,
                currentUnitProgress: result.streak.currentUnitProgress,
                currentUnitValue: result.streak.currentUnitValue,
                completionRate: result.rate,
                lookbackDays: values.count
            )
            perHourBest.append((hour, streak))
        }

        // Sort hours by intensity score, then pick up to 3 non-adjacent hours so we don't
        // show "4–5pm" and "5–6pm" both (same walk, different slicing).
        let ranked = perHourBest.sorted { intensityScore($0.1, intensity: intensity) > intensityScore($1.1, intensity: intensity) }

        var picked: [(Int, Streak)] = []
        for candidate in ranked {
            let tooClose = picked.contains { circularHourDistance($0.0, candidate.0) <= 1 }
            if !tooClose { picked.append(candidate) }
            if picked.count >= 3 { break }
        }

        return picked.map(\.1)
    }

    static func circularHourDistance(_ a: Int, _ b: Int) -> Int {
        let distance = abs(a - b)
        return min(distance, 24 - distance)
    }

    /// Shared streak computation that takes a raw day→value map instead of ActivityDay.
    /// Used by both the all-day path and the hour-window miner.
    static func computeDailyStreakFromValues(
        metric: StreakMetric,
        threshold: Double,
        byDayValues: [Date: Double],
        today: Date,
        plannedFreezes: Set<Date> = []
    ) -> Streak {
        guard threshold > 0 else {
            return Streak(metric: metric, cadence: .daily, threshold: threshold,
                          current: 0, best: 0, startDate: nil, lastHitDate: nil,
                          currentUnitCompleted: false, currentUnitProgress: 0, currentUnitValue: 0)
        }
        let todayValue = byDayValues[today] ?? 0
        let todayIsFreeze = plannedFreezes.contains(today)
        let todayMet = todayValue >= threshold

        var currentLen = 0
        var streakStart: Date? = nil
        // A freeze day on `today` doesn't add to length but doesn't break either —
        // we still walk back to count the run that's being preserved.
        if todayMet {
            currentLen = 1
            streakStart = today
        }

        var cursor = DateHelpers.addDays(-1, to: today)
        while true {
            if plannedFreezes.contains(cursor) {
                // Pass-through: freeze days bridge the streak without incrementing length.
                streakStart = cursor
                cursor = DateHelpers.addDays(-1, to: cursor)
                continue
            }
            let value = byDayValues[cursor] ?? 0
            if value >= threshold {
                currentLen += 1
                streakStart = cursor
                cursor = DateHelpers.addDays(-1, to: cursor)
            } else {
                break
            }
        }

        let sortedDays = byDayValues.keys.sorted()
        var best = 0
        var run = 0
        for d in sortedDays {
            if plannedFreezes.contains(d) {
                continue
            }
            if (byDayValues[d] ?? 0) >= threshold {
                run += 1
                best = max(best, run)
            } else {
                run = 0
            }
        }
        best = max(best, currentLen)

        var lastHit: Date? = nil
        var back = today
        for _ in 0..<800 {
            if (byDayValues[back] ?? 0) >= threshold {
                lastHit = back
                break
            }
            back = DateHelpers.addDays(-1, to: back)
        }

        // Find the most recent day before the streak started that did NOT meet the threshold
        var lastMissed: Date? = nil
        if let start = streakStart {
            var missedCursor = DateHelpers.addDays(-1, to: start)
            for _ in 0..<800 {
                if plannedFreezes.contains(missedCursor) {
                    missedCursor = DateHelpers.addDays(-1, to: missedCursor)
                    continue
                }
                let value = byDayValues[missedCursor] ?? 0
                if value < threshold {
                    lastMissed = missedCursor
                    break
                }
                missedCursor = DateHelpers.addDays(-1, to: missedCursor)
            }
        }

        let progress = threshold > 0 ? min(todayValue / threshold, 10) : 0
        return Streak(
            metric: metric,
            cadence: .daily,
            threshold: threshold,
            current: currentLen,
            best: best,
            startDate: streakStart,
            lastHitDate: lastHit,
            lastMissedDate: lastMissed,
            currentUnitCompleted: todayMet || todayIsFreeze,
            currentUnitProgress: todayIsFreeze ? 1 : progress,
            currentUnitValue: todayValue
        )
    }

    // MARK: - Daily streak

    static func computeDailyStreak(
        metric: StreakMetric,
        threshold: Double,
        byDay: [Date: ActivityDay],
        today: Date,
        plannedFreezes: Set<Date> = []
    ) -> Streak {
        let values = Dictionary(uniqueKeysWithValues: byDay.map { ($0.key, $0.value.value(for: metric)) })
        return computeDailyStreakFromValues(
            metric: metric,
            threshold: threshold,
            byDayValues: values,
            today: today,
            plannedFreezes: plannedFreezes
        )
    }

    static func completionRate(metric: StreakMetric, threshold: Double, recentHistory: [ActivityDay]) -> Double {
        guard !recentHistory.isEmpty else { return 0 }
        let hitDays = recentHistory.filter { $0.value(for: metric) >= threshold }.count
        return Double(hitDays) / Double(recentHistory.count)
    }

    private static func applyingGrace(
        to streak: Streak,
        key: String,
        today: Date,
        gracePreservations: [String: GracePreservation],
        completionRate: Double,
        lookbackDays: Int
    ) -> Streak {
        guard let preservation = gracePreservations[key] else {
            return Streak(
                customID: streak.customID,
                metric: streak.metric,
                cadence: streak.cadence,
                threshold: streak.threshold,
                window: streak.window,
                workoutType: streak.workoutType,
                workoutMeasure: streak.workoutMeasure,
                current: streak.current,
                best: streak.best,
                startDate: streak.startDate,
                lastHitDate: streak.lastHitDate,
                lastMissedDate: streak.lastMissedDate,
                currentUnitCompleted: streak.currentUnitCompleted,
                currentUnitProgress: streak.currentUnitProgress,
                currentUnitValue: streak.currentUnitValue,
                completionRate: completionRate,
                lookbackDays: lookbackDays
            )
        }

        let missed = DateHelpers.startOfDay(preservation.missedDate)
        let daysAfterMiss = max(0, DateHelpers.gregorian.dateComponents([.day], from: missed, to: today).day ?? 0)
        let canBridge = daysAfterMiss == 1
        let bridgedCurrent = canBridge ? max(streak.current, preservation.preservedLength + streak.current) : streak.current
        let bridgedStart = canBridge ? DateHelpers.addDays(-(bridgedCurrent - 1), to: today) : streak.startDate

        return Streak(
            customID: streak.customID,
            metric: streak.metric,
            cadence: streak.cadence,
            threshold: streak.threshold,
            window: streak.window,
            workoutType: streak.workoutType,
            workoutMeasure: streak.workoutMeasure,
            current: bridgedCurrent,
            best: max(streak.best, bridgedCurrent),
            startDate: bridgedStart,
            lastHitDate: streak.lastHitDate,
            lastMissedDate: streak.lastMissedDate,
            currentUnitCompleted: streak.currentUnitCompleted,
            currentUnitProgress: streak.currentUnitProgress,
            currentUnitValue: streak.currentUnitValue,
            completionRate: completionRate,
            lookbackDays: lookbackDays
        )
    }

    private static func customStreak(
        _ custom: CustomStreak,
        byDay: [Date: ActivityDay],
        hourlySteps: [Date: [Int: Double]],
        today: Date,
        lookbackDays: Int,
        gracePreservations: [String: GracePreservation],
        plannedFreezes: Set<Date> = []
    ) -> Streak {
        let key = custom.trackingKey
        let base: Streak
        let rate: Double

        if let workoutTypeKey = custom.workoutType, custom.metric == .workouts {
            let measure = custom.workoutMeasure ?? .count
            var values: [Date: Double] = [:]
            for (day, activity) in byDay {
                let stat = activity.workoutDetails[workoutTypeKey] ?? .zero
                values[day] = stat.value(for: measure)
            }
            base = computeDailyStreakFromValues(
                metric: custom.metric,
                threshold: custom.threshold,
                byDayValues: values,
                today: today,
                plannedFreezes: plannedFreezes
            )
            let recent = Array(values.keys.sorted().suffix(max(1, lookbackDays)))
            let recentVals = recent.compactMap { values[$0] }
            rate = recentVals.isEmpty ? 0 : Double(recentVals.filter { $0 >= custom.threshold }.count) / Double(recentVals.count)
        } else if let hour = custom.hourWindow {
            var values: [Date: Double] = [:]
            for (day, hours) in hourlySteps {
                values[day] = hours[hour] ?? 0
            }
            base = computeDailyStreakFromValues(
                metric: custom.metric,
                threshold: custom.threshold,
                byDayValues: values,
                today: today,
                plannedFreezes: plannedFreezes
            )
            rate = values.isEmpty ? 0 : Double(values.values.filter { $0 >= custom.threshold }.count) / Double(values.count)
        } else {
            base = computeDailyStreak(
                metric: custom.metric,
                threshold: custom.threshold,
                byDay: byDay,
                today: today,
                plannedFreezes: plannedFreezes
            )
            let recent = Array(byDay.values.sorted { $0.date < $1.date }.suffix(max(1, lookbackDays)))
            rate = completionRate(metric: custom.metric, threshold: custom.threshold, recentHistory: recent)
        }

        let window = custom.hourWindow.map(HourWindow.init(startHour:))
        let customBase = Streak(
            customID: custom.id,
            metric: custom.metric,
            cadence: custom.cadence,
            threshold: custom.threshold,
            window: window,
            workoutType: custom.workoutType,
            workoutMeasure: custom.workoutMeasure,
            current: base.current,
            best: base.best,
            startDate: base.startDate,
            lastHitDate: base.lastHitDate,
            lastMissedDate: base.lastMissedDate,
            currentUnitCompleted: base.currentUnitCompleted,
            currentUnitProgress: base.currentUnitProgress,
            currentUnitValue: base.currentUnitValue
        )

        return applyingGrace(
            to: customBase,
            key: key,
            today: today,
            gracePreservations: gracePreservations,
            completionRate: rate,
            lookbackDays: lookbackDays
        )
    }

    // MARK: - Detail helpers

    /// For the detail screen: per-day value + whether it met the threshold.
    static func dailyHistory(
        for streak: Streak,
        history: [ActivityDay]
    ) -> [(date: Date, value: Double, met: Bool)] {
        if streak.metric == .workouts,
           let workoutType = streak.workoutType,
           let measure = streak.workoutMeasure {
            return history.map { day in
                let v = day.workoutDetails[workoutType]?.value(for: measure) ?? 0
                return (date: day.date, value: v, met: v >= streak.threshold)
            }
        }

        return dailyHistory(for: streak.metric, threshold: streak.threshold, history: history)
    }

    /// For the detail screen: per-day value + whether it met the threshold.
    static func dailyHistory(
        for metric: StreakMetric,
        threshold: Double,
        history: [ActivityDay]
    ) -> [(date: Date, value: Double, met: Bool)] {
        history.map { day in
            let v = day.value(for: metric)
            return (date: day.date, value: v, met: v >= threshold)
        }
    }

}

import Foundation

/// Mines a history of daily activity values for streaks the user may not realize they have.
///
/// Algorithm (per metric):
///   1. Slice history to the last `lookbackDays`.
///   2. Generate candidate thresholds from the actual values seen in that window.
///   3. For each candidate, compute the daily completion rate and current streak.
///   4. Pick the threshold whose completion rate is CLOSEST to vibe.targetCompletionRate.
///   5. Only surface the metric if the best completion rate is within ±10pp of target.
///   6. Rank all surviving streaks by `Streak.score`.
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
        vibe: DiscoveryVibe = .challenging,
        lookbackDays: Int = 30,
        now: Date = .now
    ) -> [Streak] {
        guard !history.isEmpty else { return [] }

        let byDay: [Date: ActivityDay] = Dictionary(uniqueKeysWithValues: history.map { ($0.date, $0) })
        let today = DateHelpers.startOfDay(now)

        // Only consider the last N days when computing completion rates.
        let recentHistory = Array(history.suffix(max(1, lookbackDays)))

        var found: [Streak] = []

        for metric in StreakMetric.allCases where !hiddenMetrics.contains(metric) {
            if let best = discoverBestThreshold(
                metric: metric,
                history: history,
                recentHistory: recentHistory,
                byDay: byDay,
                today: today,
                target: vibe.targetCompletionRate,
                tolerance: completionTolerance
            ) {
                found.append(best)
            }
        }

        // Hour-window streaks: mine hidden time-of-day rhythms in the user's step data.
        if !hourlySteps.isEmpty && !hiddenMetrics.contains(.steps) {
            let windowStreaks = discoverHourWindows(
                hourlySteps: hourlySteps,
                today: today,
                vibe: vibe
            )
            found.append(contentsOf: windowStreaks)
        }

        return found.sorted { vibeScore($0, vibe: vibe) > vibeScore($1, vibe: vibe) }
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
            hourWindow: streak.window?.startHour
        )
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
        tolerance: Double
    ) -> Streak? {
        let values = recentHistory.map { $0.value(for: metric) }
        guard !values.isEmpty else { return nil }

        // Discrete metrics (workouts, mindful) don't have meaningful unique continuous values;
        // fall back to the fixed tier list.
        let candidates: [Double]
        switch metric {
        case .workouts, .mindfulMinutes:
            candidates = metric.dailyThresholds
        default:
            // Use every unique value in the lookback window as a candidate threshold.
            candidates = Array(Set(values)).sorted()
        }

        let windowDays = Double(values.count)
        var best: (streak: Streak, rate: Double, distance: Double)? = nil

        for threshold in candidates {
            let hitDays = values.filter { $0 >= threshold }.count
            let rate = Double(hitDays) / windowDays
            let distance = abs(rate - target)

            // Compute streak using FULL history (not just lookback) so current streak is accurate.
            let streak = computeDailyStreak(metric: metric, threshold: threshold, byDay: byDay, today: today)

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

        guard let result = best, result.distance <= tolerance else { return nil }

        // Rebuild the Streak with the discovered completion rate attached.
        return Streak(
            metric: result.streak.metric,
            cadence: result.streak.cadence,
            threshold: result.streak.threshold,
            window: result.streak.window,
            current: result.streak.current,
            best: result.streak.best,
            startDate: result.streak.startDate,
            lastHitDate: result.streak.lastHitDate,
            currentUnitCompleted: result.streak.currentUnitCompleted,
            currentUnitProgress: result.streak.currentUnitProgress,
            currentUnitValue: result.streak.currentUnitValue,
            completionRate: result.rate,
            lookbackDays: values.count
        )
    }

    /// Score tuned per vibe — drives which streak becomes hero and badge ordering.
    /// Since smart discovery already targets the vibe's completion rate, the score
    /// mainly differentiates by streak length and metric weight, with a small
    /// bonus for lower completion rates (harder thresholds).
    static func vibeScore(_ s: Streak, vibe: DiscoveryVibe) -> Double {
        let len = Double(s.current)
        let weight = s.metric.weight
        let difficulty = 1.0 + (1.0 - s.completionRate) * 0.5
        return len * weight * difficulty
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
        vibe: DiscoveryVibe
    ) -> [Streak] {
        var perHourBest: [(Int, Streak)] = []
        let target = vibe.targetCompletionRate

        for hour in 0..<24 {
            // Build a day→value map for just this hour.
            var byDay: [Date: Double] = [:]
            for (day, hours) in hourlySteps {
                byDay[day] = hours[hour] ?? 0
            }

            let values = Array(byDay.values)
            guard !values.isEmpty else { continue }
            let windowDays = Double(values.count)

            // Evaluate every threshold tier for this hour.
            var best: (streak: Streak, rate: Double, distance: Double)? = nil
            for threshold in hourlyStepThresholds {
                let hitDays = values.filter { $0 >= threshold }.count
                let rate = Double(hitDays) / windowDays
                let distance = abs(rate - target)

                let base = computeDailyStreakFromValues(
                    metric: .steps,
                    threshold: threshold,
                    byDayValues: byDay,
                    today: today
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
                window: HourWindow(startHour: hour),
                current: result.streak.current,
                best: result.streak.best,
                startDate: result.streak.startDate,
                lastHitDate: result.streak.lastHitDate,
                currentUnitCompleted: result.streak.currentUnitCompleted,
                currentUnitProgress: result.streak.currentUnitProgress,
                currentUnitValue: result.streak.currentUnitValue,
                completionRate: result.rate,
                lookbackDays: values.count
            )
            perHourBest.append((hour, streak))
        }

        // Sort hours by vibe score, then pick up to 3 non-adjacent hours so we don't
        // show "4–5pm" and "5–6pm" both (same walk, different slicing).
        let ranked = perHourBest.sorted { vibeScore($0.1, vibe: vibe) > vibeScore($1.1, vibe: vibe) }

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
        today: Date
    ) -> Streak {
        let todayValue = byDayValues[today] ?? 0
        let todayMet = todayValue >= threshold

        var currentLen = 0
        var streakStart: Date? = nil
        if todayMet {
            currentLen = 1
            streakStart = today
        }

        var cursor = DateHelpers.addDays(-1, to: today)
        while true {
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

        let progress = threshold > 0 ? min(todayValue / threshold, 10) : 0
        return Streak(
            metric: metric,
            cadence: .daily,
            threshold: threshold,
            current: currentLen,
            best: best,
            startDate: streakStart,
            lastHitDate: lastHit,
            currentUnitCompleted: todayMet,
            currentUnitProgress: progress,
            currentUnitValue: todayValue
        )
    }

    // MARK: - Daily streak

    static func computeDailyStreak(
        metric: StreakMetric,
        threshold: Double,
        byDay: [Date: ActivityDay],
        today: Date
    ) -> Streak {
        // Current streak: walk backward from today. The current day only counts if it's met.
        let todayValue = byDay[today]?.value(for: metric) ?? 0
        let todayMet = todayValue >= threshold

        var currentLen = 0
        var streakStartDate: Date? = nil

        if todayMet {
            currentLen = 1
            streakStartDate = today
        }

        var cursor = DateHelpers.addDays(-1, to: today)
        while true {
            let value = byDay[cursor]?.value(for: metric) ?? 0
            if value >= threshold {
                currentLen += 1
                streakStartDate = cursor
                cursor = DateHelpers.addDays(-1, to: cursor)
            } else {
                break
            }
        }

        // Best streak: scan full history in order.
        let sortedDays = byDay.keys.sorted()
        var best = 0
        var run = 0
        for d in sortedDays {
            let value = byDay[d]?.value(for: metric) ?? 0
            if value >= threshold {
                run += 1
                best = max(best, run)
            } else {
                run = 0
            }
        }
        best = max(best, currentLen)

        // Most recent day that met the threshold
        var lastHit: Date? = nil
        var back = today
        for _ in 0..<800 {
            if (byDay[back]?.value(for: metric) ?? 0) >= threshold {
                lastHit = back
                break
            }
            back = DateHelpers.addDays(-1, to: back)
        }

        let progress = threshold > 0 ? min(todayValue / threshold, 10) : 0
        return Streak(
            metric: metric,
            cadence: .daily,
            threshold: threshold,
            current: currentLen,
            best: best,
            startDate: streakStartDate,
            lastHitDate: lastHit,
            currentUnitCompleted: todayMet,
            currentUnitProgress: progress,
            currentUnitValue: todayValue
        )
    }

    // MARK: - Detail helpers

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

import Foundation

/// Mines a history of daily activity values for streaks the user may not realize they have.
///
/// Algorithm (per metric):
///   1. Compute daily streaks at every threshold in `metric.dailyThresholds`.
///   2. Compute the historical daily completion rate for each threshold.
///   3. Pick the HIGHEST-threshold streak where completion rate >= vibe.targetCompletionRate
///      and `current >= minLength`. Fallbacks ensure we never return empty.
///   4. Rank all surviving streaks by `Streak.score`.
///   5. The top-scoring streak becomes the hero; the next N are badges.
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

    /// Step thresholds evaluated for each hour of the day.
    /// 250 is a reasonable "you were doing something" floor.
    static let hourlyStepThresholds: [Double] = [250, 500, 1000, 1500, 2000, 3000]

    static func discover(
        history: [ActivityDay],
        hourlySteps: [Date: [Int: Double]] = [:],
        hiddenMetrics: Set<StreakMetric> = [],
        vibe: DiscoveryVibe = .challenging,
        minStreakLength: Int? = nil,
        now: Date = .now
    ) -> [Streak] {
        guard !history.isEmpty else { return [] }

        let byDay: [Date: ActivityDay] = Dictionary(uniqueKeysWithValues: history.map { ($0.date, $0) })
        let today = DateHelpers.startOfDay(now)
        let totalDays = max(1, Double(history.count))

        var found: [Streak] = []

        for metric in StreakMetric.allCases where !hiddenMetrics.contains(metric) {
            let thresholds = metric.dailyThresholds
            let candidates = thresholds.map { t -> (streak: Streak, completionRate: Double) in
                let streak = computeDailyStreak(metric: metric, threshold: t, byDay: byDay, today: today)
                let hitDays = history.filter { $0.value(for: metric) >= t }.count
                let completionRate = Double(hitDays) / totalDays
                return (streak, completionRate)
            }
            if let best = pickByVibe(candidates: candidates, vibe: vibe, minLength: minDailyLength) {
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

        // User-requested "I've done it at least N times" floor
        let filtered: [Streak]
        if let floor = minStreakLength, floor > 0 {
            let meeting = found.filter { $0.current >= floor }
            filtered = meeting.isEmpty ? found : meeting
        } else {
            filtered = found
        }

        return filtered.sorted { vibeScore($0, vibe: vibe) > vibeScore($1, vibe: vibe) }
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

    // MARK: - Selection

    /// Choose the best threshold for a given vibe based on historical completion rate.
    /// `candidates` is one (Streak, completionRate) per threshold, ascending.
    private static func pickByVibe(candidates: [(streak: Streak, completionRate: Double)], vibe: DiscoveryVibe, minLength: Int) -> Streak? {
        guard !candidates.isEmpty else { return nil }
        let target = vibe.targetCompletionRate

        // Primary: highest threshold that meets target completion rate AND has current streak >= minLength.
        let qualifying = candidates.filter { $0.completionRate >= target && $0.streak.current >= minLength }
        if let best = qualifying.last {
            return best.streak
        }

        // Fallback: highest threshold that meets target completion rate (even if streak is short).
        let rateQualifying = candidates.filter { $0.completionRate >= target }
        if let best = rateQualifying.last {
            return best.streak
        }

        // Fallback: highest threshold with ANY streak >= absoluteFloor.
        let anyStreak = candidates.filter { $0.streak.current >= absoluteFloor }
        if let best = anyStreak.last {
            return best.streak
        }

        // Last resort: highest completion rate overall.
        return candidates.max(by: { $0.completionRate < $1.completionRate })?.streak
    }

    /// Score tuned per vibe — drives which streak becomes hero and badge ordering.
    static func vibeScore(_ s: Streak, vibe: DiscoveryVibe) -> Double {
        let thresholds = s.window == nil ? s.metric.dailyThresholds : hourlyStepThresholds
        let tierIdx = thresholds.firstIndex(of: s.threshold) ?? 0
        let tierCount = max(1, thresholds.count)
        let tierFrac = Double(tierIdx) / Double(tierCount - 1 == 0 ? 1 : tierCount - 1)
        let len = Double(s.current)
        let weight = s.metric.weight

        switch vibe {
        case .sustainable:
            // Strongly reward length; mild tier bonus.
            return len * (1.0 + 0.1 * Double(tierIdx)) * weight
        case .challenging:
            // Reward both length and tier; penalize extremes.
            let balance = 1.0 - abs(tierFrac - 0.6) * 0.5
            return len * (0.8 + 0.7 * Double(tierIdx)) * balance * weight
        case .lifeChanging:
            // Strongly reward tier; length still matters but less.
            return (0.5 + len * 0.3) * (1.0 + 0.35 * Double(tierIdx)) * weight
        }
    }

    /// Convenience overload for callers that don't compute completion rates (e.g. hour windows).
    private static func pickByVibe(candidates: [Streak], vibe: DiscoveryVibe, minLength: Int) -> Streak? {
        let wrapped = candidates.map { (streak: $0, completionRate: 1.0) }
        return pickByVibe(candidates: wrapped, vibe: vibe, minLength: minLength)
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

        for hour in 0..<24 {
            // Build a day→value map for just this hour.
            var byDay: [Date: Double] = [:]
            for (day, hours) in hourlySteps {
                byDay[day] = hours[hour] ?? 0
            }

            // Evaluate every threshold tier for this hour.
            let candidates = hourlyStepThresholds.map { threshold -> Streak in
                let base = computeDailyStreakFromValues(
                    metric: .steps,
                    threshold: threshold,
                    byDayValues: byDay,
                    today: today
                )
                return Streak(
                    metric: .steps,
                    cadence: .daily,
                    threshold: threshold,
                    window: HourWindow(startHour: hour),
                    current: base.current,
                    best: base.best,
                    startDate: base.startDate,
                    lastHitDate: base.lastHitDate,
                    currentUnitCompleted: base.currentUnitCompleted,
                    currentUnitProgress: base.currentUnitProgress,
                    currentUnitValue: base.currentUnitValue
                )
            }

            if let best = pickByVibe(candidates: candidates, vibe: vibe, minLength: minHourWindowLength) {
                perHourBest.append((hour, best))
            }
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

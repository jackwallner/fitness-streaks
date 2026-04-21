import Foundation

/// Mines a history of daily activity values for streaks the user may not realize they have.
///
/// Algorithm (per metric):
///   1. Compute daily streaks at every threshold in `metric.dailyThresholds`.
///   2. Compute weekly streaks at every threshold in `metric.weeklyThresholds`.
///   3. Pick the HIGHEST-threshold streak per (metric, cadence) where `current >= minLength`.
///   4. Rank all surviving streaks by `Streak.score`.
///   5. The top-scoring streak becomes the hero; the next N are badges.
///
/// "Current" counts the live unit (today / this week) only if it already met the threshold.
/// This keeps the streak from being "broken" mid-day.
enum StreakEngine {
    /// Minimum current length to surface a streak. Anything shorter is treated as trivia.
    static let minDailyLength = 3
    static let minWeeklyLength = 2
    /// Hard floor — we never surface streaks shorter than this even if nothing else qualifies.
    static let absoluteFloor = 2

    static func discover(
        history: [ActivityDay],
        hiddenMetrics: Set<StreakMetric> = [],
        now: Date = .now
    ) -> [Streak] {
        guard !history.isEmpty else { return [] }

        let byDay: [Date: ActivityDay] = Dictionary(uniqueKeysWithValues: history.map { ($0.date, $0) })
        let today = DateHelpers.startOfDay(now)
        let thisWeek = DateHelpers.startOfWeek(now)

        var found: [Streak] = []

        for metric in StreakMetric.allCases where !hiddenMetrics.contains(metric) {
            // Daily
            let bestDaily = pickBest(
                thresholds: metric.dailyThresholds,
                minLength: metric == .workouts ? minDailyLength : minDailyLength,
                build: { threshold in
                    computeDailyStreak(metric: metric, threshold: threshold, byDay: byDay, today: today)
                }
            )
            if let s = bestDaily { found.append(s) }

            // Weekly
            if let weekly = metric.weeklyThresholds {
                let weekTotals = weeklyTotals(for: metric, byDay: byDay)
                let bestWeekly = pickBest(
                    thresholds: weekly,
                    minLength: minWeeklyLength,
                    build: { threshold in
                        computeWeeklyStreak(metric: metric, threshold: threshold, weekTotals: weekTotals, thisWeek: thisWeek)
                    }
                )
                if let s = bestWeekly { found.append(s) }
            }
        }

        return found.sorted { $0.score > $1.score }
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
            currentUnitValue: streak.currentUnitValue
        )
    }

    // MARK: - Selection

    private static func pickBest(
        thresholds: [Double],
        minLength: Int,
        build: (Double) -> Streak
    ) -> Streak? {
        // Evaluate all thresholds; find the highest threshold whose current >= minLength.
        // If none qualifies, fall back to the lowest threshold that has at least `absoluteFloor`.
        let results = thresholds.map(build)

        if let best = results.reversed().first(where: { $0.current >= minLength }) {
            return best
        }
        if let floor = results.first(where: { $0.current >= absoluteFloor }) {
            return floor
        }
        return nil
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

    // MARK: - Weekly

    static func weeklyTotals(for metric: StreakMetric, byDay: [Date: ActivityDay]) -> [Date: Double] {
        var totals: [Date: Double] = [:]
        for (day, activity) in byDay {
            let weekStart = DateHelpers.startOfWeek(day)
            totals[weekStart, default: 0] += activity.value(for: metric)
        }
        return totals
    }

    static func computeWeeklyStreak(
        metric: StreakMetric,
        threshold: Double,
        weekTotals: [Date: Double],
        thisWeek: Date
    ) -> Streak {
        let thisValue = weekTotals[thisWeek] ?? 0
        let thisMet = thisValue >= threshold

        var currentLen = 0
        var streakStart: Date? = nil
        if thisMet {
            currentLen = 1
            streakStart = thisWeek
        }

        var cursor = DateHelpers.addWeeks(-1, to: thisWeek)
        while true {
            let v = weekTotals[cursor] ?? 0
            if v >= threshold {
                currentLen += 1
                streakStart = cursor
                cursor = DateHelpers.addWeeks(-1, to: cursor)
            } else {
                break
            }
        }

        // Best weekly streak
        let sortedWeeks = weekTotals.keys.sorted()
        var best = 0
        var run = 0
        for w in sortedWeeks {
            if (weekTotals[w] ?? 0) >= threshold {
                run += 1
                best = max(best, run)
            } else {
                run = 0
            }
        }
        best = max(best, currentLen)

        // Last week that met threshold
        var lastHit: Date? = nil
        var back = thisWeek
        for _ in 0..<200 {
            if (weekTotals[back] ?? 0) >= threshold {
                lastHit = back
                break
            }
            back = DateHelpers.addWeeks(-1, to: back)
        }

        let progress = threshold > 0 ? min(thisValue / threshold, 10) : 0
        return Streak(
            metric: metric,
            cadence: .weekly,
            threshold: threshold,
            current: currentLen,
            best: best,
            startDate: streakStart,
            lastHitDate: lastHit,
            currentUnitCompleted: thisMet,
            currentUnitProgress: progress,
            currentUnitValue: thisValue
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
            return (day.date, v, v >= threshold)
        }
    }

    /// For the detail screen (weekly): per-week total + hit/miss.
    static func weeklyHistory(
        for metric: StreakMetric,
        threshold: Double,
        history: [ActivityDay]
    ) -> [(weekStart: Date, total: Double, met: Bool)] {
        var totals: [Date: Double] = [:]
        for day in history {
            let w = DateHelpers.startOfWeek(day.date)
            totals[w, default: 0] += day.value(for: metric)
        }
        let sorted = totals.keys.sorted()
        return sorted.map { w in
            let t = totals[w] ?? 0
            return (w, t, t >= threshold)
        }
    }
}

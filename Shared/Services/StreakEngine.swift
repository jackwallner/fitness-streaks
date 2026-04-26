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
        let thisWeek = DateHelpers.startOfWeek(now)

        var found: [Streak] = []

        for metric in StreakMetric.allCases where !hiddenMetrics.contains(metric) {
            // Daily — per-vibe threshold pick
            let dailyCandidates = metric.dailyThresholds.map { t in
                computeDailyStreak(metric: metric, threshold: t, byDay: byDay, today: today)
            }
            if let best = pickByVibe(candidates: dailyCandidates, vibe: vibe, minLength: minDailyLength) {
                found.append(best)
            }

            // Weekly
            if let weekly = metric.weeklyThresholds {
                let weekTotals = weeklyTotals(for: metric, byDay: byDay)
                let weeklyCandidates = weekly.map { t in
                    computeWeeklyStreak(metric: metric, threshold: t, weekTotals: weekTotals, thisWeek: thisWeek)
                }
                if let best = pickByVibe(candidates: weeklyCandidates, vibe: vibe, minLength: minWeeklyLength) {
                    found.append(best)
                }
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

    /// Choose the best per-(metric,cadence) threshold for a given vibe.
    /// `candidates` is one Streak per threshold, ascending.
    private static func pickByVibe(candidates: [Streak], vibe: DiscoveryVibe, minLength: Int) -> Streak? {
        guard !candidates.isEmpty else { return nil }
        switch vibe {
        case .lifeChanging:
            // Highest threshold where current >= minLength; else highest with any history.
            if let hit = candidates.reversed().first(where: { $0.current >= minLength }) {
                return hit
            }
            return candidates.reversed().first(where: { $0.current >= absoluteFloor })
        case .challenging:
            // Favor mid-tier with real momentum: highest threshold where current >= minLength × 2,
            // else any threshold meeting minLength, else floor.
            if let pushed = candidates.reversed().first(where: { $0.current >= max(minLength * 2, minLength + 2) }) {
                return pushed
            }
            if let hit = candidates.reversed().first(where: { $0.current >= minLength }) {
                return hit
            }
            return candidates.first(where: { $0.current >= absoluteFloor })
        case .sustainable:
            // Prefer the longest-running streak across tiers, weighting ties toward higher tier.
            let qualifying = candidates.filter { $0.current >= minLength }
            let pool = qualifying.isEmpty ? candidates.filter { $0.current >= absoluteFloor } : qualifying
            return pool.max { a, b in
                if a.current != b.current { return a.current < b.current }
                return a.threshold < b.threshold
            }
        }
    }

    /// Score tuned per vibe — drives which streak becomes hero and badge ordering.
    static func vibeScore(_ s: Streak, vibe: DiscoveryVibe) -> Double {
        let thresholds = s.window == nil
            ? (s.cadence == .daily ? s.metric.dailyThresholds : (s.metric.weeklyThresholds ?? s.metric.dailyThresholds))
            : hourlyStepThresholds
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

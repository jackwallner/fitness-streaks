import Foundation

func day(_ n: Int) -> Date { DateHelpers.addDays(n, to: today) }
func date(_ value: Date?) -> Any { value.map(DateHelpers.dayKey) ?? NSNull() }
func encode(_ s: Streak) -> [String: Any] {
    ["metric": s.metric.rawValue, "cadence": s.cadence.rawValue, "threshold": s.threshold,
     "key": s.trackingKey, "id": s.id, "customID": s.customID as Any? ?? NSNull(),
     "hour": s.window?.startHour as Any? ?? NSNull(), "workoutType": s.workoutType as Any? ?? NSNull(),
     "measure": s.workoutMeasure?.rawValue as Any? ?? NSNull(), "current": s.current, "best": s.best,
     "start": date(s.startDate), "lastHit": date(s.lastHitDate), "lastMissed": date(s.lastMissedDate),
     "completed": s.currentUnitCompleted, "progress": s.currentUnitProgress, "value": s.currentUnitValue,
     "rate": s.completionRate, "lookback": s.lookbackDays, "score": StreakEngine.intensityScore(s, intensity: .challenging)]
}
func activity(_ offset: Int, _ seed: Int) -> ActivityDay {
    let i = offset + 80
    let hit = ((i * 17 + seed * 13) % 11) > seed % 5
    let scale = hit ? Double((i + seed) % 7 + 5) : 0
    return ActivityDay(date: day(offset), steps: scale * 1130 + Double(i % 3), exerciseMinutes: scale * 4.3,
                       standHours: scale, activeEnergy: scale * 51.2, workoutCount: hit ? 1 : 0,
                       mindfulMinutes: scale * 0.8, sleepHours: scale * 0.9, distanceMiles: scale * 0.83,
                       flightsClimbed: scale * 2.1, earlySteps: scale * 134, heartRateMinutes: scale * 2.7,
                       workoutDetails: ["running": WorkoutDailyStat(count: hit ? 1 : 0, minutes: scale * 4, miles: scale * 0.5)])
}
func encodeDay(_ a: ActivityDay) -> [String: Any] {
    ["date": DateHelpers.dayKey(a.date), "values": StreakMetric.allCases.map { a.value(for: $0) },
     "running": [a.workoutDetails["running"]?.count ?? 0, a.workoutDetails["running"]?.minutes ?? 0, a.workoutDetails["running"]?.miles ?? 0]]
}
let today = DateHelpers.startOfDay(Date(timeIntervalSince1970: 1772996400))
var daily: [[String: Any]] = []
for metric in StreakMetric.allCases {
    for seed in 0..<90 {
        let threshold = seed % 13 == 0 ? 0 : metric.dailyThresholds[seed % metric.dailyThresholds.count]
        let history = (-65...0).map { activity($0, seed) }
        let values = Dictionary(uniqueKeysWithValues: history.map { ($0.date, $0.value(for: metric)) })
        let freezes: Set<Date> = seed % 3 == 0 ? [day(-1), day(-4), day(0)] : []
        let s = StreakEngine.computeDailyStreakFromValues(metric: metric, threshold: threshold, byDayValues: values, today: today, plannedFreezes: freezes)
        daily.append(["metric": metric.rawValue, "threshold": threshold, "today": DateHelpers.dayKey(today), "values": values.map { ["date": DateHelpers.dayKey($0.key), "value": $0.value] }, "freezes": freezes.map(DateHelpers.dayKey), "expected": encode(s)])
    }
}
var discoveries: [[String: Any]] = []
for seed in 0..<96 {
    let history = (-65...0).map { activity($0, seed) }
    let intensity = DiscoveryIntensity(rawValue: seed % 3)!
    let lookback = [7, 14, 30, 66, 365][seed % 5]
    let hidden: Set<StreakMetric> = seed % 4 == 0 ? [.steps, .standHours] : []
    let committed: [String: Double] = seed % 3 == 0 ? ["steps-daily": 5000, "sleepHours-daily": 7] : [:]
    let custom = CustomStreak(id: "fixture", metric: .workouts, cadence: seed % 2 == 0 ? .daily : .weekly, threshold: seed % 2 == 0 ? 20 : 2, hourWindow: nil, workoutType: "running", workoutMeasure: seed % 2 == 0 ? .minutes : .count)
    let freezes: Set<Date> = seed % 5 == 0 ? [day(-1), day(-2)] : []
    let grace = GracePreservation(key: "steps-daily", missedDate: day(-1 - seed % 6), preservedLength: 10, threshold: 5000, metric: .steps, cadence: .daily, hourWindow: nil, grantedAt: today)
    let preservations = seed % 3 == 0 ? [grace.key: grace] : [:]
    let found = StreakEngine.discover(history: history, hiddenMetrics: hidden, intensity: intensity, lookbackDays: lookback, committedThresholds: committed, customStreaks: [custom], gracePreservations: preservations, plannedFreezes: freezes, now: today)
    discoveries.append(["seed": seed, "today": DateHelpers.dayKey(today), "history": history.map(encodeDay), "intensity": intensity.rawValue, "lookback": lookback, "hidden": hidden.map(\.rawValue), "committed": committed, "freezes": freezes.map(DateHelpers.dayKey), "graceMissed": date(preservations.isEmpty ? nil : grace.missedDate), "custom": ["id": custom.id, "metric": custom.metric.rawValue, "cadence": custom.cadence.rawValue, "threshold": custom.threshold, "workoutType": "running", "measure": custom.workoutMeasure!.rawValue], "expected": found.map(encode)])
}
let catalog: [String: Any] = ["metrics": StreakMetric.allCases.map { ["key": $0.rawValue, "name": $0.displayName, "unit": $0.unitLabel, "weight": $0.weight, "thresholds": $0.dailyThresholds] as [String: Any] }, "workouts": WorkoutTypeCatalog.all.map { ["key": $0.key, "name": $0.displayName, "distance": $0.supportsDistance] as [String: Any] }]
let out: [String: Any] = ["daily": daily, "discoveries": discoveries, "timezone": TimeZone.current.identifier]
try JSONSerialization.data(withJSONObject: out, options: [.sortedKeys]).write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
try JSONSerialization.data(withJSONObject: catalog, options: [.sortedKeys, .prettyPrinted]).write(to: URL(fileURLWithPath: CommandLine.arguments[2]))
print("Exported \(daily.count) daily cases and \(discoveries.count) discoveries from original Swift sources")

import Foundation

/// What we measure on a per-type workout streak.
enum WorkoutMeasure: String, Codable, Sendable, CaseIterable, Identifiable {
    case count          // any session counts
    case minutes        // total session duration in minutes
    case miles          // total distance in miles (if HK provides it)

    var id: String { rawValue }

    var label: String {
        switch self {
        case .count: "Sessions"
        case .minutes: "Minutes"
        case .miles: "Miles"
        }
    }

    var unit: String {
        switch self {
        case .count: "session"
        case .minutes: "min"
        case .miles: "mi"
        }
    }
}

/// One day's per-type workout aggregate. Cached so widgets and the engine never re-query HK.
struct WorkoutDailyStat: Codable, Hashable, Sendable {
    var count: Double
    var minutes: Double
    var miles: Double

    func value(for measure: WorkoutMeasure) -> Double {
        switch measure {
        case .count: return count
        case .minutes: return minutes
        case .miles: return miles
        }
    }

    static let zero = WorkoutDailyStat(count: 0, minutes: 0, miles: 0)
}

/// Curated subset of HKWorkoutActivityType. Not exhaustive — Apple ships ~80 types,
/// most of which would just clutter the picker. Order = picker order.
///
/// `activityTypeRaw` is HKWorkoutActivityType.rawValue, hardcoded so this file does not
/// have to import HealthKit (which would force widget targets to link the framework).
enum WorkoutTypeCatalog {
    struct Entry: Identifiable, Hashable {
        let key: String                    // stable string used as map key + persisted ID
        let displayName: String
        let symbol: String
        let supportsDistance: Bool
        let activityTypeRaw: UInt           // HKWorkoutActivityType.rawValue

        var id: String { key }
    }

    static let all: [Entry] = [
        Entry(key: "running",             displayName: "Running",            symbol: "figure.run",                              supportsDistance: true,  activityTypeRaw: 37),
        Entry(key: "walking",             displayName: "Walking",            symbol: "figure.walk",                             supportsDistance: true,  activityTypeRaw: 52),
        Entry(key: "hiking",              displayName: "Hiking",             symbol: "figure.hiking",                           supportsDistance: true,  activityTypeRaw: 24),
        Entry(key: "cycling",             displayName: "Cycling",            symbol: "figure.outdoor.cycle",                    supportsDistance: true,  activityTypeRaw: 13),
        Entry(key: "swimming",            displayName: "Swimming",           symbol: "figure.pool.swim",                        supportsDistance: true,  activityTypeRaw: 46),
        Entry(key: "rowing",              displayName: "Rowing",             symbol: "figure.rower",                            supportsDistance: true,  activityTypeRaw: 35),
        Entry(key: "elliptical",          displayName: "Elliptical",         symbol: "figure.elliptical",                       supportsDistance: false, activityTypeRaw: 16),
        Entry(key: "stairClimbing",       displayName: "Stair Climbing",     symbol: "figure.stair.stepper",                    supportsDistance: false, activityTypeRaw: 44),
        Entry(key: "yoga",                displayName: "Yoga",               symbol: "figure.yoga",                             supportsDistance: false, activityTypeRaw: 57),
        Entry(key: "pilates",             displayName: "Pilates",            symbol: "figure.pilates",                          supportsDistance: false, activityTypeRaw: 66),
        Entry(key: "coreTraining",        displayName: "Core Training",      symbol: "figure.core.training",                    supportsDistance: false, activityTypeRaw: 59),
        Entry(key: "functionalStrength",  displayName: "Functional Strength", symbol: "figure.strengthtraining.functional",     supportsDistance: false, activityTypeRaw: 20),
        Entry(key: "traditionalStrength", displayName: "Strength Training",  symbol: "figure.strengthtraining.traditional",     supportsDistance: false, activityTypeRaw: 50),
        Entry(key: "hiit",                displayName: "HIIT",               symbol: "figure.highintensity.intervaltraining",   supportsDistance: false, activityTypeRaw: 63),
        Entry(key: "mixedCardio",         displayName: "Mixed Cardio",       symbol: "figure.mixed.cardio",                     supportsDistance: false, activityTypeRaw: 73),
        Entry(key: "cardioDance",         displayName: "Dance",              symbol: "figure.dance",                            supportsDistance: false, activityTypeRaw: 77),
        Entry(key: "boxing",              displayName: "Boxing",             symbol: "figure.boxing",                           supportsDistance: false, activityTypeRaw: 8),
        Entry(key: "kickboxing",          displayName: "Kickboxing",         symbol: "figure.kickboxing",                       supportsDistance: false, activityTypeRaw: 65),
        Entry(key: "martialArts",         displayName: "Martial Arts",       symbol: "figure.martial.arts",                     supportsDistance: false, activityTypeRaw: 28),
        Entry(key: "climbing",            displayName: "Climbing",           symbol: "figure.climbing",                         supportsDistance: false, activityTypeRaw: 9),
        Entry(key: "tennis",              displayName: "Tennis",             symbol: "figure.tennis",                           supportsDistance: false, activityTypeRaw: 48),
        Entry(key: "basketball",          displayName: "Basketball",         symbol: "figure.basketball",                       supportsDistance: false, activityTypeRaw: 6),
        Entry(key: "soccer",              displayName: "Soccer",             symbol: "figure.soccer",                           supportsDistance: false, activityTypeRaw: 41),
        Entry(key: "golf",                displayName: "Golf",               symbol: "figure.golf",                             supportsDistance: true,  activityTypeRaw: 21),
        Entry(key: "skating",             displayName: "Skating",            symbol: "figure.skating",                          supportsDistance: true,  activityTypeRaw: 39),
        Entry(key: "downhillSkiing",      displayName: "Skiing",             symbol: "figure.skiing.downhill",                  supportsDistance: true,  activityTypeRaw: 61),
        Entry(key: "snowboarding",        displayName: "Snowboarding",       symbol: "figure.snowboarding",                     supportsDistance: true,  activityTypeRaw: 67),
        Entry(key: "surfing",             displayName: "Surfing",            symbol: "figure.surfing",                          supportsDistance: false, activityTypeRaw: 45),
        Entry(key: "paddleSports",        displayName: "Paddle Sports",      symbol: "oar.2.crossed",                           supportsDistance: true,  activityTypeRaw: 31),
        Entry(key: "jumpRope",            displayName: "Jump Rope",          symbol: "figure.jumprope",                         supportsDistance: false, activityTypeRaw: 64),
        Entry(key: "mindAndBody",         displayName: "Mind & Body",        symbol: "figure.mind.and.body",                    supportsDistance: false, activityTypeRaw: 29),
        Entry(key: "pickleball",          displayName: "Pickleball",         symbol: "figure.pickleball",                       supportsDistance: false, activityTypeRaw: 79),
        Entry(key: "barre",               displayName: "Barre",              symbol: "figure.barre",                            supportsDistance: false, activityTypeRaw: 58),
        Entry(key: "taiChi",              displayName: "Tai Chi",            symbol: "figure.taichi",                           supportsDistance: false, activityTypeRaw: 72),
    ]

    private static let byKey: [String: Entry] = Dictionary(uniqueKeysWithValues: all.map { ($0.key, $0) })
    private static let byRaw: [UInt: Entry] = Dictionary(uniqueKeysWithValues: all.map { ($0.activityTypeRaw, $0) })

    static func entry(forKey key: String) -> Entry? { byKey[key] }
    static func entry(forActivityRaw raw: UInt) -> Entry? { byRaw[raw] }
}

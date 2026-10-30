import Foundation

/// What we measure on a per-type workout streak.
enum WorkoutMeasure: String, Codable, Sendable, CaseIterable, Identifiable {
    case count          // any session counts
    case minutes        // total session duration in minutes
    case miles          // total distance in miles (if HK provides it)

    var id: String { rawValue }

    var label: String {
        switch self {
        case .count: String(localized: "Sessions")
        case .minutes: String(localized: "Minutes")
        case .miles: String(localized: "Miles")
        }
    }

    var unit: String {
        switch self {
        case .count: String(localized: "unit.session", defaultValue: "session")
        case .minutes: String(localized: "unit.min", defaultValue: "min")
        case .miles: String(localized: "unit.mi", defaultValue: "mi")
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
        /// The name inside a sentence ("20 min running", "20 Min. Laufen",
        /// "20 min biegania"); see `StreakMetric.inlineName`.
        let inlineName: String
        let symbol: String
        let supportsDistance: Bool
        let activityTypeRaw: UInt           // HKWorkoutActivityType.rawValue

        var id: String { key }
    }

    static let all: [Entry] = [
        Entry(key: "running",             displayName: String(localized: "Running"), inlineName: String(localized: "inline.running", defaultValue: "running"), symbol: "figure.run",                              supportsDistance: true,  activityTypeRaw: 37),
        Entry(key: "walking",             displayName: String(localized: "Walking"), inlineName: String(localized: "inline.walking", defaultValue: "walking"), symbol: "figure.walk",                             supportsDistance: true,  activityTypeRaw: 52),
        Entry(key: "hiking",              displayName: String(localized: "Hiking"), inlineName: String(localized: "inline.hiking", defaultValue: "hiking"), symbol: "figure.hiking",                           supportsDistance: true,  activityTypeRaw: 24),
        Entry(key: "cycling",             displayName: String(localized: "Cycling"), inlineName: String(localized: "inline.cycling", defaultValue: "cycling"), symbol: "figure.outdoor.cycle",                    supportsDistance: true,  activityTypeRaw: 13),
        Entry(key: "swimming",            displayName: String(localized: "Swimming"), inlineName: String(localized: "inline.swimming", defaultValue: "swimming"), symbol: "figure.pool.swim",                        supportsDistance: true,  activityTypeRaw: 46),
        Entry(key: "rowing",              displayName: String(localized: "Rowing"), inlineName: String(localized: "inline.rowing", defaultValue: "rowing"), symbol: "figure.rower",                            supportsDistance: true,  activityTypeRaw: 35),
        Entry(key: "elliptical",          displayName: String(localized: "Elliptical"), inlineName: String(localized: "inline.elliptical", defaultValue: "elliptical"), symbol: "figure.elliptical",                       supportsDistance: false, activityTypeRaw: 16),
        Entry(key: "stairClimbing",       displayName: String(localized: "Stair Climbing"), inlineName: String(localized: "inline.stairClimbing", defaultValue: "stair climbing"), symbol: "figure.stair.stepper",                    supportsDistance: false, activityTypeRaw: 44),
        Entry(key: "yoga",                displayName: String(localized: "Yoga"), inlineName: String(localized: "inline.yoga", defaultValue: "yoga"), symbol: "figure.yoga",                             supportsDistance: false, activityTypeRaw: 57),
        Entry(key: "pilates",             displayName: String(localized: "Pilates"), inlineName: String(localized: "inline.pilates", defaultValue: "pilates"), symbol: "figure.pilates",                          supportsDistance: false, activityTypeRaw: 66),
        Entry(key: "coreTraining",        displayName: String(localized: "Core Training"), inlineName: String(localized: "inline.coreTraining", defaultValue: "core training"), symbol: "figure.core.training",                    supportsDistance: false, activityTypeRaw: 59),
        Entry(key: "functionalStrength",  displayName: String(localized: "Functional Strength"), inlineName: String(localized: "inline.functionalStrength", defaultValue: "functional strength"), symbol: "figure.strengthtraining.functional",     supportsDistance: false, activityTypeRaw: 20),
        Entry(key: "traditionalStrength", displayName: String(localized: "Strength Training"), inlineName: String(localized: "inline.traditionalStrength", defaultValue: "strength training"), symbol: "figure.strengthtraining.traditional",     supportsDistance: false, activityTypeRaw: 50),
        Entry(key: "hiit",                displayName: String(localized: "HIIT"), inlineName: String(localized: "inline.hiit", defaultValue: "HIIT"), symbol: "figure.highintensity.intervaltraining",   supportsDistance: false, activityTypeRaw: 63),
        Entry(key: "mixedCardio",         displayName: String(localized: "Mixed Cardio"), inlineName: String(localized: "inline.mixedCardio", defaultValue: "mixed cardio"), symbol: "figure.mixed.cardio",                     supportsDistance: false, activityTypeRaw: 73),
        Entry(key: "cardioDance",         displayName: String(localized: "Dance"), inlineName: String(localized: "inline.cardioDance", defaultValue: "dance"), symbol: "figure.dance",                            supportsDistance: false, activityTypeRaw: 77),
        Entry(key: "boxing",              displayName: String(localized: "Boxing"), inlineName: String(localized: "inline.boxing", defaultValue: "boxing"), symbol: "figure.boxing",                           supportsDistance: false, activityTypeRaw: 8),
        Entry(key: "kickboxing",          displayName: String(localized: "Kickboxing"), inlineName: String(localized: "inline.kickboxing", defaultValue: "kickboxing"), symbol: "figure.kickboxing",                       supportsDistance: false, activityTypeRaw: 65),
        Entry(key: "martialArts",         displayName: String(localized: "Martial Arts"), inlineName: String(localized: "inline.martialArts", defaultValue: "martial arts"), symbol: "figure.martial.arts",                     supportsDistance: false, activityTypeRaw: 28),
        Entry(key: "climbing",            displayName: String(localized: "Climbing"), inlineName: String(localized: "inline.climbing", defaultValue: "climbing"), symbol: "figure.climbing",                         supportsDistance: false, activityTypeRaw: 9),
        Entry(key: "tennis",              displayName: String(localized: "Tennis"), inlineName: String(localized: "inline.tennis", defaultValue: "tennis"), symbol: "figure.tennis",                           supportsDistance: false, activityTypeRaw: 48),
        Entry(key: "basketball",          displayName: String(localized: "Basketball"), inlineName: String(localized: "inline.basketball", defaultValue: "basketball"), symbol: "figure.basketball",                       supportsDistance: false, activityTypeRaw: 6),
        Entry(key: "soccer",              displayName: String(localized: "Soccer"), inlineName: String(localized: "inline.soccer", defaultValue: "soccer"), symbol: "figure.soccer",                           supportsDistance: false, activityTypeRaw: 41),
        Entry(key: "golf",                displayName: String(localized: "Golf"), inlineName: String(localized: "inline.golf", defaultValue: "golf"), symbol: "figure.golf",                             supportsDistance: true,  activityTypeRaw: 21),
        Entry(key: "skating",             displayName: String(localized: "Skating"), inlineName: String(localized: "inline.skating", defaultValue: "skating"), symbol: "figure.skating",                          supportsDistance: true,  activityTypeRaw: 39),
        Entry(key: "downhillSkiing",      displayName: String(localized: "Skiing"), inlineName: String(localized: "inline.downhillSkiing", defaultValue: "skiing"), symbol: "figure.skiing.downhill",                  supportsDistance: true,  activityTypeRaw: 61),
        Entry(key: "snowboarding",        displayName: String(localized: "Snowboarding"), inlineName: String(localized: "inline.snowboarding", defaultValue: "snowboarding"), symbol: "figure.snowboarding",                     supportsDistance: true,  activityTypeRaw: 67),
        Entry(key: "surfing",             displayName: String(localized: "Surfing"), inlineName: String(localized: "inline.surfing", defaultValue: "surfing"), symbol: "figure.surfing",                          supportsDistance: false, activityTypeRaw: 45),
        Entry(key: "paddleSports",        displayName: String(localized: "Paddle Sports"), inlineName: String(localized: "inline.paddleSports", defaultValue: "paddle sports"), symbol: "oar.2.crossed",                           supportsDistance: true,  activityTypeRaw: 31),
        Entry(key: "jumpRope",            displayName: String(localized: "Jump Rope"), inlineName: String(localized: "inline.jumpRope", defaultValue: "jump rope"), symbol: "figure.jumprope",                         supportsDistance: false, activityTypeRaw: 64),
        Entry(key: "mindAndBody",         displayName: String(localized: "Mind & Body"), inlineName: String(localized: "inline.mindAndBody", defaultValue: "mind & body"), symbol: "figure.mind.and.body",                    supportsDistance: false, activityTypeRaw: 29),
        Entry(key: "pickleball",          displayName: String(localized: "Pickleball"), inlineName: String(localized: "inline.pickleball", defaultValue: "pickleball"), symbol: "figure.pickleball",                       supportsDistance: false, activityTypeRaw: 79),
        Entry(key: "barre",               displayName: String(localized: "Barre"), inlineName: String(localized: "inline.barre", defaultValue: "barre"), symbol: "figure.barre",                            supportsDistance: false, activityTypeRaw: 58),
        Entry(key: "taiChi",              displayName: String(localized: "Tai Chi"), inlineName: String(localized: "inline.taiChi", defaultValue: "tai chi"), symbol: "figure.taichi",                           supportsDistance: false, activityTypeRaw: 72),
    ]

    private static let byKey: [String: Entry] = Dictionary(uniqueKeysWithValues: all.map { ($0.key, $0) })
    private static let byRaw: [UInt: Entry] = Dictionary(uniqueKeysWithValues: all.map { ($0.activityTypeRaw, $0) })

    static func entry(forKey key: String) -> Entry? { byKey[key] }
    static func entry(forActivityRaw raw: UInt) -> Entry? { byRaw[raw] }
}

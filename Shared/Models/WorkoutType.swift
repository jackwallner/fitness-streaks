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
        case .count: String(localized: "session")
        case .minutes: String(localized: "min")
        case .miles: String(localized: "mi")
        }
    }

    func amount(_ number: String) -> String {
        switch self {
        case .count: String(localized: "\(number) session")
        case .minutes: String(localized: "\(number) min")
        case .miles: String(localized: "\(number) mi")
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
        let symbol: String
        let supportsDistance: Bool
        let activityTypeRaw: UInt           // HKWorkoutActivityType.rawValue

        var id: String { key }

        var displayName: String {
            switch key {
            case "running": String(localized: "Running")
            case "walking": String(localized: "Walking")
            case "hiking": String(localized: "Hiking")
            case "cycling": String(localized: "Cycling")
            case "swimming": String(localized: "Swimming")
            case "rowing": String(localized: "Rowing")
            case "elliptical": String(localized: "Elliptical")
            case "stairClimbing": String(localized: "Stair Climbing")
            case "yoga": String(localized: "Yoga")
            case "pilates": String(localized: "Pilates")
            case "coreTraining": String(localized: "Core Training")
            case "functionalStrength": String(localized: "Functional Strength")
            case "traditionalStrength": String(localized: "Strength Training")
            case "hiit": String(localized: "HIIT")
            case "mixedCardio": String(localized: "Mixed Cardio")
            case "cardioDance": String(localized: "Dance")
            case "boxing": String(localized: "Boxing")
            case "kickboxing": String(localized: "Kickboxing")
            case "martialArts": String(localized: "Martial Arts")
            case "climbing": String(localized: "Climbing")
            case "tennis": String(localized: "Tennis")
            case "basketball": String(localized: "Basketball")
            case "soccer": String(localized: "Soccer")
            case "golf": String(localized: "Golf")
            case "skating": String(localized: "Skating")
            case "downhillSkiing": String(localized: "Skiing")
            case "snowboarding": String(localized: "Snowboarding")
            case "surfing": String(localized: "Surfing")
            case "paddleSports": String(localized: "Paddle Sports")
            case "jumpRope": String(localized: "Jump Rope")
            case "mindAndBody": String(localized: "Mind & Body")
            case "pickleball": String(localized: "Pickleball")
            case "barre": String(localized: "Barre")
            case "taiChi": String(localized: "Tai Chi")
            default: key
            }
        }

        /// Lowercase form for use inside a sentence ("20 min cycling"). A separate
        /// key per type, so no language has to lowercase translated text.
        var lowerName: String {
            switch key {
            case "running": String(localized: "running")
            case "walking": String(localized: "walking")
            case "hiking": String(localized: "hiking")
            case "cycling": String(localized: "cycling")
            case "swimming": String(localized: "swimming")
            case "rowing": String(localized: "rowing")
            case "elliptical": String(localized: "elliptical")
            case "stairClimbing": String(localized: "stair climbing")
            case "yoga": String(localized: "yoga")
            case "pilates": String(localized: "pilates")
            case "coreTraining": String(localized: "core training")
            case "functionalStrength": String(localized: "functional strength")
            case "traditionalStrength": String(localized: "strength training")
            case "hiit": String(localized: "hiit")
            case "mixedCardio": String(localized: "mixed cardio")
            case "cardioDance": String(localized: "dance")
            case "boxing": String(localized: "boxing")
            case "kickboxing": String(localized: "kickboxing")
            case "martialArts": String(localized: "martial arts")
            case "climbing": String(localized: "climbing")
            case "tennis": String(localized: "tennis")
            case "basketball": String(localized: "basketball")
            case "soccer": String(localized: "soccer")
            case "golf": String(localized: "golf")
            case "skating": String(localized: "skating")
            case "downhillSkiing": String(localized: "skiing")
            case "snowboarding": String(localized: "snowboarding")
            case "surfing": String(localized: "surfing")
            case "paddleSports": String(localized: "paddle sports")
            case "jumpRope": String(localized: "jump rope")
            case "mindAndBody": String(localized: "mind & body")
            case "pickleball": String(localized: "pickleball")
            case "barre": String(localized: "barre")
            case "taiChi": String(localized: "tai chi")
            default: key
            }
        }
    }

    static let all: [Entry] = [
        Entry(key: "running", symbol: "figure.run",                              supportsDistance: true,  activityTypeRaw: 37),
        Entry(key: "walking", symbol: "figure.walk",                             supportsDistance: true,  activityTypeRaw: 52),
        Entry(key: "hiking", symbol: "figure.hiking",                           supportsDistance: true,  activityTypeRaw: 24),
        Entry(key: "cycling", symbol: "figure.outdoor.cycle",                    supportsDistance: true,  activityTypeRaw: 13),
        Entry(key: "swimming", symbol: "figure.pool.swim",                        supportsDistance: true,  activityTypeRaw: 46),
        Entry(key: "rowing", symbol: "figure.rower",                            supportsDistance: true,  activityTypeRaw: 35),
        Entry(key: "elliptical", symbol: "figure.elliptical",                       supportsDistance: false, activityTypeRaw: 16),
        Entry(key: "stairClimbing", symbol: "figure.stair.stepper",                    supportsDistance: false, activityTypeRaw: 44),
        Entry(key: "yoga", symbol: "figure.yoga",                             supportsDistance: false, activityTypeRaw: 57),
        Entry(key: "pilates", symbol: "figure.pilates",                          supportsDistance: false, activityTypeRaw: 66),
        Entry(key: "coreTraining", symbol: "figure.core.training",                    supportsDistance: false, activityTypeRaw: 59),
        Entry(key: "functionalStrength", symbol: "figure.strengthtraining.functional",     supportsDistance: false, activityTypeRaw: 20),
        Entry(key: "traditionalStrength", symbol: "figure.strengthtraining.traditional",     supportsDistance: false, activityTypeRaw: 50),
        Entry(key: "hiit", symbol: "figure.highintensity.intervaltraining",   supportsDistance: false, activityTypeRaw: 63),
        Entry(key: "mixedCardio", symbol: "figure.mixed.cardio",                     supportsDistance: false, activityTypeRaw: 73),
        Entry(key: "cardioDance", symbol: "figure.dance",                            supportsDistance: false, activityTypeRaw: 77),
        Entry(key: "boxing", symbol: "figure.boxing",                           supportsDistance: false, activityTypeRaw: 8),
        Entry(key: "kickboxing", symbol: "figure.kickboxing",                       supportsDistance: false, activityTypeRaw: 65),
        Entry(key: "martialArts", symbol: "figure.martial.arts",                     supportsDistance: false, activityTypeRaw: 28),
        Entry(key: "climbing", symbol: "figure.climbing",                         supportsDistance: false, activityTypeRaw: 9),
        Entry(key: "tennis", symbol: "figure.tennis",                           supportsDistance: false, activityTypeRaw: 48),
        Entry(key: "basketball", symbol: "figure.basketball",                       supportsDistance: false, activityTypeRaw: 6),
        Entry(key: "soccer", symbol: "figure.soccer",                           supportsDistance: false, activityTypeRaw: 41),
        Entry(key: "golf", symbol: "figure.golf",                             supportsDistance: true,  activityTypeRaw: 21),
        Entry(key: "skating", symbol: "figure.skating",                          supportsDistance: true,  activityTypeRaw: 39),
        Entry(key: "downhillSkiing", symbol: "figure.skiing.downhill",                  supportsDistance: true,  activityTypeRaw: 61),
        Entry(key: "snowboarding", symbol: "figure.snowboarding",                     supportsDistance: true,  activityTypeRaw: 67),
        Entry(key: "surfing", symbol: "figure.surfing",                          supportsDistance: false, activityTypeRaw: 45),
        Entry(key: "paddleSports", symbol: "oar.2.crossed",                           supportsDistance: true,  activityTypeRaw: 31),
        Entry(key: "jumpRope", symbol: "figure.jumprope",                         supportsDistance: false, activityTypeRaw: 64),
        Entry(key: "mindAndBody", symbol: "figure.mind.and.body",                    supportsDistance: false, activityTypeRaw: 29),
        Entry(key: "pickleball", symbol: "figure.pickleball",                       supportsDistance: false, activityTypeRaw: 79),
        Entry(key: "barre", symbol: "figure.barre",                            supportsDistance: false, activityTypeRaw: 58),
        Entry(key: "taiChi", symbol: "figure.taichi",                           supportsDistance: false, activityTypeRaw: 72),
    ]

    private static let byKey: [String: Entry] = Dictionary(uniqueKeysWithValues: all.map { ($0.key, $0) })
    private static let byRaw: [UInt: Entry] = Dictionary(uniqueKeysWithValues: all.map { ($0.activityTypeRaw, $0) })

    static func entry(forKey key: String) -> Entry? { byKey[key] }
    static func entry(forActivityRaw raw: UInt) -> Entry? { byRaw[raw] }
}

import Foundation

/// Count labels shown beside a number that is drawn separately ("12" over
/// "DAYS STREAK"). A catalog plural variant has to contain its number, so these
/// labels cannot be plural keys themselves. Instead the catalog's
/// `"%lld plural category"` key returns the CLDR category for the user's
/// language ("few 3"), and each label has one whole key per category.
enum PluralLabel {
    enum Category: String {
        case one, few, many, other
    }

    static func category(_ count: Int) -> Category {
        let token = String(localized: "\(count) plural category")
        let word = token.split(separator: " ").first.map(String.init) ?? ""
        return Category(rawValue: word) ?? (count == 1 ? .one : .other)
    }

    /// "day" / "days", the cadence unit under a bare count.
    static func cadenceName(_ cadence: StreakCadence, _ count: Int) -> String {
        switch (cadence, category(count)) {
        case (.daily, .one): String(localized: "day")
        case (.daily, .few): String(localized: "days (few)")
        case (.daily, .many): String(localized: "days (many)")
        case (.daily, .other): String(localized: "days")
        case (.weekly, .one): String(localized: "week")
        case (.weekly, .few): String(localized: "weeks (few)")
        case (.weekly, .many): String(localized: "weeks (many)")
        case (.weekly, .other): String(localized: "weeks")
        }
    }

    /// "day streak" / "days streak", under the detail screen's current count.
    static func cadenceStreak(_ cadence: StreakCadence, _ count: Int) -> String {
        switch (cadence, category(count)) {
        case (.daily, .one): String(localized: "day streak")
        case (.daily, .few): String(localized: "days streak (few)")
        case (.daily, .many): String(localized: "days streak (many)")
        case (.daily, .other): String(localized: "days streak")
        case (.weekly, .one): String(localized: "week streak")
        case (.weekly, .few): String(localized: "weeks streak (few)")
        case (.weekly, .many): String(localized: "weeks streak (many)")
        case (.weekly, .other): String(localized: "weeks streak")
        }
    }

    /// "best day" / "best days", under the detail screen's record count.
    static func bestCadence(_ cadence: StreakCadence, _ count: Int) -> String {
        switch (cadence, category(count)) {
        case (.daily, .one): String(localized: "best day")
        case (.daily, .few): String(localized: "best days (few)")
        case (.daily, .many): String(localized: "best days (many)")
        case (.daily, .other): String(localized: "best days")
        case (.weekly, .one): String(localized: "best week")
        case (.weekly, .few): String(localized: "best weeks (few)")
        case (.weekly, .many): String(localized: "best weeks (many)")
        case (.weekly, .other): String(localized: "best weeks")
        }
    }
}

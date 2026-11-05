import Foundation
import XCTest

/// The string catalog compiles into the app, and its English plural rules
/// survive the trip. Translations arrive in later runs; until then these prove
/// the catalog is wired into every build and the plural machinery works.
final class LocalizationTests: XCTestCase {
    static let languages: [String] = []

    private func bundle(_ language: String) -> Bundle? {
        let hosts = [Bundle.main] + Bundle.allBundles
        for host in hosts {
            if let path = host.path(forResource: language, ofType: "lproj"),
               let bundle = Bundle(path: path) {
                return bundle
            }
        }
        return nil
    }

    func testEnglishCatalogShips() {
        XCTAssertNotNil(bundle("en"), "en.lproj is missing")
    }

    func testEveryTranslatedLanguageShips() {
        for language in Self.languages {
            XCTAssertNotNil(bundle(language), "\(language).lproj is missing")
        }
    }

    func testEnglishPluralsPickOneAndOther() throws {
        let en = try XCTUnwrap(bundle("en"))
        let locale = Locale(identifier: "en")
        XCTAssertEqual(String(localized: "\(1) days", bundle: en, locale: locale), "1 day")
        XCTAssertEqual(String(localized: "\(5) days", bundle: en, locale: locale), "5 days")
        XCTAssertEqual(String(localized: "\(1) weeks", bundle: en, locale: locale), "1 week")
        XCTAssertEqual(String(localized: "\(3) weeks", bundle: en, locale: locale), "3 weeks")
    }

    func testPluralSubstitutionKeepsTheOtherArguments() throws {
        let en = try XCTUnwrap(bundle("en"))
        let locale = Locale(identifier: "en")
        let one = String(localized: "You're at \(1) days. Get it in before midnight.", bundle: en, locale: locale)
        let many = String(localized: "You're at \(4) days. Get it in before midnight.", bundle: en, locale: locale)
        XCTAssertEqual(one, "You're at 1 day. Get it in before midnight.")
        XCTAssertEqual(many, "You're at 4 days. Get it in before midnight.")
        let price = "$4.99"
        XCTAssertEqual(String(localized: "\(price) / \(1) days", bundle: en, locale: locale), "$4.99 / 1 day")
        XCTAssertEqual(String(localized: "\(price) / \(3) days", bundle: en, locale: locale), "$4.99 / 3 days")
    }

    func testPluralCategoryFollowsTheLanguage() {
        XCTAssertEqual(PluralLabel.category(1), .one)
        XCTAssertEqual(PluralLabel.category(5), .other)
        XCTAssertEqual(PluralLabel.cadenceStreak(.daily, 1), "day streak")
        XCTAssertEqual(PluralLabel.cadenceStreak(.daily, 12), "days streak")
        XCTAssertEqual(PluralLabel.bestCadence(.weekly, 1), "best week")
        XCTAssertEqual(PluralLabel.bestCadence(.weekly, 4), "best weeks")
    }

    func testMetricCopyKeepsItsEnglishWording() {
        XCTAssertEqual(StreakMetric.workouts.thresholdLabel(1, cadence: .daily), "any workout")
        XCTAssertEqual(StreakMetric.sleepHours.format(value: 7.5), "7.5")
        XCTAssertEqual(StreakMetric.distanceMiles.format(value: 12.34), "12")
    }

    // MARK: - Numeric plurals

    // These resolve through the English bundle: the test process has no
    // catalog of its own, so `String(localized:)` alone would return the key.
    // The literals match the ones in StreakMetric, WorkoutType, Streak and
    // StoreKitService, so a drifting key or a lost plural form shows up here.

    private func english() throws -> (bundle: Bundle, locale: Locale) {
        (try XCTUnwrap(bundle("en")), Locale(identifier: "en_US"))
    }

    /// Keys whose number reaches the catalog as an integer, so a language can
    /// pick one/few/many/other. Each must compile to a stringsdict plural rule.
    func testCountSensitiveKeysCompileToPluralRules() throws {
        let en = try XCTUnwrap(bundle("en"))
        let path = try XCTUnwrap(en.path(forResource: "Localizable", ofType: "stringsdict"))
        let rules = try XCTUnwrap(NSDictionary(contentsOfFile: path) as? [String: Any])
        let keys = [
            "%lld|%@ steps", "%lld|%@ min", "%lld|%@ hr", "%lld|%@ kcal", "%lld|%@ workout",
            "%lld|%@ min mindful", "%lld|%@ mi", "%lld|%@ flights", "%lld|%@ early steps",
            "%lld|%@ min cardio", "%lld|%@ session",
            "%lld|%@+ steps every day", "%lld|%@+ flights every day between %@",
            "%lld min %@", "%lld+ min of %@ every day",
            "REVIVE YOUR %lld-day %@ streak.", "REVIVE YOUR %lld-week %@ streak.",
            "%lld-day free trial, ON US.", "%lld-month free trial, ON US.", "%lld-year free trial, ON US.",
            "%@ streak: %lld days, threshold %@", "%@ streak: %lld weeks in a row, threshold %@",
        ]
        for key in keys {
            XCTAssertNotNil(rules[key], "\(key) lost its plural rule")
        }
    }

    /// A plural variation that printed its own `%lld` would group digits
    /// ("10,000 steps"), so goals travel as a selector plus separate text.
    func testAmountsAreNotGroupedAtAnyCount() throws {
        let (en, locale) = try english()
        for n in [0, 1, 2, 5, 11, 22, 1_000, 10_000] {
            let text = n.plain
            XCTAssertEqual(String(localized: "\(n)|\(text) steps", bundle: en, locale: locale), "\(n) steps")
            XCTAssertEqual(String(localized: "\(n)|\(text) min", bundle: en, locale: locale), "\(n) min")
            XCTAssertEqual(String(localized: "\(n)|\(text) hr", bundle: en, locale: locale), "\(n) hr")
            XCTAssertEqual(String(localized: "\(n)|\(text) kcal", bundle: en, locale: locale), "\(n) kcal")
            XCTAssertEqual(String(localized: "\(n)|\(text) workout", bundle: en, locale: locale), "\(n) workout")
            XCTAssertEqual(String(localized: "\(n)|\(text) min mindful", bundle: en, locale: locale), "\(n) min mindful")
            XCTAssertEqual(String(localized: "\(n)|\(text) mi", bundle: en, locale: locale), "\(n) mi")
            XCTAssertEqual(String(localized: "\(n)|\(text) flights", bundle: en, locale: locale), "\(n) flights")
            XCTAssertEqual(String(localized: "\(n)|\(text) early steps", bundle: en, locale: locale), "\(n) early steps")
            XCTAssertEqual(String(localized: "\(n)|\(text) min cardio", bundle: en, locale: locale), "\(n) min cardio")
            XCTAssertEqual(String(localized: "\(n)|\(text) session", bundle: en, locale: locale), "\(n) session")
        }
        let tenth = "7.5"
        XCTAssertEqual(String(localized: "\(tenth) hr sleep", bundle: en, locale: locale), "7.5 hr sleep")
        XCTAssertEqual(String(localized: "\(tenth) kcal/min", bundle: en, locale: locale), "7.5 kcal/min")
        XCTAssertEqual(String(localized: "\(tenth) mi", bundle: en, locale: locale), "7.5 mi")
    }

    func testProseKeepsItsEnglishWording() throws {
        let (en, locale) = try english()
        let n = 10_000
        let commas = "10,000"
        let plain = "1000"
        let window = "5p-6p"
        XCTAssertEqual(String(localized: "\(n)|\(commas)+ steps every day", bundle: en, locale: locale), "10,000+ steps every day")
        XCTAssertEqual(String(localized: "\(n)|\(commas)+ min cardio every day", bundle: en, locale: locale), "10,000+ min cardio every day")
        XCTAssertEqual(String(localized: "\(n)|\(plain)+ steps every day between \(window)", bundle: en, locale: locale),
                       "1000+ steps every day between 5p-6p")
        XCTAssertEqual(String(localized: "\(n)|\(plain)+ early steps every day between \(window)", bundle: en, locale: locale),
                       "1000+ early steps every day between 5p-6p")
        let hours = "7.5"
        XCTAssertEqual(String(localized: "\(hours)+ hr sleep every day between \(window)", bundle: en, locale: locale),
                       "7.5+ hr sleep every day between 5p-6p")
        let minutes = 30
        let name = "running"
        XCTAssertEqual(String(localized: "\(minutes)+ min of \(name) every day", bundle: en, locale: locale), "30+ min of running every day")
        XCTAssertEqual(String(localized: "\(minutes) min \(name)", bundle: en, locale: locale), "30 min running")
        XCTAssertEqual(String(localized: "\(minutes) \(name) sessions", bundle: en, locale: locale), "30 running sessions")
    }

    /// Window prose prints the goal the way the detail screen always did
    /// (`format(value:)`), with no thousands separator. The comma form is the
    /// non-window `prose`.
    func testWindowProseNumberHasNoSeparator() {
        XCTAssertEqual(StreakMetric.steps.format(value: 1_000), "1000")
        XCTAssertEqual(StreakMetric.steps.format(value: 12_500), "12500")
        XCTAssertEqual(StreakMetric.sleepHours.format(value: 7.5), "7.5")
        XCTAssertEqual(StreakMetric.distanceMiles.format(value: 5), "5.0")
    }

    /// The integer handed to the catalog is the number on screen, so the plural
    /// category cannot drift from the digits.
    func testDisplayCountMatchesTheDigitsShown() {
        let values: [Double] = [0, 0.4, 1, 1.5, 2.49, 9.95, 10, 10.6, 22, 99.9, 1_234]
        for metric in StreakMetric.allCases {
            for value in values {
                if let count = metric.displayCount(value) {
                    XCTAssertEqual(metric.format(value: value), count.plain, "\(metric) \(value)")
                }
                if let count = metric.displayCount(value, truncating: true) {
                    XCTAssertEqual(metric.formatTruncating(value: value), count.plain, "\(metric) \(value) truncated")
                }
            }
        }
    }

    func testFractionalMetricsTakeTheTextForm() {
        XCTAssertNil(StreakMetric.sleepHours.displayCount(8))
        XCTAssertNil(StreakMetric.intensityRatio.displayCount(8))
        XCTAssertNil(StreakMetric.distanceMiles.displayCount(2.5))
        XCTAssertEqual(StreakMetric.distanceMiles.displayCount(12.4), 12)
        XCTAssertEqual(StreakMetric.steps.displayCount(9_999.6), 10_000)
        XCTAssertEqual(StreakMetric.steps.displayCount(9_999.6, truncating: true), 9_999)
        XCTAssertEqual(StreakMetric.workouts.displayCount(0.5), 0)
    }

    func testTrialSentencesKeepTheirEnglishWording() throws {
        let (en, locale) = try english()
        let n = 7
        let price = "$29.99 / year"
        XCTAssertEqual(String(localized: "\(n)-day free trial, ON US.", bundle: en, locale: locale), "7-day free trial, ON US.")
        XCTAssertEqual(String(localized: "\(n)-month free trial, ON US.", bundle: en, locale: locale), "7-month free trial, ON US.")
        XCTAssertEqual(
            String(localized: "One missed day zeroes it out. Streaks+ auto-saves the run and tracks every streak you've earned, free for your \(n)-day trial.", bundle: en, locale: locale),
            "One missed day zeroes it out. Streaks+ auto-saves the run and tracks every streak you've earned, free for your 7-day trial.")
        XCTAssertEqual(
            String(localized: "Free keeps \(3). Start your \(n)-day free trial to keep the other \(4) and protect every run.", bundle: en, locale: locale),
            "Free keeps 3. Start your 7-day free trial to keep the other 4 and protect every run.")
        XCTAssertEqual(
            String(localized: "Start your \(n)-year free trial to auto-save misses and protect every streak you just found.", bundle: en, locale: locale),
            "Start your 7-year free trial to auto-save misses and protect every streak you just found.")
        XCTAssertEqual(String(localized: "▶ KEEP ALL · START \(n)-day free trial", bundle: en, locale: locale), "▶ KEEP ALL · START 7-day free trial")
        XCTAssertEqual(
            String(localized: "\(n)-Day Free Trial, then \(price). Auto-renews unless canceled at least 24 hours before the trial ends.", bundle: en, locale: locale),
            "7-Day Free Trial, then $29.99 / year. Auto-renews unless canceled at least 24 hours before the trial ends.")
        XCTAssertEqual(
            String(localized: "\(n)-Month Free Trial, then \(price). Renews automatically unless you cancel at least 24 hours before the trial ends.", bundle: en, locale: locale),
            "7-Month Free Trial, then $29.99 / year. Renews automatically unless you cancel at least 24 hours before the trial ends.")
        XCTAssertEqual(String(localized: "Start with \(1) days free. Cancel anytime.", bundle: en, locale: locale), "Start with 1 day free. Cancel anytime.")
        XCTAssertEqual(String(localized: "Start with \(n) days free. Cancel anytime.", bundle: en, locale: locale), "Start with 7 days free. Cancel anytime.")
        XCTAssertEqual(String(localized: "START \(n) DAYS FREE · YEARLY \(price)", bundle: en, locale: locale), "START 7 DAYS FREE · YEARLY $29.99 / year")
    }

    func testBrokenStreakSentencesKeepTheirEnglishWording() throws {
        let (en, locale) = try english()
        let length = 12
        let name = "steps"
        XCTAssertEqual(String(localized: "REVIVE YOUR \(length)-day \(name) streak.", bundle: en, locale: locale), "REVIVE YOUR 12-day steps streak.")
        XCTAssertEqual(String(localized: "REVIVE YOUR \(1)-week \(name) streak.", bundle: en, locale: locale), "REVIVE YOUR 1-week steps streak.")
        XCTAssertEqual(
            String(localized: "Start a Streaks+ trial and we'll restore your \(length)-day \(name) run on the spot. Streaks+ auto-saves every missed day so this doesn't happen again.", bundle: en, locale: locale),
            "Start a Streaks+ trial and we'll restore your 12-day steps run on the spot. Streaks+ auto-saves every missed day so this doesn't happen again.")
        XCTAssertEqual(
            String(localized: "Subscribe to Streaks+ to revive your \(length)-week \(name) streak", bundle: en, locale: locale),
            "Subscribe to Streaks+ to revive your 12-week steps streak")
    }

    func testCadenceCountsInsideSentencesKeepTheirEnglishWording() throws {
        let (en, locale) = try english()
        let name = "Steps"
        let goal = "10000 steps"
        XCTAssertEqual(String(localized: "\(name) streak: \(1) days, threshold \(goal)", bundle: en, locale: locale), "Steps streak: 1 day, threshold 10000 steps")
        XCTAssertEqual(String(localized: "\(name) streak: \(5) weeks", bundle: en, locale: locale), "Steps streak: 5 weeks")
        XCTAssertEqual(String(localized: "\(name), \(1) weeks, \(80) percent completion", bundle: en, locale: locale), "Steps, 1 week, 80 percent completion")
        XCTAssertEqual(String(localized: "\(name) streak: \(9) days in a row, threshold \(goal)", bundle: en, locale: locale), "Steps streak: 9 days in a row, threshold 10000 steps")
    }

    func testOpenAppToSyncHasAKey() throws {
        let (en, locale) = try english()
        XCTAssertEqual(String(localized: "Open app to sync", bundle: en, locale: locale), "Open app to sync")
        let path = try XCTUnwrap(en.path(forResource: "Localizable", ofType: "strings"))
        let table = try XCTUnwrap(NSDictionary(contentsOfFile: path) as? [String: String])
        XCTAssertEqual(table["Open app to sync"], "Open app to sync")
    }

    // MARK: - Stored data

    /// Broken runs persist in UserDefaults and the widget snapshot. The record
    /// keeps its English metric key and numeric length; no translated phrase is
    /// ever stored, so the sentences can be reworded without a migration.
    func testBrokenStreakKeepsItsStoredShape() throws {
        let broken = BrokenStreak(
            key: "steps-daily", metric: .steps, cadence: .daily, threshold: 10_000, hourWindow: nil,
            brokenLength: 12, brokenAt: Date(timeIntervalSinceReferenceDate: 800_000_000),
            missedDate: Date(timeIntervalSinceReferenceDate: 799_900_000))
        let data = try JSONEncoder().encode(broken)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(Set(object.keys), ["key", "metric", "cadence", "threshold", "brokenLength", "brokenAt", "missedDate"])
        XCTAssertEqual(object["metric"] as? String, "steps")
        XCTAssertEqual(object["cadence"] as? String, "daily")
        XCTAssertEqual(object["brokenLength"] as? Int, 12)
        XCTAssertEqual(try JSONDecoder().decode(BrokenStreak.self, from: data), broken)
    }

    func testOlderBrokenStreakRecordsStillDecode() throws {
        let json = """
        {"key":"sleepHours-weekly","metric":"sleepHours","cadence":"weekly","threshold":7.5,
         "brokenLength":4,"brokenAt":790000000.5}
        """
        let broken = try JSONDecoder().decode(BrokenStreak.self, from: Data(json.utf8))
        XCTAssertEqual(broken.metric, .sleepHours)
        XCTAssertEqual(broken.cadence, .weekly)
        XCTAssertEqual(broken.brokenLength, 4)
        XCTAssertNil(broken.missedDate)
    }
}

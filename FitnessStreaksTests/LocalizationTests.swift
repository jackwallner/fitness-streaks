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
        XCTAssertEqual(StreakMetric.steps.thresholdLabel(10_000, cadence: .daily), "10000 steps")
        XCTAssertEqual(StreakMetric.workouts.thresholdLabel(1, cadence: .daily), "any workout")
        XCTAssertEqual(StreakMetric.steps.prose(10_000, cadence: .daily), "10,000+ steps every day")
        XCTAssertEqual(StreakMetric.sleepHours.format(value: 7.5), "7.5")
        XCTAssertEqual(StreakMetric.distanceMiles.format(value: 12.34), "12")
    }
}

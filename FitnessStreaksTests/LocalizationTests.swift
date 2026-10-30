import XCTest

/// The string catalog compiles into one .lproj per language, and the plural
/// rules and argument order survive the trip. A key that fell back to English
/// would still pass a "not empty" check, so these compare against the
/// catalog's own wording.
final class LocalizationTests: XCTestCase {
    static let languages = ["de", "es", "fr", "it", "ja", "nl", "pl", "pt-BR"]

    private func bundle(_ language: String) -> Bundle? {
        let hosts = [Bundle(for: LocalizationTests.self), Bundle.main] + Bundle.allBundles
        for host in hosts {
            if let path = host.path(forResource: language, ofType: "lproj"),
               let bundle = Bundle(path: path) {
                return bundle
            }
        }
        return nil
    }

    func testEveryLanguageShips() {
        for language in Self.languages {
            XCTAssertNotNil(bundle(language), "\(language).lproj is missing")
        }
    }

    func testPolishPluralsPickTheRightForm() throws {
        let pl = try XCTUnwrap(bundle("pl"))
        let locale = Locale(identifier: "pl")
        XCTAssertEqual(String(localized: "\(1) weeks", bundle: pl, locale: locale), "1 tydzień")
        XCTAssertEqual(String(localized: "\(3) weeks", bundle: pl, locale: locale), "3 tygodnie")
        XCTAssertEqual(String(localized: "\(5) weeks", bundle: pl, locale: locale), "5 tygodni")
    }

    func testPluralCategoryFollowsTheLanguage() throws {
        let pl = try XCTUnwrap(bundle("pl"))
        let locale = Locale(identifier: "pl")
        XCTAssertEqual(String(localized: "\(3) plural category", bundle: pl, locale: locale), "few 3")
        XCTAssertEqual(String(localized: "\(5) plural category", bundle: pl, locale: locale), "many 5")
        let de = try XCTUnwrap(bundle("de"))
        XCTAssertEqual(String(localized: "\(1) plural category", bundle: de, locale: Locale(identifier: "de")), "one 1")
    }

    func testSubstitutionKeepsArgumentOrder() throws {
        let de = try XCTUnwrap(bundle("de"))
        let locale = Locale(identifier: "de")
        let name = "Schritte"
        XCTAssertEqual(String(localized: "Your \(name) run ended at \(5) days.", bundle: de, locale: locale),
                       "Deine Schritte-Serie endete nach 5 Tagen.")
        XCTAssertEqual(String(localized: "Your \(name) run ended at \(1) days.", bundle: de, locale: locale),
                       "Deine Schritte-Serie endete nach 1 Tag.")
    }

    func testCopyIsTranslated() throws {
        let de = try XCTUnwrap(bundle("de"))
        XCTAssertEqual(String(localized: "▶ GET STARTED", bundle: de), "▶ LOS GEHT'S")
        XCTAssertEqual(String(localized: "\(7) DAYS FREE", bundle: de, locale: Locale(identifier: "de")), "7 TAGE GRATIS")
        let ja = try XCTUnwrap(bundle("ja"))
        XCTAssertEqual(String(localized: "\(12) days", bundle: ja, locale: Locale(identifier: "ja")), "12日")
        let ptBR = try XCTUnwrap(bundle("pt-BR"))
        XCTAssertEqual(String(localized: "Streaks+ auto-saves every missed day.", bundle: ptBR),
                       "O Streaks+ resgata cada dia perdido.")
    }
}

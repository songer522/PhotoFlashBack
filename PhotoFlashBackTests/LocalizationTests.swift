import XCTest
@testable import PhotoFlashBack

/// Issue #19: month names and dates come from locale-aware system formatters (on the Gregorian
/// memory calendar), and user-facing text lives in the String Catalogs.
final class LocalizationTests: XCTestCase {
    private let english = Locale(identifier: "en_US")
    private let french = Locale(identifier: "fr_FR")

    // MARK: - Date locale

    func testUserLocaleTakesLanguageFromPreferredLanguages() {
        // With only English strings, iOS hands the app "en_FR" on a French device.
        let locale = MemoryDateText.userLocale(preferredLanguages: ["fr-FR", "en-US"], current: Locale(identifier: "en_FR"))
        XCTAssertEqual(locale.language.languageCode, .french)
        XCTAssertEqual(locale.region, .france)
        XCTAssertEqual(MemoryDateText.dayMonth(month: 11, day: 18, locale: locale), "18 novembre")
    }

    func testUserLocaleFallsBackToCurrentWithoutPreferredLanguages() {
        let current = Locale(identifier: "en_GB")
        XCTAssertEqual(MemoryDateText.userLocale(preferredLanguages: [], current: current), current)
    }

    // MARK: - Month symbols (date picker)

    func testMonthSymbolsAreEnglishForEnglishLocale() {
        XCTAssertEqual(MemoryDateText.monthSymbols(locale: english), [
            "January", "February", "March", "April", "May", "June",
            "July", "August", "September", "October", "November", "December"
        ])
    }

    func testMonthSymbolsAreFrenchForFrenchLocale() {
        let symbols = MemoryDateText.monthSymbols(locale: french)
        XCTAssertEqual(symbols.count, 12)
        XCTAssertEqual(symbols.first?.lowercased(), "janvier")
        XCTAssertEqual(symbols[7].lowercased(), "août")
    }

    func testMonthSymbolsStayGregorianWhenLocaleUsesAnotherCalendar() {
        // Memory dates are Gregorian month/day pairs, so a Hebrew-calendar locale must still
        // label month 1 as January, not Tishri.
        let symbols = MemoryDateText.monthSymbols(locale: Locale(identifier: "en_US@calendar=hebrew"))
        XCTAssertEqual(symbols.count, 12)
        XCTAssertEqual(symbols.first, "January")
    }

    // MARK: - Day and month text (grid header, empty states)

    func testDayMonthIsEnglishForEnglishLocale() {
        XCTAssertEqual(MemoryDateText.dayMonth(month: 1, day: 5, locale: english), "January 5")
    }

    func testDayMonthUsesFrenchWordsAndOrder() {
        XCTAssertEqual(MemoryDateText.dayMonth(month: 1, day: 5, locale: french), "5 janvier")
    }

    func testDayMonthFormatsLeapDay() {
        XCTAssertEqual(MemoryDateText.dayMonth(month: 2, day: 29, locale: english), "February 29")
    }

    func testDayMonthIsNilForInvalidMonth() {
        XCTAssertNil(MemoryDateText.dayMonth(month: 13, day: 1, locale: english))
    }

    @MainActor
    func testDisplayDateFollowsLocale() {
        let viewModel = PhotosViewModel()
        viewModel.month = 10
        viewModel.day = 27
        XCTAssertEqual(viewModel.displayDate(locale: english), "October 27")
        XCTAssertEqual(viewModel.displayDate(locale: french), "27 octobre")
    }

    @MainActor
    func testDisplayDateRejectsInvalidMonth() {
        let viewModel = PhotosViewModel()
        viewModel.month = 0
        XCTAssertEqual(viewModel.displayDate(locale: english), "Invalid Date")
    }

    // MARK: - Reminder notification body

    func testReminderBodyUsesLocalizedShortDate() {
        let body = MemoryReminderPlanner.body(count: 3, month: 9, day: 5, locale: french)
        XCTAssertTrue(body.contains("5 sept"), body)
        XCTAssertFalse(body.contains("Sep 5"), body)
    }

    // MARK: - String Catalogs

    // English-base entries without explicit values compile to nothing (the key is the English
    // text), so check the source catalogs rather than the built bundle.
    private func catalogKeys(_ relativePath: String) throws -> [String: Any] {
        let repoRoot = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        let data = try Data(contentsOf: repoRoot.appendingPathComponent(relativePath))
        let json = try XCTUnwrap(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(json["sourceLanguage"] as? String, "en")
        return try XCTUnwrap(json["strings"] as? [String: Any])
    }

    func testAppCatalogHoldsUserFacingStrings() throws {
        let strings = try catalogKeys("PhotoFlashBack/Localizable.xcstrings")
        for key in ["Settings", "No Photos on This Day", "Delete Photo", "Organizing memories...",
                    "Loading photos... %lld/%lld", "Found %lld photos", "📸 %lld memories from %@"] {
            XCTAssertNotNil(strings[key], "\(key) is not in the app's Localizable.xcstrings")
        }
    }

    func testReminderBodyPluralComesFromCatalog() {
        XCTAssertEqual(MemoryReminderPlanner.body(count: 1, month: 10, day: 27, locale: english), "📸 1 memory from Oct 27")
        XCTAssertEqual(MemoryReminderPlanner.body(count: 2, month: 10, day: 27, locale: english), "📸 2 memories from Oct 27")
    }

    func testWidgetCatalogHoldsWidgetStrings() throws {
        let strings = try catalogKeys("TodayWidget/Localizable.xcstrings")
        for key in ["On this day", "No memories", "Memory from %@", "Loading memories...", "Rewind: Today's Memories"] {
            XCTAssertNotNil(strings[key], "\(key) is not in the widget's Localizable.xcstrings")
        }
    }

    func testPhotoLibraryUsageDescriptionIsInInfoPlistCatalog() throws {
        let strings = try catalogKeys("PhotoFlashBack/InfoPlist.xcstrings")
        XCTAssertNotNil(strings["NSPhotoLibraryUsageDescription"])
        XCTAssertNotNil(strings["CFBundleDisplayName"])
    }
}

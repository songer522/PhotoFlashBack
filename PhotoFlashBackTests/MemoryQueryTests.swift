import XCTest
import Photos
@testable import PhotoFlashBack

final class MemoryQueryTests: XCTestCase {
    private let calendar = Calendar(identifier: .gregorian)
    private let unfiltered = MediaFilter(photos: true, videos: true, screenshots: true)

    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 10) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }

    func testMatchesSameMonthDayAnyYear() {
        XCTAssertTrue(MemoryQuery.isMemory(creationDate: date(2019, 10, 27), kind: .photo, month: 10, day: 27, filter: unfiltered, calendar: calendar))
    }

    func testRejectsOtherDay() {
        XCTAssertFalse(MemoryQuery.isMemory(creationDate: date(2019, 10, 28), kind: .photo, month: 10, day: 27, filter: unfiltered, calendar: calendar))
        XCTAssertFalse(MemoryQuery.isMemory(creationDate: nil, kind: .photo, month: 10, day: 27, filter: unfiltered, calendar: calendar))
    }

    func testFilterExcludingKindRejects() {
        let videosOnly = MediaFilter(photos: false, videos: true, screenshots: false)
        XCTAssertFalse(MemoryQuery.isMemory(creationDate: date(2019, 10, 27), kind: .photo, month: 10, day: 27, filter: videosOnly, calendar: calendar))
        XCTAssertTrue(MemoryQuery.isMemory(creationDate: date(2019, 10, 27), kind: .video, month: 10, day: 27, filter: videosOnly, calendar: calendar))
    }

    func testAllOffFilterIsUnfiltered() {
        let allOff = MediaFilter(photos: false, videos: false, screenshots: false)
        XCTAssertTrue(MemoryQuery.isMemory(creationDate: date(2019, 10, 27), kind: .screenshot, month: 10, day: 27, filter: allOff, calendar: calendar))
    }

    func testDayKeyUsesCalendarMonthAndDay() {
        XCTAssertEqual(MemoryQuery.dayKey(creationDate: date(2019, 10, 27), calendar: calendar), MemoryQuery.DayKey(month: 10, day: 27))
        XCTAssertNil(MemoryQuery.dayKey(creationDate: nil, calendar: calendar))
    }

    func testDayKeySkipsExactMidnightLikeTheGridPredicate() {
        // The grid's per-year range is (startOfDay, nextStartOfDay], so a photo stamped exactly
        // at midnight is never shown; the batched counter must agree.
        XCTAssertNil(MemoryQuery.dayKey(creationDate: date(2019, 10, 27, 0), calendar: calendar))
        XCTAssertNotNil(MemoryQuery.dayKey(creationDate: date(2019, 10, 27, 0).addingTimeInterval(1), calendar: calendar))
    }

    func testWindowRangesUseGregorianYearsWhateverTheDeviceCalendar() {
        var buddhist = Calendar(identifier: .buddhist)
        buddhist.timeZone = TimeZone(identifier: "America/Chicago")!
        var gregorian = Calendar(identifier: .gregorian)
        gregorian.timeZone = buddhist.timeZone
        let start = gregorian.date(from: DateComponents(year: 2026, month: 10, day: 26))!

        let ranges = MemoryQuery.windowRanges(from: start, days: 31, years: 1990...2030, timeZone: buddhist.timeZone)

        let october2020 = gregorian.date(from: DateComponents(year: 2020, month: 10, day: 27, hour: 12))!
        XCTAssertTrue(ranges.contains { $0.from < october2020 && october2020 <= $0.to })
        XCTAssertEqual(ranges.count, 2030 - 1990 + 1)
    }

    func testDefaultGridMatchingAgreesWithTheCounterEvenWhereHebrewMonthDayDiffers() {
        // Oct 27, 2020 is 9 Heshvan 5781 in the Hebrew calendar. The counter groups it under 10/27,
        // so the grid's default matching must accept it for 10/27 too, or a reminder would
        // advertise memories the grid then hides.
        let memoryDate = MemoryQuery.memoryCalendar().date(from: DateComponents(year: 2020, month: 10, day: 27, hour: 12))!
        var hebrew = Calendar(identifier: .hebrew)
        hebrew.timeZone = .current
        XCTAssertNotEqual(hebrew.dateComponents([.month, .day], from: memoryDate), DateComponents(month: 10, day: 27))

        XCTAssertEqual(MemoryQuery.dayKey(creationDate: memoryDate), MemoryQuery.DayKey(month: 10, day: 27))
        XCTAssertTrue(MemoryQuery.isMemory(creationDate: memoryDate, kind: .photo, month: 10, day: 27, filter: unfiltered))
        XCTAssertFalse(MemoryQuery.isMemory(creationDate: memoryDate, kind: .photo, month: 10, day: 27, filter: unfiltered, calendar: hebrew))
    }

    func testWrappedWindowRangesCoverExactlyTheGridYears() {
        let calendar = MemoryQuery.memoryCalendar()
        func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
            calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12))!
        }
        let ranges = MemoryQuery.windowRanges(from: date(2026, 12, 20), days: 31, years: 1990...2060)
        func covered(_ date: Date) -> Bool { ranges.contains { $0.from < date && date <= $0.to } }

        XCTAssertTrue(covered(date(1990, 1, 5)))
        XCTAssertTrue(covered(date(2060, 12, 25)))
        XCTAssertFalse(covered(date(1989, 12, 25)))
        XCTAssertFalse(covered(date(2061, 1, 5)))
    }

    // MARK: - Year range (issue #16)

    func testYearRangeSpansOldestAssetToNextYear() {
        let calendar = MemoryQuery.memoryCalendar()
        func date(_ year: Int) -> Date { calendar.date(from: DateComponents(year: year, month: 6, day: 1, hour: 12))! }
        let range = MemoryQuery.yearRange(oldest: date(2003), newest: date(2025), now: date(2026), calendar: calendar)
        XCTAssertEqual(range, 2003...2027)
    }

    func testYearRangeReachesFutureTimestampsInTheLibrary() {
        let calendar = MemoryQuery.memoryCalendar()
        func date(_ year: Int) -> Date { calendar.date(from: DateComponents(year: year, month: 6, day: 1, hour: 12))! }
        let range = MemoryQuery.yearRange(oldest: date(2003), newest: date(2063), now: date(2026), calendar: calendar)
        XCTAssertEqual(range, 2003...2063)
    }

    func testYearRangeForEmptyLibraryIsThisYearAndNext() {
        let calendar = MemoryQuery.memoryCalendar()
        let now = calendar.date(from: DateComponents(year: 2026, month: 6, day: 1, hour: 12))!
        XCTAssertEqual(MemoryQuery.yearRange(oldest: nil, newest: nil, now: now, calendar: calendar), 2026...2027)
    }

    func testYearRangeBoundsAbsurdTimestampsSoThePredicateStaysSmall() {
        let calendar = MemoryQuery.memoryCalendar()
        func date(_ year: Int) -> Date { calendar.date(from: DateComponents(year: year, month: 6, day: 1, hour: 12))! }
        let range = MemoryQuery.yearRange(oldest: date(1), newest: date(9999), now: date(2026), calendar: calendar)
        XCTAssertEqual(range, (2026 - MemoryQuery.maxYearsBack)...(2026 + MemoryQuery.maxYearsAhead))
    }

    func testDayRangesCoverEveryYearInTheRangeWithTheMidnightBoundary() {
        let calendar = MemoryQuery.memoryCalendar()
        let ranges = MemoryQuery.dayRanges(month: 10, day: 27, years: 2000...2060)
        XCTAssertEqual(ranges.count, 61)
        let start2055 = calendar.date(from: DateComponents(year: 2055, month: 10, day: 27))!
        func covered(_ date: Date) -> Bool { ranges.contains { $0.from < date && date <= $0.to } }
        XCTAssertFalse(covered(start2055))
        XCTAssertTrue(covered(start2055.addingTimeInterval(1)))
        XCTAssertTrue(covered(calendar.date(byAdding: .day, value: 1, to: start2055)!))
        XCTAssertFalse(covered(calendar.date(byAdding: .day, value: 1, to: start2055)!.addingTimeInterval(1)))
    }

    func testDayRangesSkipFebruary29InCommonYears() {
        let ranges = MemoryQuery.dayRanges(month: 2, day: 29, years: 2019...2024)
        XCTAssertEqual(ranges.count, 2) // 2020 and 2024
    }

    func testFetchOptionsMatchesPhotosPastTheOldYearCeiling() {
        let calendar = MemoryQuery.memoryCalendar()
        let options = MemoryQuery.fetchOptions(month: 10, day: 27, years: 2000...2060)
        let photo2055 = calendar.date(from: DateComponents(year: 2055, month: 10, day: 27, hour: 12))!
        let otherDay = calendar.date(from: DateComponents(year: 2055, month: 10, day: 28, hour: 12))!
        let image = PHAssetMediaType.image.rawValue
        XCTAssertTrue(options.predicate!.evaluate(with: ["creationDate": photo2055, "mediaType": image] as NSDictionary))
        XCTAssertFalse(options.predicate!.evaluate(with: ["creationDate": otherDay, "mediaType": image] as NSDictionary))
    }

    // MARK: - Widget selection (issue #16)

    func testWidgetYearAcceptsPastPhotosOnTheDay() {
        let calendar = MemoryQuery.memoryCalendar()
        let photo = calendar.date(from: DateComponents(year: 2019, month: 10, day: 27, hour: 12))!
        XCTAssertEqual(MemoryQuery.widgetYear(creationDate: photo, kind: .photo, month: 10, day: 27, currentYear: 2026, calendar: calendar), 2019)
    }

    func testWidgetYearRejectsScreenshotsVideosThisYearAndOtherDays() {
        let calendar = MemoryQuery.memoryCalendar()
        func date(_ year: Int, _ day: Int) -> Date { calendar.date(from: DateComponents(year: year, month: 10, day: day, hour: 12))! }
        XCTAssertNil(MemoryQuery.widgetYear(creationDate: date(2019, 27), kind: .screenshot, month: 10, day: 27, currentYear: 2026, calendar: calendar))
        XCTAssertNil(MemoryQuery.widgetYear(creationDate: date(2019, 27), kind: .video, month: 10, day: 27, currentYear: 2026, calendar: calendar))
        XCTAssertNil(MemoryQuery.widgetYear(creationDate: date(2026, 27), kind: .photo, month: 10, day: 27, currentYear: 2026, calendar: calendar))
        XCTAssertNil(MemoryQuery.widgetYear(creationDate: date(2019, 28), kind: .photo, month: 10, day: 27, currentYear: 2026, calendar: calendar))
        XCTAssertNil(MemoryQuery.widgetYear(creationDate: nil, kind: .photo, month: 10, day: 27, currentYear: 2026, calendar: calendar))
    }

    func testMemoryCalendarIsGregorianInTheGivenTimeZone() {
        let zone = TimeZone(identifier: "Asia/Tokyo")!
        let calendar = MemoryQuery.memoryCalendar(timeZone: zone)
        XCTAssertEqual(calendar.identifier, .gregorian)
        XCTAssertEqual(calendar.timeZone, zone)
    }
}

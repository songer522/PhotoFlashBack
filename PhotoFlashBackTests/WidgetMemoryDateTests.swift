import XCTest
@testable import PhotoFlashBack

/// `WidgetMemoryDate` lives in the widget target and is compiled into this test bundle directly
/// (the widget extension can't be imported). Each test plays a device whose `Calendar.current` is
/// not Gregorian and checks that the widget still agrees with the app's Gregorian memory dates.
final class WidgetMemoryDateTests: XCTestCase {
    private let zone = TimeZone(identifier: "America/Los_Angeles")!

    private func gregorianDate(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 10) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone
        return calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }

    private func deviceCalendar(_ identifier: Calendar.Identifier) -> Calendar {
        var calendar = Calendar(identifier: identifier)
        calendar.timeZone = zone
        return calendar
    }

    private let nonGregorian: [Calendar.Identifier] = [.hebrew, .islamicUmmAlQura, .persian, .buddhist, .japanese]

    func testSameGregorianMonthDayIsTodayOnNonGregorianDevice() {
        let photo = gregorianDate(2020, 11, 17)
        let today = gregorianDate(2026, 11, 17, 8)
        for identifier in nonGregorian {
            XCTAssertTrue(
                WidgetMemoryDate.isEntry(creationDate: photo, forDay: today, deviceCalendar: deviceCalendar(identifier)),
                "\(identifier) device threw out a photo from the same Gregorian day"
            )
        }
    }

    func testOtherGregorianDayIsStaleOnNonGregorianDevice() {
        let photo = gregorianDate(2020, 11, 18)
        let today = gregorianDate(2026, 11, 17)
        for identifier in nonGregorian {
            XCTAssertFalse(
                WidgetMemoryDate.isEntry(creationDate: photo, forDay: today, deviceCalendar: deviceCalendar(identifier)),
                "\(identifier) device kept a photo from another Gregorian day"
            )
        }
    }

    /// Same Hebrew month/day in another year falls on a different Gregorian day, so the app never
    /// stored it for today and the widget must treat it as stale.
    func testSameHebrewMonthDayButOtherGregorianDayIsStale() {
        let hebrew = deviceCalendar(.hebrew)
        let photo = gregorianDate(2020, 11, 17)
        let hebrewPhoto = hebrew.dateComponents([.year, .month, .day], from: photo)
        let today = hebrew.date(from: DateComponents(year: hebrewPhoto.year! + 6, month: hebrewPhoto.month, day: hebrewPhoto.day, hour: 10))!
        XCTAssertNotEqual(gregorianDate(2026, 11, 17), today, "test setup: Hebrew date should land on another Gregorian day")

        XCTAssertFalse(WidgetMemoryDate.isEntry(creationDate: photo, forDay: today, deviceCalendar: hebrew))
    }

    func testDayBoundaryUsesDeviceTimeZone() {
        // 23:30 on Nov 16 in Los Angeles is already Nov 17 in UTC; the device zone decides.
        let photo = gregorianDate(2020, 11, 16, 23)
        let today = gregorianDate(2026, 11, 16, 9)
        XCTAssertTrue(WidgetMemoryDate.isEntry(creationDate: photo, forDay: today, deviceCalendar: deviceCalendar(.hebrew)))
        XCTAssertFalse(WidgetMemoryDate.isEntry(creationDate: photo, forDay: gregorianDate(2026, 11, 17), deviceCalendar: deviceCalendar(.hebrew)))
    }

    func testYearLabelIsGregorianOnNonGregorianDevice() {
        let photo = gregorianDate(2020, 11, 17)
        for identifier in nonGregorian {
            XCTAssertEqual(WidgetMemoryDate.yearLabel(for: photo, deviceCalendar: deviceCalendar(identifier)), "2020", "\(identifier)")
        }
    }

    func testNextRefreshIsNextGregorianMidnightInDeviceZone() {
        let now = gregorianDate(2026, 11, 17, 15)
        let midnight = gregorianDate(2026, 11, 18, 0)
        for identifier in nonGregorian {
            XCTAssertEqual(WidgetMemoryDate.nextRefresh(after: now, deviceCalendar: deviceCalendar(identifier)), midnight, "\(identifier)")
        }
    }

    func testMemoryCalendarIsGregorianInGivenZone() {
        let calendar = WidgetMemoryDate.memoryCalendar(timeZone: zone)
        XCTAssertEqual(calendar.identifier, .gregorian)
        XCTAssertEqual(calendar.timeZone, zone)
    }

    /// The widget's copy must stay in step with the app's `MemoryQuery.memoryCalendar`.
    func testMemoryCalendarMatchesApp() {
        XCTAssertEqual(WidgetMemoryDate.memoryCalendar(timeZone: zone), MemoryQuery.memoryCalendar(timeZone: zone))
    }
}

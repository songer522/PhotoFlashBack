import XCTest
@testable import PhotoFlashBack

final class MemoryReminderPlannerTests: XCTestCase {
    private var calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        return c
    }()
    private let nine = MemoryReminderSettings(enabled: true, hour: 9, minute: 0)

    private func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int, _ min: Int, _ s: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: y, month: m, day: d, hour: h, minute: min, second: s))!
    }

    private func plan(_ now: Date, settings: MemoryReminderSettings? = nil,
                      count: @escaping (Int, Int) -> Int = { _, _ in 1 }) -> [PlannedReminder] {
        MemoryReminderPlanner.plan(now: now, calendar: calendar, settings: settings ?? nine, count: count)
    }

    func testDisabledReturnsEmpty() {
        let off = MemoryReminderSettings(enabled: false, hour: 9, minute: 0)
        XCTAssertEqual(plan(date(2026, 10, 26, 8, 0), settings: off), [])
    }

    func testSkipsZeroCountDays() {
        let result = plan(date(2026, 10, 26, 8, 0)) { m, d in (m == 10 && d == 28) ? 0 : 5 }
        XCTAssertFalse(result.contains { $0.month == 10 && $0.day == 28 })
        XCTAssertTrue(result.contains { $0.identifier == "memory-2026-10-26" })
        XCTAssertTrue(result.contains { $0.identifier == "memory-2026-10-27" })
    }

    func testStartsTodayWhenTimeAhead() {
        XCTAssertEqual(plan(date(2026, 10, 26, 8, 59)).first?.identifier, "memory-2026-10-26")
    }

    func testStartsTomorrowWhenTimePassed() {
        XCTAssertEqual(plan(date(2026, 10, 26, 9, 1)).first?.identifier, "memory-2026-10-27")
    }

    func testTimeEqualToNowStartsTomorrow() {
        XCTAssertEqual(plan(date(2026, 10, 26, 9, 0, 0)).first?.identifier, "memory-2026-10-27")
    }

    func testWindowCappedAt30AndThumbnailsOnFirst3Planned() {
        for now in [date(2026, 10, 26, 8, 0), date(2026, 10, 26, 10, 0)] {
            let result = plan(now)
            XCTAssertEqual(result.count, 30)
            XCTAssertEqual(result.map { $0.wantsThumbnail }.enumerated().filter { $0.element }.map { $0.offset }, [0, 1, 2])
        }
        let start = date(2026, 10, 26, 8, 0)
        let skipFirstTwo = plan(start) { m, d in (m == 10 && (d == 26 || d == 27)) ? 0 : 1 }
        XCTAssertEqual(skipFirstTwo.count, 28)
        XCTAssertEqual(skipFirstTwo.map { $0.wantsThumbnail }.enumerated().filter { $0.element }.map { $0.offset }, [0, 1, 2])
        XCTAssertEqual(skipFirstTwo.first?.identifier, "memory-2026-10-28")
    }

    func testFeb29OnlyInLeapYears() {
        XCTAssertFalse(plan(date(2027, 2, 20, 8, 0)).contains { $0.identifier == "memory-2027-02-29" })
        let leap = plan(date(2028, 2, 20, 8, 0)).first { $0.identifier == "memory-2028-02-29" }
        XCTAssertEqual(leap?.month, 2)
        XCTAssertEqual(leap?.day, 29)
    }

    func testYearWraparound() {
        let result = plan(date(2026, 12, 30, 10, 0))
        XCTAssertEqual(result.first { $0.identifier == "memory-2026-12-31" }?.fireDateComponents.year, 2026)
        XCTAssertEqual(result.first { $0.identifier == "memory-2027-01-01" }?.fireDateComponents.year, 2027)
    }

    func testDSTKeepsWallClockTime() {
        let result = plan(date(2026, 3, 5, 10, 0))
        XCTAssertTrue(result.contains { $0.identifier == "memory-2026-03-08" })
        XCTAssertTrue(result.contains { $0.identifier == "memory-2026-03-09" })
        for r in result {
            XCTAssertEqual(r.fireDateComponents.hour, 9)
            XCTAssertEqual(r.fireDateComponents.minute, 0)
        }
    }

    func testFireComponentsUseChosenTime() {
        let s = MemoryReminderSettings(enabled: true, hour: 21, minute: 45)
        let result = plan(date(2026, 10, 26, 8, 0), settings: s)
        XCTAssertFalse(result.isEmpty)
        for r in result {
            XCTAssertEqual(r.fireDateComponents.hour, 21)
            XCTAssertEqual(r.fireDateComponents.minute, 45)
        }
    }

    func testIdentifiersUniqueAndFormatted() {
        let ids = plan(date(2026, 10, 26, 8, 0)).map { $0.identifier }
        XCTAssertEqual(Set(ids).count, ids.count)
        for id in ids {
            XCTAssertNotNil(id.range(of: #"^memory-\d{4}-\d{2}-\d{2}$"#, options: .regularExpression), id)
        }
    }

    func testBodyCopy() {
        XCTAssertEqual(MemoryReminderPlanner.body(count: 24, month: 10, day: 27), "📸 24 memories from Oct 27")
        XCTAssertEqual(MemoryReminderPlanner.body(count: 1, month: 10, day: 27), "📸 1 memory from Oct 27")
        XCTAssertEqual(MemoryReminderPlanner.body(count: 3, month: 9, day: 5), "📸 3 memories from Sep 5")
    }
}

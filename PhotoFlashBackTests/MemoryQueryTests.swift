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
}

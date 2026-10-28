import XCTest
@testable import PhotoFlashBack

final class PendingMemoryDateTests: XCTestCase {
    private var defaults: UserDefaults!
    private let monthKey = MemoryReminderScheduler.monthKey
    private let dayKey = MemoryReminderScheduler.dayKey

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: "PendingMemoryDateTests.\(UUID().uuidString)")
    }

    override func tearDown() {
        defaults.removeObject(forKey: PendingMemoryDate.key)
        defaults = nil
        super.tearDown()
    }

    func testParsesValidUserInfo() {
        let parsed = PendingMemoryDate.parse(userInfo: [monthKey: 10, dayKey: 27])
        XCTAssertEqual(parsed?.month, 10)
        XCTAssertEqual(parsed?.day, 27)
    }

    func testRejectsMissingOrMalformed() {
        XCTAssertNil(PendingMemoryDate.parse(userInfo: [:]))
        XCTAssertNil(PendingMemoryDate.parse(userInfo: [monthKey: "10", dayKey: 27]))
        XCTAssertNil(PendingMemoryDate.parse(userInfo: [monthKey: 13, dayKey: 1]))
        XCTAssertNil(PendingMemoryDate.parse(userInfo: [monthKey: 2, dayKey: 30]))
        XCTAssertNil(PendingMemoryDate.parse(userInfo: [monthKey: 4, dayKey: 31]))
        XCTAssertNil(PendingMemoryDate.parse(userInfo: [monthKey: 0, dayKey: 1]))
        XCTAssertNil(PendingMemoryDate.parse(userInfo: [monthKey: 1, dayKey: 0]))
        let leapDay = PendingMemoryDate.parse(userInfo: [monthKey: 2, dayKey: 29])
        XCTAssertEqual(leapDay?.month, 2)
        XCTAssertEqual(leapDay?.day, 29)
    }

    func testTakeClears() {
        PendingMemoryDate.store(month: 10, day: 27, in: defaults)
        let first = PendingMemoryDate.take(from: defaults)
        XCTAssertEqual(first?.month, 10)
        XCTAssertEqual(first?.day, 27)
        XCTAssertNil(PendingMemoryDate.take(from: defaults))
    }

    func testTakeRejectsAndClearsGarbage() {
        defaults.set(["month": 13, "day": 1], forKey: PendingMemoryDate.key)
        XCTAssertNil(PendingMemoryDate.take(from: defaults))
        XCTAssertNil(defaults.object(forKey: PendingMemoryDate.key))
        defaults.set("nonsense", forKey: PendingMemoryDate.key)
        XCTAssertNil(PendingMemoryDate.take(from: defaults))
        XCTAssertNil(defaults.object(forKey: PendingMemoryDate.key))
    }
}

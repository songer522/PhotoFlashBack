import XCTest
import UserNotifications
@testable import PhotoFlashBack

/// Models the live pending set: remove deletes, add inserts.
private final class FakeCenter: NotificationScheduling, @unchecked Sendable {
    private let lock = NSLock()
    private var pending: Set<String>
    private var removedLog: [String] = []
    private var added: [UNNotificationRequest] = []
    private var authorizationChecks = 0

    let authorized: Bool
    /// Delays the first `isAuthorized()` call so a second refresh can start while the first is in flight.
    let firstAuthorizationDelayNanoseconds: UInt64
    let onFirstAuthorizationCheck: (@Sendable () -> Void)?

    init(pending: [String] = ["memory-2026-10-20", "other-123"],
         authorized: Bool = true,
         firstAuthorizationDelayNanoseconds: UInt64 = 0,
         onFirstAuthorizationCheck: (@Sendable () -> Void)? = nil) {
        self.pending = Set(pending)
        self.authorized = authorized
        self.firstAuthorizationDelayNanoseconds = firstAuthorizationDelayNanoseconds
        self.onFirstAuthorizationCheck = onFirstAuthorizationCheck
    }

    var pendingSet: Set<String> { lock.withLock { pending } }
    var removed: [String] { lock.withLock { removedLog } }
    var addedRequests: [UNNotificationRequest] { lock.withLock { added } }

    func isAuthorized() async -> Bool {
        let isFirst: Bool = lock.withLock {
            authorizationChecks += 1
            return authorizationChecks == 1
        }
        if isFirst {
            onFirstAuthorizationCheck?()
            if firstAuthorizationDelayNanoseconds > 0 {
                try? await Task.sleep(nanoseconds: firstAuthorizationDelayNanoseconds)
            }
        }
        return authorized
    }

    func pendingIdentifiers() async -> [String] {
        lock.withLock { Array(pending) }
    }

    func remove(identifiers: [String]) {
        lock.withLock {
            removedLog.append(contentsOf: identifiers)
            identifiers.forEach { pending.remove($0) }
        }
    }

    func add(_ request: UNNotificationRequest) async throws {
        lock.withLock {
            added.append(request)
            pending.insert(request.identifier)
        }
    }
}

private final class SettingsBox: @unchecked Sendable {
    private let lock = NSLock()
    private var value: MemoryReminderSettings
    init(_ value: MemoryReminderSettings) { self.value = value }
    func get() -> MemoryReminderSettings { lock.withLock { value } }
    func set(_ newValue: MemoryReminderSettings) { lock.withLock { value = newValue } }
}

final class MemoryReminderSchedulerTests: XCTestCase {
    private var calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        return c
    }()
    private let enabled = MemoryReminderSettings(enabled: true, hour: 9, minute: 0)
    private let disabled = MemoryReminderSettings(enabled: false, hour: 9, minute: 0)

    private var now: Date {
        calendar.date(from: DateComponents(year: 2026, month: 10, day: 26, hour: 8, minute: 0))!
    }

    private func makeScheduler(center: FakeCenter, settings: SettingsBox) -> MemoryReminderScheduler {
        let fixedNow = now
        return MemoryReminderScheduler(
            center: center,
            settings: { settings.get() },
            makeCounter: { _, _ in { _, _ in 2 } },
            thumbnail: { _ in nil },
            now: { fixedNow },
            calendar: calendar
        )
    }

    func testDisabledRemovesOnlyMemoryRequests() async {
        let center = FakeCenter()
        let scheduler = makeScheduler(center: center, settings: SettingsBox(disabled))
        await scheduler.refresh()
        XCTAssertEqual(center.removed, ["memory-2026-10-20"])
        XCTAssertTrue(center.addedRequests.isEmpty)
        XCTAssertEqual(center.pendingSet, ["other-123"])
    }

    func testUnauthorizedRemovesAndAddsNothing() async {
        let center = FakeCenter(authorized: false)
        let scheduler = makeScheduler(center: center, settings: SettingsBox(enabled))
        await scheduler.refresh()
        XCTAssertEqual(center.removed, ["memory-2026-10-20"])
        XCTAssertTrue(center.addedRequests.isEmpty)
        XCTAssertEqual(center.pendingSet, ["other-123"])
    }

    func testEnabledReplacesWithPlan() async throws {
        let center = FakeCenter()
        let scheduler = makeScheduler(center: center, settings: SettingsBox(enabled))
        await scheduler.refresh()

        XCTAssertEqual(center.removed, ["memory-2026-10-20"])
        XCTAssertEqual(center.addedRequests.count, 30)
        XCTAssertTrue(center.pendingSet.contains("other-123"))
        XCTAssertFalse(center.pendingSet.contains("memory-2026-10-20"))

        let first = try XCTUnwrap(center.addedRequests.first)
        XCTAssertEqual(first.identifier, "memory-2026-10-26")
        XCTAssertEqual(first.content.body, "📸 2 memories from Oct 26")
        XCTAssertEqual(first.content.userInfo[MemoryReminderScheduler.monthKey] as? Int, 10)
        XCTAssertEqual(first.content.userInfo[MemoryReminderScheduler.dayKey] as? Int, 26)
        let trigger = try XCTUnwrap(first.trigger as? UNCalendarNotificationTrigger)
        XCTAssertFalse(trigger.repeats)
        XCTAssertEqual(trigger.dateComponents.hour, 9)
    }

    func testToggleOnThenOffLeavesNothingPending() async {
        let started = expectation(description: "first refresh reached the authorization check")
        let center = FakeCenter(
            firstAuthorizationDelayNanoseconds: 200_000_000,
            onFirstAuthorizationCheck: { started.fulfill() }
        )
        let box = SettingsBox(enabled)
        let scheduler = makeScheduler(center: center, settings: box)

        let first = Task { await scheduler.refresh() }
        await fulfillment(of: [started], timeout: 5)
        box.set(disabled)
        let second = Task { await scheduler.refresh() }
        await first.value
        await second.value

        XCTAssertTrue(center.pendingSet.filter { $0.hasPrefix(MemoryReminderPlanner.identifierPrefix) }.isEmpty)
        XCTAssertTrue(center.pendingSet.contains("other-123"))
    }
}

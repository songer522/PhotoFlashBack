import XCTest
@testable import PhotoFlashBack

final class MemoryReminderSettingsTests: XCTestCase {
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: "MemoryReminderSettingsTests.\(UUID().uuidString)")
    }

    override func tearDown() {
        [MemoryReminderSettingsStore.enabledKey, MemoryReminderSettingsStore.hourKey, MemoryReminderSettingsStore.minuteKey].forEach {
            defaults.removeObject(forKey: $0)
        }
        defaults = nil
        super.tearDown()
    }

    func testMissingKeysLoadDefaults() {
        let settings = MemoryReminderSettingsStore.load(from: defaults)
        XCTAssertEqual(settings, .default)
        XCTAssertFalse(settings.enabled)
        XCTAssertEqual(settings.hour, 9)
        XCTAssertEqual(settings.minute, 0)
    }

    func testRoundTrip() {
        let saved = MemoryReminderSettings(enabled: true, hour: 21, minute: 45)
        MemoryReminderSettingsStore.save(saved, to: defaults)
        XCTAssertEqual(MemoryReminderSettingsStore.load(from: defaults), saved)
    }
}

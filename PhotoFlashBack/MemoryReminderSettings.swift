import Foundation

struct MemoryReminderSettings: Equatable {
    var enabled: Bool
    var hour: Int
    var minute: Int

    static let `default` = MemoryReminderSettings(enabled: false, hour: 9, minute: 0)
}

enum MemoryReminderSettingsStore {
    static let enabledKey = "memoryReminder.enabled"
    static let hourKey = "memoryReminder.hour"
    static let minuteKey = "memoryReminder.minute"

    static func load(from defaults: UserDefaults = .standard) -> MemoryReminderSettings {
        let fallback = MemoryReminderSettings.default
        return MemoryReminderSettings(
            enabled: defaults.object(forKey: enabledKey) == nil ? fallback.enabled : defaults.bool(forKey: enabledKey),
            hour: defaults.object(forKey: hourKey) == nil ? fallback.hour : defaults.integer(forKey: hourKey),
            minute: defaults.object(forKey: minuteKey) == nil ? fallback.minute : defaults.integer(forKey: minuteKey)
        )
    }

    static func save(_ settings: MemoryReminderSettings, to defaults: UserDefaults = .standard) {
        defaults.set(settings.enabled, forKey: enabledKey)
        defaults.set(settings.hour, forKey: hourKey)
        defaults.set(settings.minute, forKey: minuteKey)
    }
}

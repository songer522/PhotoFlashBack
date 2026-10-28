import Foundation
import UserNotifications

/// A month/day the user asked to see by tapping a "memory of the day" notification.
/// Stored until the photo grid is ready to show it, then taken (read and cleared).
enum PendingMemoryDate {
    static let key = "PendingMemoryDate"

    private static let monthField = "month"
    private static let dayField = "day"

    /// Days per month in a leap year, so Feb 29 is valid (matches the grid picker's clamping).
    private static let maxDays = [31, 29, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]

    /// Reads the date out of a notification's `userInfo`. Returns nil when it is missing,
    /// not integers, or not a real calendar date.
    static func parse(userInfo: [AnyHashable: Any]) -> (month: Int, day: Int)? {
        guard let month = userInfo[MemoryReminderScheduler.monthKey] as? Int,
              let day = userInfo[MemoryReminderScheduler.dayKey] as? Int else {
            return nil
        }
        return validated(month: month, day: day)
    }

    /// Records the date of a tapped "memory of the day" notification so the grid shows it.
    /// Ignores other notifications and malformed userInfo. The reminder wins over a pending
    /// widget tap, so ShouldRefresh and the widget's ItemToGo are cleared. Returns whether
    /// the tap was a memory reminder.
    @discardableResult
    static func storeTap(of response: UNNotificationResponse, in defaults: UserDefaults = .standard) -> Bool {
        let request = response.notification.request
        guard request.identifier.hasPrefix(MemoryReminderPlanner.identifierPrefix),
              let date = parse(userInfo: request.content.userInfo) else {
            return false
        }
        store(month: date.month, day: date.day, in: defaults)
        defaults.set(false, forKey: "ShouldRefresh")
        defaults.removeObject(forKey: "ItemToGo")
        return true
    }

    static func store(month: Int, day: Int, in defaults: UserDefaults = .standard) {
        defaults.set([monthField: month, dayField: day], forKey: key)
    }

    /// True when something is stored, without clearing it. Lets callers avoid disturbing the UI
    /// (dismissing a viewer) when there is nothing to route.
    static func hasPending(in defaults: UserDefaults = .standard) -> Bool {
        defaults.object(forKey: key) != nil
    }

    /// Returns the stored date and clears it. Garbage is cleared and reported as nil.
    static func take(from defaults: UserDefaults = .standard) -> (month: Int, day: Int)? {
        guard let stored = defaults.object(forKey: key) else { return nil }
        defaults.removeObject(forKey: key)
        guard let dict = stored as? [String: Any],
              let month = dict[monthField] as? Int,
              let day = dict[dayField] as? Int else {
            return nil
        }
        return validated(month: month, day: day)
    }

    private static func validated(month: Int, day: Int) -> (month: Int, day: Int)? {
        guard (1...12).contains(month), (1...maxDays[month - 1]).contains(day) else { return nil }
        return (month, day)
    }
}

import Foundation

/// Date rules for the widget's stored "on this day" entries. The app picks and stores photos with
/// the Gregorian `MemoryQuery.memoryCalendar()`, so the widget must use the same calendar: on a
/// Hebrew, Islamic or Persian device calendar the month/day differ (every entry would look stale),
/// and on a Buddhist or Japanese one the year label would not match the app. Only the device
/// calendar's time zone is used.
enum WidgetMemoryDate {
    /// Copy of `MemoryQuery.memoryCalendar(timeZone:)` in the app target (PhotoFlashBack/MemoryQuery.swift);
    /// the widget can't see app sources. Keep the two in sync.
    static func memoryCalendar(timeZone: TimeZone = .current) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar
    }

    /// Whether a stored entry belongs to `today`'s month/day. Entries left over from an earlier
    /// day's fetch return false so old photos don't linger.
    static func isEntry(creationDate: Date, forDay today: Date, deviceCalendar: Calendar = .current) -> Bool {
        let calendar = memoryCalendar(timeZone: deviceCalendar.timeZone)
        let todayComponents = calendar.dateComponents([.day, .month], from: today)
        let storedComponents = calendar.dateComponents([.day, .month], from: creationDate)
        return storedComponents.day == todayComponents.day && storedComponents.month == todayComponents.month
    }

    static func yearLabel(for creationDate: Date, deviceCalendar: Calendar = .current) -> String {
        String(memoryCalendar(timeZone: deviceCalendar.timeZone).component(.year, from: creationDate))
    }

    /// Start of the next day, when the widget's entries go stale.
    static func nextRefresh(after date: Date, deviceCalendar: Calendar = .current) -> Date {
        let calendar = memoryCalendar(timeZone: deviceCalendar.timeZone)
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: date) ?? date.addingTimeInterval(24 * 60 * 60)
        return calendar.startOfDay(for: tomorrow)
    }
}

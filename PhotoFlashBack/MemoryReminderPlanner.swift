import Foundation

struct PlannedReminder: Equatable {
    let identifier: String
    let month: Int
    let day: Int
    let fireDateComponents: DateComponents
    let count: Int
    let wantsThumbnail: Bool
}

enum MemoryReminderPlanner {
    static let identifierPrefix = "memory-"

    static func plan(
        now: Date,
        calendar: Calendar,
        settings: MemoryReminderSettings,
        windowDays: Int = 30,
        thumbnailDays: Int = 3,
        count: (_ month: Int, _ day: Int) -> Int
    ) -> [PlannedReminder] {
        guard settings.enabled else { return [] }

        let today = calendar.startOfDay(for: now)
        guard let todayFire = calendar.date(bySettingHour: settings.hour, minute: settings.minute, second: 0, of: today) else {
            return []
        }
        let firstOffset = todayFire > now ? 0 : 1

        var reminders: [PlannedReminder] = []
        for offset in firstOffset..<(firstOffset + windowDays) {
            guard let dayStart = calendar.date(byAdding: .day, value: offset, to: today) else { continue }
            let parts = calendar.dateComponents([.year, .month, .day], from: dayStart)
            guard let year = parts.year, let month = parts.month, let day = parts.day else { continue }

            let memories = count(month, day)
            guard memories > 0 else { continue }

            reminders.append(PlannedReminder(
                identifier: String(format: "%@%04d-%02d-%02d", identifierPrefix, year, month, day),
                month: month,
                day: day,
                fireDateComponents: DateComponents(year: year, month: month, day: day, hour: settings.hour, minute: settings.minute),
                count: memories,
                wantsThumbnail: reminders.count < thumbnailDays
            ))
        }
        return reminders
    }

    static func body(count: Int, month: Int, day: Int) -> String {
        var posix = Calendar(identifier: .gregorian)
        posix.locale = Locale(identifier: "en_US_POSIX")
        let monthName = posix.shortMonthSymbols[month - 1]
        let noun = count == 1 ? "memory" : "memories"
        return "📸 \(count) \(noun) from \(monthName) \(day)"
    }
}

import Foundation

/// User-facing text for a memory's month/day. Memory dates are Gregorian month/day pairs
/// (`MemoryQuery.memoryCalendar()`), so names always come from a Gregorian calendar, in the
/// user's locale: "January 5" in English, "5 janvier" in French.
enum MemoryDateText {
    /// The locale for dates and month names. While the app has only English strings, iOS gives it
    /// `Locale.current` with English as the language (e.g. "en_FR" on a French device), which
    /// would print "18 November". Take the language from the user's preferred languages instead,
    /// so a French device shows "18 novembre"; region and other settings stay `Locale.current`'s.
    static var userLocale: Locale {
        userLocale(preferredLanguages: Locale.preferredLanguages, current: .current)
    }

    static func userLocale(preferredLanguages: [String], current: Locale) -> Locale {
        guard let preferred = preferredLanguages.first else { return current }
        var components = Locale.Components(locale: current)
        components.languageComponents = Locale.Language.Components(identifier: preferred)
        return Locale(components: components)
    }

    /// Month names for the date picker, e.g. "January" or "janvier".
    static func monthSymbols(locale: Locale = userLocale) -> [String] {
        let formatter = DateFormatter()
        // Locale first: setting it resets the calendar to the locale's own (e.g. Hebrew).
        formatter.locale = locale
        formatter.calendar = calendar(locale: locale)
        return formatter.standaloneMonthSymbols
    }

    /// Month and day, e.g. "January 5" or "5 janvier"; nil if the pair isn't a real date.
    static func dayMonth(month: Int, day: Int, locale: Locale = userLocale) -> String? {
        format(month: month, day: day, locale: locale) { $0.month(.wide).day() }
    }

    /// Short month and day, e.g. "Jan 5" or "5 janv."; nil if the pair isn't a real date.
    static func abbreviatedDayMonth(month: Int, day: Int, locale: Locale = userLocale) -> String? {
        format(month: month, day: day, locale: locale) { $0.month(.abbreviated).day() }
    }

    private static func format(month: Int, day: Int, locale: Locale, fields: (Date.FormatStyle) -> Date.FormatStyle) -> String? {
        let calendar = calendar(locale: locale)
        // 2000 is a leap year, so February 29 is a real date.
        let components = DateComponents(year: 2000, month: month, day: day)
        guard components.isValidDate(in: calendar), let date = calendar.date(from: components) else { return nil }
        return date.formatted(fields(Date.FormatStyle(locale: locale, calendar: calendar, timeZone: calendar.timeZone)))
    }

    private static func calendar(locale: Locale) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = locale
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .current
        return calendar
    }
}

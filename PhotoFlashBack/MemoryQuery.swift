import Foundation
import Photos

/// The single definition of "a memory for month/day": the grid and the reminder counter both use it.
enum MemoryQuery {
    /// Matches month/day in every year of `years` (default: the library's own span, see
    /// `libraryYearRange`). Each year's range is (startOfDay, nextStartOfDay], see `dayKey`.
    static func fetchOptions(month: Int, day: Int, years: ClosedRange<Int>? = nil) -> PHFetchOptions {
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]

        let predicates = dayRanges(month: month, day: day, years: years ?? libraryYearRange()).map {
            NSPredicate(format: "creationDate > %@ AND creationDate <= %@", $0.from as NSDate, $0.to as NSDate)
        }
        let datePredicate = NSCompoundPredicate(type: .or, subpredicates: predicates)
        options.predicate = NSCompoundPredicate(type: .and, subpredicates: [datePredicate, mediaPredicate])
        return options
    }

    static func isMemory(
        creationDate: Date?,
        kind: MediaFilter.Kind,
        month: Int,
        day: Int,
        filter: MediaFilter,
        calendar: Calendar = memoryCalendar()
    ) -> Bool {
        guard let creationDate else { return false }
        let components = calendar.dateComponents([.month, .day], from: creationDate)
        guard components.month == month, components.day == day else { return false }
        return filter.includes(kind: kind)
    }

    /// Only past still photos go to the widget: images, no screenshots, not this year.
    static let widgetFilter = MediaFilter(photos: true, videos: false, screenshots: false)

    /// The year a widget candidate belongs to, or nil when it isn't one: `isMemory` with
    /// `widgetFilter`, minus photos from `currentYear`.
    static func widgetYear(
        creationDate: Date?,
        kind: MediaFilter.Kind,
        month: Int,
        day: Int,
        currentYear: Int,
        calendar: Calendar = memoryCalendar()
    ) -> Int? {
        guard let creationDate,
              isMemory(creationDate: creationDate, kind: kind, month: month, day: day, filter: widgetFilter, calendar: calendar) else { return nil }
        let year = calendar.component(.year, from: creationDate)
        return year == currentYear ? nil : year
    }

    struct DayKey: Hashable {
        let month: Int
        let day: Int
    }

    /// The month/day a photo counts toward, matching the grid: its per-year range is
    /// (startOfDay, nextStartOfDay] filtered by `isMemory`, so a photo stamped exactly at
    /// local midnight never shows up and isn't counted here either.
    static func dayKey(creationDate: Date?, calendar: Calendar = memoryCalendar()) -> DayKey? {
        guard let creationDate, creationDate != calendar.startOfDay(for: creationDate) else { return nil }
        let components = calendar.dateComponents([.month, .day], from: creationDate)
        guard let month = components.month, let day = components.day else { return nil }
        return DayKey(month: month, day: day)
    }

    /// The calendar every memory date is worked out in (grid, widget and reminders): Gregorian, so a Buddhist, Japanese or Hebrew device calendar can't shift
    /// the years or month/day, and a reminder's count always matches the grid it opens.
    static func memoryCalendar(timeZone: TimeZone = .current) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar
    }

    /// How far before this year `yearRange` searches at most: photography began in the 1820s.
    static let maxYearsBack = 200
    /// How far past this year `yearRange` searches at most, for bad future timestamps. Both caps keep
    /// the OR'd per-year predicate a few hundred terms long whatever a corrupt date says.
    static let maxYearsAhead = 100

    /// The Gregorian years to search: the oldest asset's year through the newest asset's year, and
    /// always this year and next (so a photo taken right now, or stamped slightly ahead, is found),
    /// bounded by `maxYearsBack` / `maxYearsAhead`.
    static func yearRange(oldest: Date?, newest: Date?, now: Date = Date(), calendar: Calendar = memoryCalendar()) -> ClosedRange<Int> {
        let thisYear = calendar.component(.year, from: now)
        let floor = thisYear - maxYearsBack
        let ceiling = thisYear + maxYearsAhead
        let lower = oldest.map { calendar.component(.year, from: $0) } ?? thisYear
        let upper = newest.map { calendar.component(.year, from: $0) } ?? thisYear + 1
        return min(max(lower, floor), thisYear)...max(min(upper, ceiling), thisYear + 1)
    }

    /// `yearRange` for the photo library's oldest and newest image or video. The grid, the reminder
    /// counts and the widget all search these years, so they agree on every date.
    static func libraryYearRange(now: Date = Date()) -> ClosedRange<Int> {
        func boundary(ascending: Bool) -> Date? {
            PHAsset.fetchAssets(with: boundaryFetchOptions(ascending: ascending)).firstObject?.creationDate
        }
        return yearRange(oldest: boundary(ascending: true), newest: boundary(ascending: false), now: now)
    }

    /// The single oldest (`ascending`) or newest dated image or video. Undated assets are excluded:
    /// one sorting first would otherwise make the oldest year "this year" and hide older memories.
    static func boundaryFetchOptions(ascending: Bool) -> PHFetchOptions {
        let options = PHFetchOptions()
        options.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
            // A date comparison, the predicate form PhotoKit supports; nil never satisfies it.
            NSPredicate(format: "creationDate > %@", Date.distantPast as NSDate),
            mediaPredicate,
        ])
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: ascending)]
        options.fetchLimit = 1
        return options
    }

    private static var mediaPredicate: NSPredicate {
        NSPredicate(format: "mediaType = %d OR mediaType = %d", PHAssetMediaType.image.rawValue, PHAssetMediaType.video.rawValue)
    }

    /// One (startOfDay, nextStartOfDay] range per year in `years` that has a `month`/`day`
    /// (Feb 29 only in leap years).
    static func dayRanges(month: Int, day: Int, years: ClosedRange<Int>, timeZone: TimeZone = .current) -> [(from: Date, to: Date)] {
        let calendar = memoryCalendar(timeZone: timeZone)
        return years.compactMap { year in
            guard let noon = calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12)),
                  calendar.dateComponents([.month, .day], from: noon) == DateComponents(month: month, day: day) else { return nil }
            let from = calendar.startOfDay(for: noon)
            guard let to = calendar.date(byAdding: .day, value: 1, to: from) else { return nil }
            return (from: from, to: to)
        }
    }

    /// One (from, to] range per year covering `days` dates from `start`, padded two days each side
    /// so Feb 29 shifts and year wraps stay inside, and clamped to `years`, the same years
    /// `fetchOptions` searches. A window that wraps into January starts a year early so January
    /// of the first year is still counted.
    static func windowRanges(from start: Date, days: Int, years: ClosedRange<Int>, timeZone: TimeZone = .current) -> [(from: Date, to: Date)] {
        let calendar = memoryCalendar(timeZone: timeZone)
        let first = calendar.dateComponents([.month, .day], from: start)
        guard let firstMonth = first.month, let firstDay = first.day,
              let earliest = calendar.date(from: DateComponents(year: years.lowerBound, month: 1, day: 1)),
              let latest = calendar.date(from: DateComponents(year: years.upperBound + 1, month: 1, day: 1)) else { return [] }
        return ((years.lowerBound - 1)...years.upperBound).compactMap { year in
            guard let anchor = calendar.date(from: DateComponents(year: year, month: firstMonth, day: firstDay)),
                  let from = calendar.date(byAdding: .day, value: -2, to: anchor),
                  let to = calendar.date(byAdding: .day, value: days + 2, to: anchor) else { return nil }
            let clamped = (from: max(from, earliest), to: min(to, latest))
            return clamped.from < clamped.to ? clamped : nil
        }
    }

    /// Counts memories for `days` consecutive dates starting at `start` with a single PhotoKit
    /// query. Each query costs about the same however many dates it covers, so this is ~30x
    /// faster than counting the dates one at a time. Per date it matches `assets(month:day:filter:)`.
    static func counts(from start: Date, days: Int, filter: MediaFilter, timeZone: TimeZone = .current) -> [DayKey: Int] {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        guard status == .authorized || status == .limited else { return [:] }

        let calendar = memoryCalendar(timeZone: timeZone)
        let ranges = windowRanges(from: start, days: days, years: libraryYearRange(), timeZone: timeZone).map {
            NSPredicate(format: "creationDate > %@ AND creationDate <= %@", $0.from as NSDate, $0.to as NSDate)
        }
        let options = PHFetchOptions()
        options.predicate = NSCompoundPredicate(type: .and, subpredicates: [NSCompoundPredicate(type: .or, subpredicates: ranges), mediaPredicate])

        var result: [DayKey: Int] = [:]
        PHAsset.fetchAssets(with: options).enumerateObjects { asset, _, _ in
            guard let key = dayKey(creationDate: asset.creationDate, calendar: calendar) else { return }
            let kind = MediaFilter.kind(mediaType: asset.mediaType, mediaSubtypes: asset.mediaSubtypes)
            guard filter.includes(kind: kind) else { return }
            result[key, default: 0] += 1
        }
        return result
    }

    static func assets(month: Int, day: Int, filter: MediaFilter) -> [PHAsset] {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        guard status == .authorized || status == .limited else { return [] }
        let fetched = PHAsset.fetchAssets(with: fetchOptions(month: month, day: day))
        var result: [PHAsset] = []
        fetched.enumerateObjects { asset, _, _ in
            let kind = MediaFilter.kind(mediaType: asset.mediaType, mediaSubtypes: asset.mediaSubtypes)
            if isMemory(creationDate: asset.creationDate, kind: kind, month: month, day: day, filter: filter) {
                result.append(asset)
            }
        }
        return result
    }
}

import Foundation
import Photos

/// The single definition of "a memory for month/day": the grid and the reminder counter both use it.
enum MemoryQuery {
    static func fetchOptions(month: Int, day: Int) -> PHFetchOptions {
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]

        let predicates = Helper.compoundPredicateFrom(day: day, month: month)
        let imagePredicate = NSPredicate(format: "mediaType = %d", PHAssetMediaType.image.rawValue)
        let videoPredicate = NSPredicate(format: "mediaType = %d", PHAssetMediaType.video.rawValue)
        let datePredicate = NSCompoundPredicate(type: .or, subpredicates: predicates)
        let mediaPredicate = NSCompoundPredicate(type: .or, subpredicates: [imagePredicate, videoPredicate])
        options.predicate = NSCompoundPredicate(type: .and, subpredicates: [datePredicate, mediaPredicate])
        return options
    }

    static func isMemory(
        creationDate: Date?,
        kind: MediaFilter.Kind,
        month: Int,
        day: Int,
        filter: MediaFilter,
        calendar: Calendar = .current
    ) -> Bool {
        guard let creationDate else { return false }
        let components = calendar.dateComponents([.month, .day], from: creationDate)
        guard components.month == month, components.day == day else { return false }
        return filter.includes(kind: kind)
    }

    struct DayKey: Hashable {
        let month: Int
        let day: Int
    }

    /// The month/day a photo counts toward, matching the grid: its per-year range is
    /// (startOfDay, nextStartOfDay] filtered by `isMemory`, so a photo stamped exactly at
    /// local midnight never shows up and isn't counted here either.
    static func dayKey(creationDate: Date?, calendar: Calendar = .current) -> DayKey? {
        guard let creationDate, creationDate != calendar.startOfDay(for: creationDate) else { return nil }
        let components = calendar.dateComponents([.month, .day], from: creationDate)
        guard let month = components.month, let day = components.day else { return nil }
        return DayKey(month: month, day: day)
    }

    /// Counts memories for `days` consecutive dates starting at `start` with a single PhotoKit
    /// query. Each query costs about the same however many dates it covers, so this is ~30x
    /// faster than counting the dates one at a time. Per date it matches `assets(month:day:filter:)`.
    static func counts(from start: Date, days: Int, filter: MediaFilter, calendar: Calendar = .current) -> [DayKey: Int] {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        guard status == .authorized || status == .limited else { return [:] }

        let first = calendar.dateComponents([.month, .day], from: start)
        guard let firstMonth = first.month, let firstDay = first.day else { return [:] }
        // One range per year covering the window, padded so Feb 29 shifts and year wraps stay inside.
        var ranges: [NSPredicate] = []
        for year in 1970...2050 {
            guard let anchor = calendar.date(from: DateComponents(year: year, month: firstMonth, day: firstDay)),
                  let from = calendar.date(byAdding: .day, value: -2, to: anchor),
                  let to = calendar.date(byAdding: .day, value: days + 2, to: anchor) else { continue }
            ranges.append(NSPredicate(format: "creationDate > %@ AND creationDate <= %@", from as NSDate, to as NSDate))
        }
        let mediaPredicate = NSPredicate(format: "mediaType = %d OR mediaType = %d", PHAssetMediaType.image.rawValue, PHAssetMediaType.video.rawValue)
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

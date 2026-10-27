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

    static func count(month: Int, day: Int, filter: MediaFilter) -> Int {
        assets(month: month, day: day, filter: filter).count
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

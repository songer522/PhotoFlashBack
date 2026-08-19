import Foundation
import Photos

struct MediaFilter: Equatable, Sendable {
    var photos: Bool
    var videos: Bool
    var screenshots: Bool

    var isEffectivelyUnfiltered: Bool {
        let allOn = photos && videos && screenshots
        let allOff = !photos && !videos && !screenshots
        return allOn || allOff
    }

    enum Kind: Equatable {
        case photo
        case video
        case screenshot
    }

    static func kind(mediaType: PHAssetMediaType, mediaSubtypes: PHAssetMediaSubtype) -> Kind {
        if mediaType == .video {
            return .video
        }
        if mediaType == .image && mediaSubtypes.contains(.photoScreenshot) {
            return .screenshot
        }
        return .photo
    }

    func includes(kind: Kind) -> Bool {
        if isEffectivelyUnfiltered {
            return true
        }
        switch kind {
        case .photo:
            return photos
        case .video:
            return videos
        case .screenshot:
            return screenshots
        }
    }

    func includes(_ asset: PHAsset) -> Bool {
        includes(kind: Self.kind(mediaType: asset.mediaType, mediaSubtypes: asset.mediaSubtypes))
    }

    func normalizedForFetch() -> MediaFilter {
        if isEffectivelyUnfiltered {
            return MediaFilter(photos: true, videos: true, screenshots: true)
        }
        return self
    }
}

enum MediaFilterStore {
    static let photosKey = "mediaFilter.photos"
    static let videosKey = "mediaFilter.videos"
    static let screenshotsKey = "mediaFilter.screenshots"

    static func load(from defaults: UserDefaults = .standard) -> MediaFilter {
        MediaFilter(
            photos: flag(photosKey, from: defaults),
            videos: flag(videosKey, from: defaults),
            screenshots: flag(screenshotsKey, from: defaults)
        )
    }

    static func save(_ filter: MediaFilter, to defaults: UserDefaults = .standard) {
        defaults.set(filter.photos, forKey: photosKey)
        defaults.set(filter.videos, forKey: videosKey)
        defaults.set(filter.screenshots, forKey: screenshotsKey)
    }

    private static func flag(_ key: String, from defaults: UserDefaults) -> Bool {
        if defaults.object(forKey: key) == nil {
            return true
        }
        return defaults.bool(forKey: key)
    }
}

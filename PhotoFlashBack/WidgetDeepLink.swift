//
//  WidgetDeepLink.swift
//  PhotoFlashBack
//
//  Parses per-photo widget deep links (openToday://widget?index=N&localId=...)
//  and resolves them to the matching photo's metadata in WidgetPhotoStore,
//  or in the photo library when the store doesn't have it.
//

import Foundation
import Photos

enum WidgetDeepLink {
    static let scheme = "openToday"
    static let host = "widget"

    struct Target {
        let index: Int?
        let localIdentifier: String?
    }

    static func parse(_ url: URL) -> Target {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return Target(index: nil, localIdentifier: nil)
        }
        let items = components.queryItems ?? []
        let indexString = items.first(where: { $0.name == "index" })?.value
        let localId = items.first(where: { $0.name == "localId" })?.value
        return Target(index: indexString.flatMap(Int.init), localIdentifier: localId)
    }

    static func widgetURL(index: Int, localIdentifier: String) -> URL {
        var components = URLComponents()
        components.scheme = scheme
        components.host = host
        components.queryItems = [
            URLQueryItem(name: "index", value: String(index)),
            URLQueryItem(name: "localId", value: localIdentifier),
        ]
        return components.url ?? URL(string: "openToday://widget")!
    }

    /// Returns the metadata dict for the tapped photo. Prefers an exact
    /// localIdentifier match (the tapped card): from the store, else from
    /// `assetLookup`, which covers an empty or stale store (e.g. the first
    /// launch after the issue #14 migration, from a tap on an existing
    /// widget). Then the requested index, then index 0 for backwards
    /// compatibility with old widget timelines that carry no query items.
    static func resolveMetadata(index: Int?, localIdentifier: String?,
                                store: WidgetPhotoStore? = .appGroup(),
                                assetLookup: (String) -> [String: Any]? = photoLibraryMetadata) -> [String: Any]? {
        if let localIdentifier, !localIdentifier.isEmpty {
            if let store {
                for i in 0..<WidgetPhotoStore.maxStoredAssetCount {
                    if let meta = store.metadata(at: i), meta.localIdentifier == localIdentifier {
                        return meta.dictionary
                    }
                }
            }
            if let meta = assetLookup(localIdentifier) {
                return meta
            }
        }

        guard let store else { return nil }

        if let index, let meta = store.metadata(at: index) {
            return meta.dictionary
        }

        return store.metadata(at: 0)?.dictionary
    }

    /// The tap-routing metadata for a photo library asset, or nil if it no
    /// longer exists or photo access isn't granted.
    static func photoLibraryMetadata(localIdentifier: String) -> [String: Any]? {
        guard let asset = PHAsset.fetchAssets(withLocalIdentifiers: [localIdentifier], options: nil).firstObject else {
            return nil
        }
        return metadataDictionary(localIdentifier: asset.localIdentifier, creationDate: asset.creationDate,
                                  pixelWidth: asset.pixelWidth, pixelHeight: asset.pixelHeight)
    }

    /// Same keys as `WidgetPhotoStore.Metadata.dictionary`; a missing date is
    /// omitted, since `ItemToGo` must be a property list.
    static func metadataDictionary(localIdentifier: String, creationDate: Date?,
                                   pixelWidth: Int, pixelHeight: Int) -> [String: Any] {
        var dictionary: [String: Any] = [
            "localIdentifier": localIdentifier,
            "pixelWidth": pixelWidth,
            "pixelHeight": pixelHeight,
        ]
        dictionary["creationDate"] = creationDate
        return dictionary
    }
}

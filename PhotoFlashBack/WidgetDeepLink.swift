//
//  WidgetDeepLink.swift
//  PhotoFlashBack
//
//  Parses per-photo widget deep links (openToday://widget?index=N&localId=...)
//  and resolves them to the matching photo's metadata in WidgetPhotoStore.
//

import Foundation

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
    /// localIdentifier match (the tapped card), then the requested index,
    /// then index 0 for backwards compatibility with old widget timelines
    /// that carry no query items.
    static func resolveMetadata(index: Int?, localIdentifier: String?,
                                store: WidgetPhotoStore? = .appGroup()) -> [String: Any]? {
        guard let store else { return nil }

        if let localIdentifier, !localIdentifier.isEmpty {
            for i in 0..<WidgetPhotoStore.maxStoredAssetCount {
                if let meta = store.metadata(at: i), meta.localIdentifier == localIdentifier {
                    return meta.dictionary
                }
            }
        }

        if let index, let meta = store.metadata(at: index) {
            return meta.dictionary
        }

        return store.metadata(at: 0)?.dictionary
    }
}

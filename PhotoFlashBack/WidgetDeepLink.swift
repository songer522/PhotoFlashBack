//
//  WidgetDeepLink.swift
//  PhotoFlashBack
//
//  Parses per-photo widget deep links (openToday://widget?index=N&localId=...)
//  and resolves them to the matching metadata blob in the shared App Group.
//

import Foundation

enum WidgetDeepLink {
    static let scheme = "openToday"
    static let host = "widget"
    static let suiteName = "group.com.YangSong.PhotoFlashBack.Today"
    static let maxStoredAssetCount = 6

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

    private static func metadataKey(for index: Int) -> String {
        index == 0 ? "randomAssetMetadata" : "randomAssetMetadata_\(index)"
    }

    /// Returns the metadata dict for the tapped photo. Prefers an exact
    /// localIdentifier match (the tapped card), then the requested index,
    /// then index 0 for backwards compatibility with old widget timelines
    /// that carry no query items.
    static func resolveMetadata(index: Int?, localIdentifier: String?) -> [String: Any]? {
        let sharedDefaults = UserDefaults(suiteName: suiteName)

        if let localIdentifier, !localIdentifier.isEmpty {
            for i in 0..<maxStoredAssetCount {
                if let meta = sharedDefaults?.dictionary(forKey: metadataKey(for: i)),
                   (meta["localIdentifier"] as? String) == localIdentifier {
                    return meta
                }
            }
        }

        if let index, index >= 0, index < maxStoredAssetCount,
           let meta = sharedDefaults?.dictionary(forKey: metadataKey(for: index)) {
            return meta
        }

        return sharedDefaults?.dictionary(forKey: metadataKey(for: 0))
    }
}

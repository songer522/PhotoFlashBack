//
//  WidgetPhotoStore.swift
//  TodayWidget
//
//  The on-disk hand-off of "on this day" photos from the app (PhotoManager writes) to the
//  widget (TodayWidget reads). A member of both the app and the widget targets, so the
//  directory, file names and metadata format are defined only here.
//
//  Layout, one slot per index in 0..<maxStoredAssetCount:
//    <App Group container>/WidgetPhotos/photo_<index>.json          metadata
//    <App Group container>/WidgetPhotos/photo_<index>_<UUID>.jpg    image named by the metadata
//

import Foundation
import ImageIO

struct WidgetPhotoStore {
    static let appGroupIdentifier = "group.com.YangSong.PhotoFlashBack.Today"
    static let directoryName = "WidgetPhotos"
    /// Matches the widget's systemLarge grid and the `count: 6` fetches in AppDelegate/SceneDelegate.
    static let maxStoredAssetCount = 6

    struct Metadata: Codable, Equatable {
        let creationDate: Date
        let localIdentifier: String
        let pixelWidth: Int
        let pixelHeight: Int
        /// The image file, in the store's directory, that was written with this metadata.
        let imageFileName: String

        /// Property-list form the app's widget-tap routing keeps in `ItemToGo`.
        var dictionary: [String: Any] {
            [
                "creationDate": creationDate,
                "localIdentifier": localIdentifier,
                "pixelWidth": pixelWidth,
                "pixelHeight": pixelHeight,
            ]
        }
    }

    struct Entry {
        let index: Int
        let metadata: Metadata
        let imageURL: URL
    }

    enum StoreError: Error {
        case indexOutOfRange(Int)
    }

    let directory: URL

    init(directory: URL) {
        self.directory = directory
    }

    /// The store in the shared App Group container, or nil if the container is unavailable.
    static func appGroup() -> WidgetPhotoStore? {
        guard let container = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupIdentifier
        ) else {
            return nil
        }
        return WidgetPhotoStore(directory: container.appendingPathComponent(directoryName, isDirectory: true))
    }

    // MARK: - Writing (app)

    /// Writes the slot's image, then its metadata. Each file is written atomically, and every write
    /// uses a new image file name, so metadata always names a complete image of the same photo.
    /// Holds `writeLock` throughout, so an overlapping write's cleanup can't delete this image.
    func store(imageData: Data, creationDate: Date, localIdentifier: String,
               pixelWidth: Int, pixelHeight: Int, at index: Int) throws {
        guard (0..<Self.maxStoredAssetCount).contains(index) else {
            throw StoreError.indexOutOfRange(index)
        }
        Self.writeLock.lock()
        defer { Self.writeLock.unlock() }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let imageFileName = "\(Self.imagePrefix(for: index))\(UUID().uuidString).jpg"
        try imageData.write(to: directory.appendingPathComponent(imageFileName), options: Self.writeOptions)

        let metadata = Metadata(
            creationDate: creationDate,
            localIdentifier: localIdentifier,
            pixelWidth: pixelWidth,
            pixelHeight: pixelHeight,
            imageFileName: imageFileName
        )
        try JSONEncoder().encode(metadata).write(to: metadataURL(for: index), options: Self.writeOptions)

        removeImages(forSlot: index, keeping: imageFileName)
    }

    /// Removes slots `startIndex..<maxStoredAssetCount`, which may hold a previous run's photos.
    func removeEntries(from startIndex: Int) {
        guard startIndex < Self.maxStoredAssetCount else { return }
        Self.writeLock.lock()
        defer { Self.writeLock.unlock() }
        for index in max(startIndex, 0)..<Self.maxStoredAssetCount {
            // Metadata first, so a reader never finds metadata whose image is being removed.
            try? FileManager.default.removeItem(at: metadataURL(for: index))
            removeImages(forSlot: index, keeping: nil)
        }
    }

    // MARK: - Reading (widget, and the app's deep-link handling)

    func metadata(at index: Int) -> Metadata? {
        guard (0..<Self.maxStoredAssetCount).contains(index),
              let data = try? Data(contentsOf: metadataURL(for: index)) else {
            return nil
        }
        return try? JSONDecoder().decode(Metadata.self, from: data)
    }

    /// The slot's metadata and image location, or nil if either is missing.
    func entry(at index: Int) -> Entry? {
        guard let metadata = metadata(at: index) else { return nil }
        let imageURL = directory.appendingPathComponent(metadata.imageFileName)
        guard FileManager.default.fileExists(atPath: imageURL.path) else { return nil }
        return Entry(index: index, metadata: metadata, imageURL: imageURL)
    }

    /// The slot's entry and decoded image, for the widget, which reads without `writeLock` from
    /// another process. If the image vanishes between reading the metadata and decoding it, the app
    /// has just rewritten the slot (cleanup runs only after the new metadata is published), so this
    /// re-reads the slot and decodes the new image. Gives up when the metadata hasn't changed.
    /// `accept` filters on metadata before any decode (e.g. stale dates).
    func loadImage(at index: Int, accept: (Metadata) -> Bool,
                   decode: (URL) -> CGImage?) -> (Entry, CGImage)? {
        var previous: Metadata?
        for _ in 0..<Self.maxLoadAttempts {
            guard let metadata = metadata(at: index), metadata != previous, accept(metadata) else {
                return nil
            }
            let imageURL = directory.appendingPathComponent(metadata.imageFileName)
            if let image = decode(imageURL) {
                return (Entry(index: index, metadata: metadata, imageURL: imageURL), image)
            }
            previous = metadata
        }
        return nil
    }

    /// Decodes the image at `url` directly at no more than `maxPixelSize` on its longer side,
    /// so the widget never holds a larger bitmap than it can show (widgets have a tight memory limit).
    static func downsampledImage(at url: URL, maxPixelSize: Int) -> CGImage? {
        let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithURL(url as CFURL, sourceOptions) else { return nil }
        let thumbnailOptions = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: max(maxPixelSize, 1),
        ] as CFDictionary
        return CGImageSourceCreateThumbnailAtIndex(source, 0, thumbnailOptions)
    }

    // MARK: - Legacy UserDefaults storage

    /// Keys the app used before issue #14 to keep JPEGs and metadata in the App Group defaults.
    static var legacyDefaultsKeys: [String] {
        (0..<maxStoredAssetCount).flatMap { index -> [String] in
            let suffix = index == 0 ? "" : "_\(index)"
            return ["randomAssetImageData\(suffix)", "randomAssetMetadata\(suffix)"]
        }
    }

    /// Deletes the legacy keys. Returns whether there was anything to delete.
    @discardableResult
    static func removeLegacyDefaults(from defaults: UserDefaults) -> Bool {
        var removedAny = false
        for key in legacyDefaultsKeys where defaults.object(forKey: key) != nil {
            defaults.removeObject(forKey: key)
            removedAny = true
        }
        return removedAny
    }

    // MARK: - Private

    /// Serializes every write → publish metadata → cleanup sequence, and every removal, in this
    /// process and across store instances: refreshes overlap, and PHImageManager result handlers
    /// call `store` on arbitrary queues. Readers (the widget) never take it; atomic writes keep
    /// each file whole for them.
    private static let writeLock = NSLock()

    /// Bounds `loadImage` re-reads if the app keeps rewriting the slot during the read.
    private static let maxLoadAttempts = 3

    // Readable after first unlock, so the lock-screen widget and background refresh still work.
    private static let writeOptions: Data.WritingOptions = [.atomic, .completeFileProtectionUntilFirstUserAuthentication]

    private static func imagePrefix(for index: Int) -> String {
        "photo_\(index)_"
    }

    private func metadataURL(for index: Int) -> URL {
        directory.appendingPathComponent("photo_\(index).json")
    }

    private func removeImages(forSlot index: Int, keeping keptFileName: String?) {
        let prefix = Self.imagePrefix(for: index)
        guard let names = try? FileManager.default.contentsOfDirectory(atPath: directory.path) else { return }
        for name in names where name.hasPrefix(prefix) && name != keptFileName {
            try? FileManager.default.removeItem(at: directory.appendingPathComponent(name))
        }
    }
}

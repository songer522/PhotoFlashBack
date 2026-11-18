import XCTest
import UIKit
@testable import PhotoFlashBack

/// `WidgetPhotoStore` is the on-disk hand-off between the app (writer) and the widget (reader).
/// Each test runs against its own temporary directory instead of the App Group container.
final class WidgetPhotoStoreTests: XCTestCase {
    private var directory: URL!
    private var store: WidgetPhotoStore!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("WidgetPhotoStoreTests-\(UUID().uuidString)", isDirectory: true)
        store = WidgetPhotoStore(directory: directory)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
    }

    private func jpegData(width: Int = 40, height: Int = 30) -> Data {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: width, height: height), format: format)
        return renderer.jpegData(withCompressionQuality: 0.8) { context in
            UIColor.systemTeal.setFill()
            context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        }
    }

    private func save(_ localIdentifier: String, at index: Int, data: Data? = nil,
                       creationDate: Date = Date(timeIntervalSince1970: 1_500_000_000)) throws {
        try store.store(imageData: data ?? jpegData(), creationDate: creationDate,
                        localIdentifier: localIdentifier, pixelWidth: 4032, pixelHeight: 3024, at: index)
    }

    private func imageFiles(forSlot index: Int) throws -> [String] {
        try FileManager.default.contentsOfDirectory(atPath: directory.path)
            .filter { $0.hasPrefix("photo_\(index)_") && $0.hasSuffix(".jpg") }
    }

    // MARK: - Store and read

    func testStoredEntryRoundTripsMetadataAndImage() throws {
        let data = jpegData()
        let date = Date(timeIntervalSince1970: 1_234_567_890)
        try save("asset-A", at: 2, data: data, creationDate: date)

        let entry = try XCTUnwrap(store.entry(at: 2))
        XCTAssertEqual(entry.index, 2)
        XCTAssertEqual(entry.metadata.localIdentifier, "asset-A")
        XCTAssertEqual(entry.metadata.creationDate, date)
        XCTAssertEqual(entry.metadata.pixelWidth, 4032)
        XCTAssertEqual(entry.metadata.pixelHeight, 3024)
        XCTAssertEqual(try Data(contentsOf: entry.imageURL), data)
        XCTAssertNil(store.entry(at: 0))
    }

    func testRewritingSlotReplacesImageAndLeavesOneImageFile() throws {
        try save("old", at: 1)
        try save("new", at: 1)

        XCTAssertEqual(store.entry(at: 1)?.metadata.localIdentifier, "new")
        XCTAssertEqual(try imageFiles(forSlot: 1).count, 1)
    }

    // MARK: - Concurrent writers (overlapping refreshes, PHImageManager handlers on any queue)

    /// Asserts the slot is consistent: its metadata names an image that exists and no other image
    /// remains, or it has neither metadata nor images.
    private func assertSlotConsistent(_ index: Int, file: StaticString = #filePath, line: UInt = #line) throws {
        let images = try imageFiles(forSlot: index)
        if let metadata = store.metadata(at: index) {
            XCTAssertNotNil(store.entry(at: index), "metadata names a missing image", file: file, line: line)
            XCTAssertEqual(images, [metadata.imageFileName], "exactly one image, the one the metadata names",
                           file: file, line: line)
        } else {
            XCTAssertEqual(images, [], "no metadata, so no image may remain", file: file, line: line)
        }
    }

    func testConcurrentWritesToOneSlotLeaveMetadataAndExactlyOneImage() throws {
        let data = jpegData()
        let directory = self.directory!
        for round in 0..<5 {
            DispatchQueue.concurrentPerform(iterations: 64) { i in
                // A separate instance per writer, as each refresh creates its own store.
                try? WidgetPhotoStore(directory: directory).store(
                    imageData: data, creationDate: Date(), localIdentifier: "asset-\(round)-\(i)",
                    pixelWidth: 40, pixelHeight: 30, at: 0)
            }
            XCTAssertNotNil(store.entry(at: 0), "round \(round)")
            try assertSlotConsistent(0)
        }
    }

    func testConcurrentWritesAndRemovalsLeaveEachSlotConsistent() throws {
        let data = jpegData()
        let directory = self.directory!
        for round in 0..<5 {
            DispatchQueue.concurrentPerform(iterations: 64) { i in
                let writer = WidgetPhotoStore(directory: directory)
                if i % 4 == 3 {
                    writer.removeEntries(from: 0)
                } else {
                    try? writer.store(imageData: data, creationDate: Date(), localIdentifier: "asset-\(round)-\(i)",
                                      pixelWidth: 40, pixelHeight: 30, at: i % 2)
                }
            }
            try assertSlotConsistent(0)
            try assertSlotConsistent(1)
        }
    }

    func testEntryWhoseImageIsMissingIsNotReturned() throws {
        try save("asset-A", at: 0)
        let imageURL = try XCTUnwrap(store.entry(at: 0)?.imageURL)
        try FileManager.default.removeItem(at: imageURL)

        XCTAssertNil(store.entry(at: 0))
    }

    func testStoringOutOfRangeIndexThrows() {
        XCTAssertThrowsError(try save("x", at: WidgetPhotoStore.maxStoredAssetCount))
        XCTAssertThrowsError(try save("x", at: -1))
    }

    func testRemoveEntriesClearsSlotsFromIndexOnward() throws {
        for index in 0..<WidgetPhotoStore.maxStoredAssetCount {
            try save("asset-\(index)", at: index)
        }

        store.removeEntries(from: 2)

        XCTAssertEqual(store.entry(at: 0)?.metadata.localIdentifier, "asset-0")
        XCTAssertEqual(store.entry(at: 1)?.metadata.localIdentifier, "asset-1")
        for index in 2..<WidgetPhotoStore.maxStoredAssetCount {
            XCTAssertNil(store.metadata(at: index), "slot \(index)")
            XCTAssertEqual(try imageFiles(forSlot: index), [], "slot \(index)")
        }
    }

    func testRemoveEntriesPastLastSlotKeepsEverything() throws {
        try save("asset-5", at: WidgetPhotoStore.maxStoredAssetCount - 1)

        store.removeEntries(from: WidgetPhotoStore.maxStoredAssetCount + 1)

        XCTAssertEqual(store.entry(at: WidgetPhotoStore.maxStoredAssetCount - 1)?.metadata.localIdentifier, "asset-5")
    }

    func testMetadataDictionaryCarriesWhatTheTapRoutingReads() throws {
        let date = Date(timeIntervalSince1970: 1_234_567_890)
        try save("asset-A", at: 0, creationDate: date)

        let dictionary = try XCTUnwrap(store.metadata(at: 0)?.dictionary)
        XCTAssertEqual(dictionary["localIdentifier"] as? String, "asset-A")
        XCTAssertEqual(dictionary["creationDate"] as? Date, date)
        // ItemToGo is saved to UserDefaults, so the dictionary must be a valid property list.
        XCTAssertTrue(PropertyListSerialization.propertyList(dictionary, isValidFor: .binary))
    }

    // MARK: - Widget downscaling

    func testDownsampledImageFitsRequestedPixelSize() throws {
        try save("asset-A", at: 0, data: jpegData(width: 400, height: 300))
        let imageURL = try XCTUnwrap(store.entry(at: 0)?.imageURL)

        let image = try XCTUnwrap(WidgetPhotoStore.downsampledImage(at: imageURL, maxPixelSize: 100))
        XCTAssertEqual(max(image.width, image.height), 100)
        XCTAssertEqual(image.width, 100)
        XCTAssertEqual(image.height, 75)
    }

    /// The widget reads metadata, then the app rewrites the slot and its cleanup deletes the image
    /// that metadata named before the widget decodes it. The widget must re-read the slot and get
    /// the new photo instead of skipping it.
    func testLoadImageRereadsSlotWhenImageIsReplacedMidRead() throws {
        try save("old", at: 0)
        var decodeCalls = 0

        let loaded = store.loadImage(at: 0, accept: { _ in true }) { url in
            decodeCalls += 1
            if decodeCalls == 1 {
                // The app's refresh lands between the metadata read and the decode.
                try? self.save("new", at: 0)
            }
            return WidgetPhotoStore.downsampledImage(at: url, maxPixelSize: 100)
        }

        let (entry, _) = try XCTUnwrap(loaded)
        XCTAssertEqual(entry.metadata.localIdentifier, "new")
        XCTAssertEqual(decodeCalls, 2)
    }

    func testLoadImageGivesUpOnSlotWhoseImageStaysUnreadable() throws {
        try save("asset-A", at: 0)
        var decodeCalls = 0

        let loaded = store.loadImage(at: 0, accept: { _ in true }) { _ in
            decodeCalls += 1
            return nil
        }

        XCTAssertNil(loaded)
        XCTAssertEqual(decodeCalls, 1, "unchanged metadata means no rewrite happened, so no retry")
    }

    func testLoadImageReturnsNilForEmptyOrRejectedSlotWithoutDecoding() throws {
        try save("asset-A", at: 1)
        var decodeCalls = 0
        XCTAssertNil(store.loadImage(at: 3, accept: { _ in true }) { _ in decodeCalls += 1; return nil })
        XCTAssertNil(store.loadImage(at: 1, accept: { _ in false }) { _ in decodeCalls += 1; return nil })
        XCTAssertEqual(decodeCalls, 0)
    }

    // MARK: - Legacy UserDefaults migration

    func testRemoveLegacyDefaultsDeletesImageAndMetadataKeysOnly() throws {
        let suiteName = "WidgetPhotoStoreTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let legacyKeys = ["randomAssetImageData", "randomAssetMetadata"]
            + (1..<WidgetPhotoStore.maxStoredAssetCount).flatMap {
                ["randomAssetImageData_\($0)", "randomAssetMetadata_\($0)"]
            }
        for key in legacyKeys {
            defaults.set(key.contains("Image") ? jpegData() : ["localIdentifier": key], forKey: key)
        }
        defaults.set(true, forKey: "unrelatedSetting")

        XCTAssertTrue(WidgetPhotoStore.removeLegacyDefaults(from: defaults))

        for key in legacyKeys {
            XCTAssertNil(defaults.object(forKey: key), key)
        }
        XCTAssertTrue(defaults.bool(forKey: "unrelatedSetting"))
        XCTAssertFalse(WidgetPhotoStore.removeLegacyDefaults(from: defaults), "second run has nothing to remove")
    }

    // MARK: - Widget deep link resolution

    func testResolveMetadataPrefersExactLocalIdentifier() throws {
        try save("asset-0", at: 0)
        try save("asset-1", at: 1)
        try save("asset-2", at: 2)

        let meta = WidgetDeepLink.resolveMetadata(index: 0, localIdentifier: "asset-2", store: store)
        XCTAssertEqual(meta?["localIdentifier"] as? String, "asset-2")
    }

    func testResolveMetadataFallsBackToIndexThenFirstSlot() throws {
        try save("asset-0", at: 0)
        try save("asset-1", at: 1)

        XCTAssertEqual(WidgetDeepLink.resolveMetadata(index: 1, localIdentifier: "gone", store: store,
                                                      assetLookup: { _ in nil })?["localIdentifier"] as? String, "asset-1")
        XCTAssertEqual(WidgetDeepLink.resolveMetadata(index: 5, localIdentifier: nil, store: store)?["localIdentifier"] as? String, "asset-0")
        // Old widget timelines carry no query items.
        XCTAssertEqual(WidgetDeepLink.resolveMetadata(index: nil, localIdentifier: nil, store: store)?["localIdentifier"] as? String, "asset-0")
    }

    func testResolveMetadataReturnsNilForEmptyStoreWhenLookupMisses() {
        var looked: [String] = []
        XCTAssertNil(WidgetDeepLink.resolveMetadata(index: 0, localIdentifier: "asset-0", store: store,
                                                    assetLookup: { looked.append($0); return nil }))
        XCTAssertEqual(looked, ["asset-0"])
        XCTAssertNil(WidgetDeepLink.resolveMetadata(index: 0, localIdentifier: nil, store: nil, assetLookup: { _ in nil }))
    }

    /// First launch after upgrading, from a tap on an existing widget: the legacy metadata is gone and
    /// the file store is still empty, so the URL's localId is resolved through the photo library.
    func testResolveMetadataUsesLookupForLocalIdentifierMissingFromStore() throws {
        let looked = ["localIdentifier": "tapped", "pixelWidth": 4032, "pixelHeight": 3024] as [String: Any]

        let fromEmptyStore = WidgetDeepLink.resolveMetadata(index: 2, localIdentifier: "tapped", store: store,
                                                            assetLookup: { $0 == "tapped" ? looked : nil })
        XCTAssertEqual(fromEmptyStore?["localIdentifier"] as? String, "tapped")
        // No App Group container at all.
        let withoutStore = WidgetDeepLink.resolveMetadata(index: 2, localIdentifier: "tapped", store: nil,
                                                          assetLookup: { $0 == "tapped" ? looked : nil })
        XCTAssertEqual(withoutStore?["localIdentifier"] as? String, "tapped")

        // A stale store: the exact photo beats the index fallback.
        try save("asset-0", at: 0)
        try save("asset-2", at: 2)
        let fromStaleStore = WidgetDeepLink.resolveMetadata(index: 2, localIdentifier: "tapped", store: store,
                                                            assetLookup: { $0 == "tapped" ? looked : nil })
        XCTAssertEqual(fromStaleStore?["localIdentifier"] as? String, "tapped")
    }

    func testResolveMetadataSkipsLookupWhenStoreHasLocalIdentifier() throws {
        try save("asset-1", at: 1)
        let meta = WidgetDeepLink.resolveMetadata(index: 0, localIdentifier: "asset-1", store: store,
                                                  assetLookup: { _ in XCTFail("store match must win"); return nil })
        XCTAssertEqual(meta?["localIdentifier"] as? String, "asset-1")
    }

    func testPhotoLibraryLookupMetadataIsAPropertyList() {
        let dictionary = WidgetDeepLink.metadataDictionary(localIdentifier: "x", creationDate: nil,
                                                           pixelWidth: 10, pixelHeight: 20)
        XCTAssertEqual(dictionary["localIdentifier"] as? String, "x")
        XCTAssertNil(dictionary["creationDate"], "a nil creation date is omitted, not stored")
        XCTAssertTrue(PropertyListSerialization.propertyList(dictionary, isValidFor: .binary))
    }
}

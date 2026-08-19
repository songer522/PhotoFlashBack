import XCTest
import Photos
@testable import PhotoFlashBack

final class MediaFilterTests: XCTestCase {
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: "MediaFilterTests.\(UUID().uuidString)")
    }

    override func tearDown() {
        [MediaFilterStore.photosKey, MediaFilterStore.videosKey, MediaFilterStore.screenshotsKey].forEach {
            defaults.removeObject(forKey: $0)
        }
        defaults = nil
        super.tearDown()
    }

    func testMissingKeysLoadAsAllEnabled() {
        let filter = MediaFilterStore.load(from: defaults)
        XCTAssertTrue(filter.photos)
        XCTAssertTrue(filter.videos)
        XCTAssertTrue(filter.screenshots)
        XCTAssertTrue(filter.isEffectivelyUnfiltered)
    }

    func testSavedPhotosFlagRoundTripsAndMissingKeysStayEnabled() {
        defaults.set(false, forKey: MediaFilterStore.photosKey)
        let filter = MediaFilterStore.load(from: defaults)
        XCTAssertFalse(filter.photos)
        XCTAssertTrue(filter.videos)
        XCTAssertTrue(filter.screenshots)
    }

    func testAllOffIsUnfilteredAndIncludesEveryKind() {
        let filter = MediaFilter(photos: false, videos: false, screenshots: false)
        XCTAssertTrue(filter.isEffectivelyUnfiltered)
        XCTAssertTrue(filter.includes(kind: .photo))
        XCTAssertTrue(filter.includes(kind: .video))
        XCTAssertTrue(filter.includes(kind: .screenshot))
    }

    func testAllOnIncludesEveryKind() {
        let filter = MediaFilter(photos: true, videos: true, screenshots: true)
        XCTAssertTrue(filter.includes(kind: .photo))
        XCTAssertTrue(filter.includes(kind: .video))
        XCTAssertTrue(filter.includes(kind: .screenshot))
    }

    func testPhotosOnlyExcludesVideoAndScreenshot() {
        let filter = MediaFilter(photos: true, videos: false, screenshots: false)
        XCTAssertTrue(filter.includes(kind: .photo))
        XCTAssertFalse(filter.includes(kind: .video))
        XCTAssertFalse(filter.includes(kind: .screenshot))
    }

    func testKindClassification() {
        XCTAssertEqual(MediaFilter.kind(mediaType: .video, mediaSubtypes: []), .video)
        XCTAssertEqual(MediaFilter.kind(mediaType: .image, mediaSubtypes: .photoScreenshot), .screenshot)
        XCTAssertEqual(MediaFilter.kind(mediaType: .image, mediaSubtypes: []), .photo)
        XCTAssertEqual(MediaFilter.kind(mediaType: .image, mediaSubtypes: .photoLive), .photo)
    }

    func testSaveWritesAllFlags() {
        let filter = MediaFilter(photos: false, videos: true, screenshots: false)
        MediaFilterStore.save(filter, to: defaults)
        XCTAssertEqual(defaults.object(forKey: MediaFilterStore.photosKey) as? Bool, false)
        XCTAssertEqual(defaults.object(forKey: MediaFilterStore.videosKey) as? Bool, true)
        XCTAssertEqual(defaults.object(forKey: MediaFilterStore.screenshotsKey) as? Bool, false)
    }

    func testNormalizedForFetchMapsAllOffToAllOn() {
        let filter = MediaFilter(photos: false, videos: false, screenshots: false)
        XCTAssertEqual(filter.normalizedForFetch(), MediaFilter(photos: true, videos: true, screenshots: true))
    }
}

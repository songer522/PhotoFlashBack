import XCTest
import CoreLocation
@testable import PhotoFlashBack

/// Issue #10: the grid year headers and the full-screen viewer share one geocode + cache path,
/// and each formats the cached placemark fields its own way, whichever screen filled the cache.
final class LocationNameResolverTests: XCTestCase {
    private var directory: URL!

    private let brooklyn = PlaceComponents(
        subLocality: "Brooklyn",
        locality: "New York",
        administrativeArea: "NY",
        country: "United States"
    )
    private let location = CLLocation(latitude: 40.6782, longitude: -73.9442)
    /// About 30 m from `location`: hits the cache through the 100 m proximity match.
    private let nearbyLocation = CLLocation(latitude: 40.6784, longitude: -73.9444)

    override func setUpWithError() throws {
        try super.setUpWithError()
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("LocationNameResolverTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
        directory = nil
        try super.tearDownWithError()
    }

    private func makeResolver(place: PlaceComponents?, counter: GeocodeCounter) -> LocationNameResolver {
        LocationNameResolver(cache: LocationCache(directory: directory)) { _ in
            await counter.increment()
            return place
        }
    }

    // MARK: - Formatting

    func testHeaderNameIsMostSpecificAvailableName() {
        XCTAssertEqual(brooklyn.headerName, "Brooklyn")
        XCTAssertEqual(PlaceComponents(subLocality: nil, locality: "Austin", administrativeArea: "TX", country: "US").headerName, "Austin")
        XCTAssertEqual(PlaceComponents(subLocality: "", locality: nil, administrativeArea: "TX", country: "US").headerName, "TX")
        XCTAssertEqual(PlaceComponents(subLocality: nil, locality: nil, administrativeArea: nil, country: "Iceland").headerName, "Iceland")
        XCTAssertNil(PlaceComponents(subLocality: nil, locality: nil, administrativeArea: nil, country: nil).headerName)
    }

    func testViewerNameIsCityCommaState() {
        XCTAssertEqual(brooklyn.viewerName, "New York, NY")
        XCTAssertEqual(PlaceComponents(subLocality: "Soho", locality: "London", administrativeArea: nil, country: "UK").viewerName, "London")
        XCTAssertEqual(PlaceComponents(subLocality: nil, locality: nil, administrativeArea: "TX", country: "US").viewerName, "TX")
        XCTAssertNil(PlaceComponents(subLocality: "Soho", locality: nil, administrativeArea: nil, country: "UK").viewerName)
    }

    // MARK: - Shared cache across call sites

    func testViewerFillsCacheThenHeaderGetsHeaderFormat() async {
        let counter = GeocodeCounter()
        let resolver = makeResolver(place: brooklyn, counter: counter)

        let viewerName = await resolver.viewerName(for: location)
        let headerName = await resolver.headerName(for: nearbyLocation)

        XCTAssertEqual(viewerName, "New York, NY")
        XCTAssertEqual(headerName, "Brooklyn")
        let geocodeCount = await counter.count
        XCTAssertEqual(geocodeCount, 1, "The header lookup should be served from the cache the viewer filled")
    }

    func testHeaderFillsCacheThenViewerGetsViewerFormat() async {
        let counter = GeocodeCounter()
        let resolver = makeResolver(place: brooklyn, counter: counter)

        let headerName = await resolver.headerName(for: location)
        let viewerName = await resolver.viewerName(for: nearbyLocation)

        XCTAssertEqual(headerName, "Brooklyn")
        XCTAssertEqual(viewerName, "New York, NY")
        let geocodeCount = await counter.count
        XCTAssertEqual(geocodeCount, 1, "The viewer lookup should be served from the cache the header filled")
    }

    func testCachedPlaceSurvivesReloadFromDisk() async {
        let firstCounter = GeocodeCounter()
        let first = makeResolver(place: brooklyn, counter: firstCounter)
        _ = await first.viewerName(for: location)
        await first.cache.flushNow()

        // A fresh cache instance (as on the next launch) reads the file back.
        let secondCounter = GeocodeCounter()
        let second = makeResolver(place: nil, counter: secondCounter)
        let headerName = await second.headerName(for: location)

        XCTAssertEqual(headerName, "Brooklyn")
        let geocodeCount = await secondCounter.count
        XCTAssertEqual(geocodeCount, 0)
    }

    func testFailedOrEmptyGeocodeIsNotCached() async {
        let counter = GeocodeCounter()
        let empty = PlaceComponents(subLocality: nil, locality: nil, administrativeArea: nil, country: nil)
        let resolver = makeResolver(place: empty, counter: counter)

        let first = await resolver.viewerName(for: location)
        let second = await resolver.headerName(for: location)

        XCTAssertNil(first)
        XCTAssertNil(second)
        let geocodeCount = await counter.count
        XCTAssertEqual(geocodeCount, 2)
    }

    // MARK: - Cache versioning

    func testLegacyMixedFormatCacheFileIsDroppedNotDecoded() async throws {
        // A pre-#10 cache entry: a preformatted name in whichever format won the race.
        let legacyJSON = """
        {"40.6782,-73.9442":{"locationName":"Brooklyn","timestamp":"\(ISO8601DateFormatter().string(from: Date()))",\
        "coordinate":{"latitude":40.6782,"longitude":-73.9442}}}
        """
        let legacyURL = directory.appendingPathComponent(LocationCache.legacyFileNames[0])
        try Data(legacyJSON.utf8).write(to: legacyURL)

        let counter = GeocodeCounter()
        let resolver = makeResolver(place: brooklyn, counter: counter)
        let viewerName = await resolver.viewerName(for: location)

        XCTAssertEqual(viewerName, "New York, NY", "The legacy entry must not be served")
        let geocodeCount = await counter.count
        XCTAssertEqual(geocodeCount, 1)
        XCTAssertFalse(FileManager.default.fileExists(atPath: legacyURL.path), "The legacy cache file should be deleted")
    }
}

private actor GeocodeCounter {
    private(set) var count = 0

    func increment() {
        count += 1
    }
}

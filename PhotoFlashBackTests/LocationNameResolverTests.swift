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

    // MARK: - Throttling (issue #15)

    /// Locations spaced ~1 km apart so none of them share a cache entry (100 m match radius).
    private func distinctLocations(_ count: Int) -> [CLLocation] {
        (0..<count).map { CLLocation(latitude: 40.0 + Double($0) * 0.01, longitude: -73.0) }
    }

    func testGeocodesRunAtMostLimitAtOnceAndAllSucceed() async {
        let tracker = ConcurrencyTracker()
        let resolver = LocationNameResolver(cache: LocationCache(directory: directory), maxConcurrentGeocodes: 2) { [brooklyn] _ in
            await tracker.begin()
            try? await Task.sleep(nanoseconds: 20_000_000)
            await tracker.end()
            return brooklyn
        }

        // A 15-year library for one day: up to two geocodes per year, all started at once.
        let names = await withTaskGroup(of: String?.self) { group in
            for location in distinctLocations(30) {
                group.addTask { await resolver.headerName(for: location) }
            }
            var names: [String?] = []
            for await name in group { names.append(name) }
            return names
        }

        XCTAssertEqual(names.count, 30)
        XCTAssertTrue(names.allSatisfy { $0 == "Brooklyn" }, "Every lookup should get a name, none dropped")
        let peak = await tracker.peak
        let total = await tracker.total
        XCTAssertLessThanOrEqual(peak, 2, "No more than the limit should be geocoding at once")
        XCTAssertEqual(total, 30)
    }

    func testQueuedLookupUsesPlaceCachedWhileItWaited() async {
        let counter = GeocodeCounter()
        let resolver = LocationNameResolver(cache: LocationCache(directory: directory), maxConcurrentGeocodes: 1) { [brooklyn] _ in
            await counter.increment()
            try? await Task.sleep(nanoseconds: 50_000_000)
            return brooklyn
        }

        async let first = resolver.headerName(for: location)
        async let second = resolver.headerName(for: nearbyLocation)
        let names = await [first, second]

        XCTAssertEqual(names, ["Brooklyn", "Brooklyn"])
        let geocodeCount = await counter.count
        XCTAssertEqual(geocodeCount, 1, "The waiting lookup should be served from the cache the first one filled")
    }

    func testCachedLookupIsNotQueuedBehindRunningGeocodes() async {
        let gate = Gate()
        let paris = CLLocation(latitude: 48.8566, longitude: 2.3522)
        let resolver = LocationNameResolver(cache: LocationCache(directory: directory), maxConcurrentGeocodes: 1) { [brooklyn] _ in
            await gate.wait()
            return brooklyn
        }
        await resolver.cache.cachePlace(brooklyn, for: location)

        // Occupy the only geocode slot with a request that cannot finish yet.
        let blocked = Task { await resolver.headerName(for: paris) }
        await gate.waitUntilEntered()

        let cachedLookupReturned = expectation(description: "cached lookup returns while a geocode is running")
        Task {
            let name = await resolver.headerName(for: self.location)
            XCTAssertEqual(name, "Brooklyn")
            cachedLookupReturned.fulfill()
        }
        await fulfillment(of: [cachedLookupReturned], timeout: 2)

        await gate.open()
        _ = await blocked.value
    }

    // MARK: - MapKit address mapping (issue #15)

    /// Inputs are real `MKAddressRepresentations` values (cityName, cityWithContext(.short),
    /// regionName) observed from MapKit for these places.
    func testMapKitAddressMapsToPlaceComponents() {
        let cupertino = PlaceComponents(cityName: "Cupertino", cityWithContext: "Cupertino, CA", regionName: "United States")
        XCTAssertEqual(cupertino, PlaceComponents(subLocality: nil, locality: "Cupertino", administrativeArea: "CA", country: "United States"))
        XCTAssertEqual(cupertino.headerName, "Cupertino")
        XCTAssertEqual(cupertino.viewerName, "Cupertino, CA")

        // MapKit returns an empty cityWithContext for Brooklyn.
        let brooklyn = PlaceComponents(cityName: "Brooklyn", cityWithContext: "", regionName: "United States")
        XCTAssertEqual(brooklyn, PlaceComponents(subLocality: nil, locality: "Brooklyn", administrativeArea: nil, country: "United States"))
        XCTAssertEqual(brooklyn.headerName, "Brooklyn")
        XCTAssertEqual(brooklyn.viewerName, "Brooklyn")

        // The district comes first in cityName; cityWithContext names the city.
        let westminster = PlaceComponents(cityName: "City of Westminster, London", cityWithContext: "London, England", regionName: "United Kingdom")
        XCTAssertEqual(westminster, PlaceComponents(subLocality: "City of Westminster", locality: "London", administrativeArea: "England", country: "United Kingdom"))
        XCTAssertEqual(westminster.headerName, "City of Westminster")
        XCTAssertEqual(westminster.viewerName, "London, England")

        // The short style drops the country, leaving just the city.
        let paris = PlaceComponents(cityName: "Paris", cityWithContext: "Paris", regionName: "France")
        XCTAssertEqual(paris, PlaceComponents(subLocality: nil, locality: "Paris", administrativeArea: nil, country: "France"))

        let countryOnly = PlaceComponents(cityName: nil, cityWithContext: nil, regionName: "Iceland")
        XCTAssertEqual(countryOnly.headerName, "Iceland")
        XCTAssertNil(countryOnly.viewerName)

        // Open ocean: MapKit gives an empty city and no short context or region.
        XCTAssertTrue(PlaceComponents(cityName: "", cityWithContext: nil, regionName: nil).isEmpty)
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

/// Records how many fake geocodes are running at once.
private actor ConcurrencyTracker {
    private var running = 0
    private(set) var peak = 0
    private(set) var total = 0

    func begin() {
        running += 1
        total += 1
        peak = max(peak, running)
    }

    func end() {
        running -= 1
    }
}

/// Holds fake geocodes until the test opens it.
private actor Gate {
    private var isOpen = false
    private var hasEntered = false
    private var waiters: [CheckedContinuation<Void, Never>] = []
    private var entryWaiters: [CheckedContinuation<Void, Never>] = []

    func wait() async {
        hasEntered = true
        entryWaiters.forEach { $0.resume() }
        entryWaiters.removeAll()
        guard !isOpen else { return }
        await withCheckedContinuation { waiters.append($0) }
    }

    func waitUntilEntered() async {
        guard !hasEntered else { return }
        await withCheckedContinuation { entryWaiters.append($0) }
    }

    func open() {
        isOpen = true
        waiters.forEach { $0.resume() }
        waiters.removeAll()
    }
}

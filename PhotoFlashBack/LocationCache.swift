//
//  LocationCache.swift
//  PhotoFlashBack
//
//  Created by Claude Code on 2/9/26.
//

import Foundation
import CoreLocation

/// Raw reverse-geocoded placemark fields. The cache stores these unformatted so each screen
/// formats the same place its own way, no matter which screen geocoded it first (issue #10).
struct PlaceComponents: Codable, Equatable, Sendable {
    let subLocality: String?
    let locality: String?
    let administrativeArea: String?
    let country: String?

    init(subLocality: String?, locality: String?, administrativeArea: String?, country: String?) {
        self.subLocality = subLocality
        self.locality = locality
        self.administrativeArea = administrativeArea
        self.country = country
    }

    init(placemark: CLPlacemark) {
        self.init(
            subLocality: placemark.subLocality,
            locality: placemark.locality,
            administrativeArea: placemark.administrativeArea,
            country: placemark.country
        )
    }

    /// Grid year headers: the most specific name available, e.g. "Brooklyn".
    var headerName: String? {
        [subLocality, locality, administrativeArea, country].lazy.compactMap(Self.nonEmpty).first
    }

    /// Full-screen viewer: "City, State", e.g. "New York, NY".
    var viewerName: String? {
        let parts = [locality, administrativeArea].compactMap(Self.nonEmpty)
        return parts.isEmpty ? nil : parts.joined(separator: ", ")
    }

    /// True when no screen has anything to show for this place.
    var isEmpty: Bool {
        headerName == nil
    }

    private static func nonEmpty(_ value: String?) -> String? {
        guard let value, !value.isEmpty else { return nil }
        return value
    }
}

/// The single reverse-geocode + cache path used by both the grid year headers and the
/// full-screen viewer (issue #10).
struct LocationNameResolver: Sendable {
    typealias Geocode = @Sendable (CLLocation) async throws -> PlaceComponents?

    static let shared = LocationNameResolver(cache: .shared) { location in
        let placemarks = try await CLGeocoder().reverseGeocodeLocation(location)
        return placemarks.first.map(PlaceComponents.init(placemark:))
    }

    let cache: LocationCache
    private let geocode: Geocode

    init(cache: LocationCache, geocode: @escaping Geocode) {
        self.cache = cache
        self.geocode = geocode
    }

    /// Cached place for `location`, geocoding and caching it on a miss. Returns nil when
    /// geocoding fails or finds nothing; those results are not cached.
    func placeComponents(for location: CLLocation) async -> PlaceComponents? {
        if let cached = await cache.getCachedPlace(for: location) {
            return cached
        }
        guard let place = try? await geocode(location), !place.isEmpty else {
            return nil
        }
        await cache.cachePlace(place, for: location)
        return place
    }

    /// Name for a grid year header, e.g. "Brooklyn".
    func headerName(for location: CLLocation) async -> String? {
        await placeComponents(for: location)?.headerName
    }

    /// Name for the full-screen viewer label, e.g. "New York, NY".
    func viewerName(for location: CLLocation) async -> String? {
        await placeComponents(for: location)?.viewerName
    }
}

/// Manages caching of geocoded places to avoid repeated API calls
actor LocationCache {
    static let shared = LocationCache(
        directory: FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
    )

    /// Versioned so a schema change starts a fresh file instead of decoding old entries.
    static let fileName = "location_cache_v2.json"
    /// Earlier cache files, deleted on load. v1 held preformatted names in two different
    /// formats (issue #10).
    static let legacyFileNames = ["location_cache.json"]

    private var memoryCache: [String: CachedLocation] = [:]
    private let fileURL: URL
    private let legacyFileURLs: [URL]
    private var hasLoaded = false

    /// Shared expiry window, used by `CachedLocation.isExpired` so the two cannot drift.
    static let maxCacheAge: TimeInterval = 60 * 60 * 24 * 30 // 30 days
    /// Upper bound on the number of entries kept in the cache; oldest entries (by
    /// `timestamp`) are evicted first once this is exceeded.
    private static let maxEntryCount = 500

    /// Pending on-disk flush, coalesced so repeated inserts don't each trigger a full write.
    private var isDirty = false
    private var pendingFlushTask: Task<Void, Never>?
    private static let flushDebounceInterval: UInt64 = 5 * 1_000_000_000 // 5 seconds

    struct CachedLocation: Codable {
        let place: PlaceComponents
        let timestamp: Date
        let coordinate: CoordinateData

        var isExpired: Bool {
            Date().timeIntervalSince(timestamp) > LocationCache.maxCacheAge
        }
    }
    
    struct CoordinateData: Codable, Hashable {
        let latitude: Double
        let longitude: Double
        
        init(from location: CLLocation) {
            self.latitude = location.coordinate.latitude
            self.longitude = location.coordinate.longitude
        }
        
        func distance(from other: CoordinateData) -> Double {
            let lat1 = latitude * .pi / 180
            let lon1 = longitude * .pi / 180
            let lat2 = other.latitude * .pi / 180
            let lon2 = other.longitude * .pi / 180
            
            let dLat = lat2 - lat1
            let dLon = lon2 - lon1
            
            let a = sin(dLat/2) * sin(dLat/2) + cos(lat1) * cos(lat2) * sin(dLon/2) * sin(dLon/2)
            let c = 2 * atan2(sqrt(a), sqrt(1-a))
            let earthRadius = 6371000.0 // meters
            
            return earthRadius * c
        }
    }
    
    init(directory: URL) {
        fileURL = directory.appendingPathComponent(LocationCache.fileName)
        legacyFileURLs = LocationCache.legacyFileNames.map { directory.appendingPathComponent($0) }
    }

    /// Retrieves a cached place if available and not expired
    func getCachedPlace(for location: CLLocation) -> PlaceComponents? {
        loadIfNeeded()
        let coordinate = CoordinateData(from: location)

        // Fast path: exact key hit using the same rounding used on write.
        let key = cacheKey(for: coordinate)
        if let exact = memoryCache[key], !exact.isExpired {
            return exact.place
        }

        // Fall back to a proximity scan, returning the CLOSEST match within 100m
        // (dictionary order is arbitrary, so picking the first match would be
        // nondeterministic).
        var closest: (place: PlaceComponents, distance: Double)?
        for (_, cached) in memoryCache {
            guard !cached.isExpired else { continue }
            let distance = cached.coordinate.distance(from: coordinate)
            guard distance < 100 else { continue }
            if closest == nil || distance < closest!.distance {
                closest = (cached.place, distance)
            }
        }

        return closest?.place
    }

    /// Caches a place for future use
    func cachePlace(_ place: PlaceComponents, for location: CLLocation) {
        loadIfNeeded()
        let coordinate = CoordinateData(from: location)
        let key = cacheKey(for: coordinate)

        let cached = CachedLocation(
            place: place,
            timestamp: Date(),
            coordinate: coordinate
        )

        memoryCache[key] = cached

        scheduleFlush()
    }

    /// Clears expired entries from cache
    func clearExpiredEntries() {
        loadIfNeeded()
        memoryCache = memoryCache.filter { !$0.value.isExpired }

        scheduleFlush()
    }

    // MARK: - Private Methods

    /// Marks the cache dirty and, if no flush is already pending, schedules one a few
    /// seconds out. This coalesces bursts of inserts (e.g. one per year-group during a
    /// fetch) into a single encode + disk write instead of one per insert.
    private func scheduleFlush() {
        isDirty = true

        guard pendingFlushTask == nil else { return }

        pendingFlushTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: LocationCache.flushDebounceInterval)
            guard let self else { return }
            await self.flushIfNeeded()
        }
    }

    /// Flushes any outstanding dirty state. Called by the debounce timer, but also safe
    /// to call directly so a pending flush is never silently dropped.
    private func flushIfNeeded() async {
        pendingFlushTask = nil
        guard isDirty else { return }
        isDirty = false
        saveCache()
    }

    /// Writes any pending changes to disk now instead of waiting for the debounce.
    func flushNow() async {
        pendingFlushTask?.cancel()
        await flushIfNeeded()
    }

    private func cacheKey(for coordinate: CoordinateData) -> String {
        // Round coordinates to 4 decimal places (~11m precision)
        let lat = String(format: "%.4f", coordinate.latitude)
        let lon = String(format: "%.4f", coordinate.longitude)
        return "\(lat),\(lon)"
    }
    
    /// Loads the file on first use, inside the actor, so a late load can never replace entries
    /// cached after launch.
    private func loadIfNeeded() {
        guard !hasLoaded else { return }
        hasLoaded = true
        removeLegacyCacheFiles()
        loadCache()
    }

    private func removeLegacyCacheFiles() {
        for url in legacyFileURLs where FileManager.default.fileExists(atPath: url.path) {
            try? FileManager.default.removeItem(at: url)
        }
    }

    private func loadCache() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return
        }
        
        do {
            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            memoryCache = try decoder.decode([String: CachedLocation].self, from: data)
            
            // Remove expired entries on load
            memoryCache = memoryCache.filter { !$0.value.isExpired }
            
            print("LocationCache: Loaded \(memoryCache.count) cached locations")
        } catch {
            print("LocationCache: Failed to load cache - \(error.localizedDescription)")
            memoryCache = [:]
        }
    }
    
    private func saveCache() {
        // Cap growth: evict the oldest entries (by timestamp) once over the limit.
        if memoryCache.count > LocationCache.maxEntryCount {
            let overflow = memoryCache.count - LocationCache.maxEntryCount
            let oldestKeys = memoryCache
                .sorted { $0.value.timestamp < $1.value.timestamp }
                .prefix(overflow)
                .map { $0.key }
            for key in oldestKeys {
                memoryCache.removeValue(forKey: key)
            }
        }

        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            // This is a machine-read cache; skip .prettyPrinted to roughly halve file size.

            let data = try encoder.encode(memoryCache)
            try data.write(to: fileURL, options: .atomic)

            print("LocationCache: Saved \(memoryCache.count) locations to disk")
        } catch {
            print("LocationCache: Failed to save cache - \(error.localizedDescription)")
        }
    }
}

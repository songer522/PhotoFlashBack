//
//  LocationCache.swift
//  PhotoFlashBack
//
//  Created by Claude Code on 2/9/26.
//

import Foundation
import CoreLocation

/// Manages caching of geocoded location names to avoid repeated API calls
actor LocationCache {
    static let shared = LocationCache()
    
    private var memoryCache: [String: CachedLocation] = [:]
    private let fileURL: URL

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
        let locationName: String
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
    
    private init() {
        // Create cache directory if needed
        let cacheDirectory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        fileURL = cacheDirectory.appendingPathComponent("location_cache.json")
        
        // Load existing cache
        Task {
            await loadCache()
        }
    }
    
    /// Retrieves a cached location name if available and not expired
    func getCachedLocation(for location: CLLocation) -> String? {
        let coordinate = CoordinateData(from: location)

        // Fast path: exact key hit using the same rounding used on write.
        let key = cacheKey(for: coordinate)
        if let exact = memoryCache[key], !exact.isExpired {
            return exact.locationName
        }

        // Fall back to a proximity scan, returning the CLOSEST match within 100m
        // (dictionary order is arbitrary, so picking the first match would be
        // nondeterministic).
        var closest: (name: String, distance: Double)?
        for (_, cached) in memoryCache {
            guard !cached.isExpired else { continue }
            let distance = cached.coordinate.distance(from: coordinate)
            guard distance < 100 else { continue }
            if closest == nil || distance < closest!.distance {
                closest = (cached.locationName, distance)
            }
        }

        return closest?.name
    }

    /// Caches a location name for future use
    func cacheLocation(_ locationName: String, for location: CLLocation) {
        let coordinate = CoordinateData(from: location)
        let key = cacheKey(for: coordinate)

        let cached = CachedLocation(
            locationName: locationName,
            timestamp: Date(),
            coordinate: coordinate
        )

        memoryCache[key] = cached

        scheduleFlush()
    }

    /// Clears expired entries from cache
    func clearExpiredEntries() {
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
    
    private func cacheKey(for coordinate: CoordinateData) -> String {
        // Round coordinates to 4 decimal places (~11m precision)
        let lat = String(format: "%.4f", coordinate.latitude)
        let lon = String(format: "%.4f", coordinate.longitude)
        return "\(lat),\(lon)"
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

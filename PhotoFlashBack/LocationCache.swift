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
    private let maxCacheAge: TimeInterval = 60 * 60 * 24 * 30 // 30 days
    
    struct CachedLocation: Codable {
        let locationName: String
        let timestamp: Date
        let coordinate: CoordinateData
        
        var isExpired: Bool {
            Date().timeIntervalSince(timestamp) > 60 * 60 * 24 * 30 // 30 days
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
        
        // Check for exact match or nearby location (within 100m)
        for (_, cached) in memoryCache {
            if !cached.isExpired && cached.coordinate.distance(from: coordinate) < 100 {
                return cached.locationName
            }
        }
        
        return nil
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
        
        // Save to disk asynchronously
        Task {
            await saveCache()
        }
    }
    
    /// Clears expired entries from cache
    func clearExpiredEntries() {
        memoryCache = memoryCache.filter { !$0.value.isExpired }
        
        Task {
            await saveCache()
        }
    }
    
    /// Returns cache statistics
    func getCacheStats() -> (total: Int, expired: Int) {
        let total = memoryCache.count
        let expired = memoryCache.values.filter { $0.isExpired }.count
        return (total, expired)
    }
    
    // MARK: - Private Methods
    
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
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = .prettyPrinted
            
            let data = try encoder.encode(memoryCache)
            try data.write(to: fileURL, options: .atomic)
            
            print("LocationCache: Saved \(memoryCache.count) locations to disk")
        } catch {
            print("LocationCache: Failed to save cache - \(error.localizedDescription)")
        }
    }
}

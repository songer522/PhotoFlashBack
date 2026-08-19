//
//  PhotosViewModel.swift
//  PhotoFlashBack
//
//  Created by Yang Song on 9/19/22.
//

import UIKit
import Photos

/// Represents the current state and progress of photo fetching operations
struct PhotoFetchProgress {
    enum Phase {
        case fetchingPhotos(current: Int, total: Int)
        case groupingByYear
        case fetchingLocations(year: String, current: Int, total: Int)
        case completed
        case failed(Error)
    }
    
    let phase: Phase
    let overallProgress: Double // 0.0 to 1.0
    
    var description: String {
        switch phase {
        case .fetchingPhotos(let current, let total):
            return "Loading photos... \(current)/\(total)"
        case .groupingByYear:
            return "Organizing memories..."
        case .fetchingLocations(let year, let current, let total):
            return "Finding locations for \(year)... (\(current)/\(total))"
        case .completed:
            return "Ready!"
        case .failed(let error):
            return "Error: \(error.localizedDescription)"
        }
    }
    
    /// Creates a progress update for photo fetching
    static func fetchingPhotos(current: Int, total: Int) -> PhotoFetchProgress {
        let progress = total > 0 ? Double(current) / Double(total) * 0.6 : 0.0
        return PhotoFetchProgress(
            phase: .fetchingPhotos(current: current, total: total),
            overallProgress: progress
        )
    }
    
    /// Creates a progress update for grouping
    static func groupingByYear() -> PhotoFetchProgress {
        PhotoFetchProgress(
            phase: .groupingByYear,
            overallProgress: 0.65
        )
    }
    
    /// Creates a progress update for location fetching
    static func fetchingLocations(year: String, current: Int, total: Int) -> PhotoFetchProgress {
        let locationProgress = total > 0 ? Double(current) / Double(total) : 0.0
        let overallProgress = 0.7 + (locationProgress * 0.3)
        return PhotoFetchProgress(
            phase: .fetchingLocations(year: year, current: current, total: total),
            overallProgress: overallProgress
        )
    }
    
    /// Creates a completed progress update
    static func completed() -> PhotoFetchProgress {
        PhotoFetchProgress(
            phase: .completed,
            overallProgress: 1.0
        )
    }
    
    /// Creates a failed progress update
    static func failed(_ error: Error) -> PhotoFetchProgress {
        PhotoFetchProgress(
            phase: .failed(error),
            overallProgress: 0.0
        )
    }
}

@MainActor
class PhotosViewModel {
    var assetArray : [(String, [PHAsset])] = []
    var assetSequence : [PHAsset] = []
    var assetDict : [String: [PHAsset]] = [:]
    var locationDict : [String: String] = [:]
    let assetManager = PHImageManager.default()
    var lastAppliedFilter = MediaFilter(photos: true, videos: true, screenshots: true)
    var month = 1
    var day = 1
    var monthArray = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"]
    
    init() {
        day = Calendar.current.component(.day, from: Date())
        month = Calendar.current.component(.month, from: Date())
    }
    
    func displayDate() -> String {
        guard month >= 1 && month <= 12 else {
            return "Invalid Date"
        }
        return String(monthArray[month - 1] + " " + String(day))
    }
    
    func isToday() -> Bool {
        return day == Calendar.current.component(.day, from: Date()) && month == Calendar.current.component(.month, from: Date())
    }
    
    func fetchPhoto() async {
        locationDict.removeAll()
        assetArray.removeAll()
        assetDict.removeAll()
        assetSequence.removeAll()
        
        // Perform fetch on background thread to avoid blocking UI
        let filter = MediaFilterStore.load()
        let newAssetDict = await Task.detached(priority: .userInitiated) { [day = self.day, month = self.month, filter] in
            let options = PHFetchOptions()
            options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
            
            let predicates = Helper.compoundPredicateFrom(day: day, month: month)
            let predicate2 = NSPredicate(format: "mediaType = %d", PHAssetMediaType.image.rawValue)
            let predicate3 = NSPredicate(format: "mediaType = %d", PHAssetMediaType.video.rawValue)
            let compoundPredicate1 = NSCompoundPredicate(type: .or, subpredicates: predicates)
            let compoundPredicate2 = NSCompoundPredicate(type: .or, subpredicates: [predicate2, predicate3])
            let compoundPredicate3 = NSCompoundPredicate(type: .and, subpredicates: [compoundPredicate1, compoundPredicate2])
            options.predicate = compoundPredicate3
            
            let assetsFetchResults = PHAsset.fetchAssets(with: options)
            var tempAssetDict: [String: [PHAsset]] = [:]
            
            assetsFetchResults.enumerateObjects { (object: AnyObject, count: Int, stop: UnsafeMutablePointer<ObjCBool>) in
                if let asset = object as? PHAsset {
                    guard let creationDate = asset.creationDate else {
                        return
                    }
                    
                    let assetDay = Calendar.current.component(.day, from: creationDate)
                    let assetMonth = Calendar.current.component(.month, from: creationDate)
                    let assetYear = Calendar.current.component(.year, from: creationDate)
                    
                    if assetDay == day && assetMonth == month {
                        guard filter.includes(asset) else { return }
                        if var assetArray = tempAssetDict[String(assetYear)] {
                            assetArray.append(asset)
                            tempAssetDict[String(assetYear)] = assetArray
                        } else {
                            tempAssetDict[String(assetYear)] = [asset]
                        }
                    }
                }
            }
            
            return tempAssetDict
        }.value
        
        self.lastAppliedFilter = filter.normalizedForFetch()
        
        self.assetDict = newAssetDict
        sortAssetArray()
    }
    
    /// Fetches photos with progress tracking
    func fetchPhotoWithProgress() -> AsyncStream<PhotoFetchProgress> {
        AsyncStream { continuation in
            Task {
                do {
                    locationDict.removeAll()
                    assetArray.removeAll()
                    assetDict.removeAll()
                    assetSequence.removeAll()
                    
                    // Phase 1: Fetch photos
                    let filter = MediaFilterStore.load()
                    let newAssetDict = await Task.detached(priority: .userInitiated) { [day = self.day, month = self.month, filter] in
                        let options = PHFetchOptions()
                        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
                        
                        let predicates = Helper.compoundPredicateFrom(day: day, month: month)
                        let predicate2 = NSPredicate(format: "mediaType = %d", PHAssetMediaType.image.rawValue)
                        let predicate3 = NSPredicate(format: "mediaType = %d", PHAssetMediaType.video.rawValue)
                        let compoundPredicate1 = NSCompoundPredicate(type: .or, subpredicates: predicates)
                        let compoundPredicate2 = NSCompoundPredicate(type: .or, subpredicates: [predicate2, predicate3])
                        let compoundPredicate3 = NSCompoundPredicate(type: .and, subpredicates: [compoundPredicate1, compoundPredicate2])
                        options.predicate = compoundPredicate3
                        
                        let assetsFetchResults = PHAsset.fetchAssets(with: options)
                        var tempAssetDict: [String: [PHAsset]] = [:]
                        let totalCount = assetsFetchResults.count
                        var processedCount = 0
                        
                        assetsFetchResults.enumerateObjects { (object: AnyObject, count: Int, stop: UnsafeMutablePointer<ObjCBool>) in
                            if let asset = object as? PHAsset {
                                guard let creationDate = asset.creationDate else {
                                    processedCount += 1
                                    if processedCount % 10 == 0 || processedCount == totalCount {
                                        continuation.yield(.fetchingPhotos(current: processedCount, total: totalCount))
                                    }
                                    return
                                }
                                
                                let assetDay = Calendar.current.component(.day, from: creationDate)
                                let assetMonth = Calendar.current.component(.month, from: creationDate)
                                let assetYear = Calendar.current.component(.year, from: creationDate)
                                
                                if assetDay == day && assetMonth == month, filter.includes(asset) {
                                    if var assetArray = tempAssetDict[String(assetYear)] {
                                        assetArray.append(asset)
                                        tempAssetDict[String(assetYear)] = assetArray
                                    } else {
                                        tempAssetDict[String(assetYear)] = [asset]
                                    }
                                }
                            }
                            
                            processedCount += 1
                            // Report progress every 10 items or at the end
                            if processedCount % 10 == 0 || processedCount == totalCount {
                                continuation.yield(.fetchingPhotos(current: processedCount, total: totalCount))
                            }
                        }
                        
                        return tempAssetDict
                    }.value
                    
                    self.lastAppliedFilter = filter.normalizedForFetch()
                    
                    // Phase 2: Group by year
                    continuation.yield(.groupingByYear())
                    self.assetDict = newAssetDict
                    self.sortAssetArray()
                    
                    // Phase 3: Fetch locations (if any photos found)
                    if !self.assetDict.isEmpty {
                        await self.findLocationsWithProgress { progress in
                            continuation.yield(progress)
                        }
                    }
                    
                    // Complete
                    continuation.yield(.completed())
                    continuation.finish()
                    
                } catch {
                    continuation.yield(.failed(error))
                    continuation.finish()
                }
            }
        }
    }
    
    func sortAssetArray() {
        if Helper.isAscendingOrder() {
            assetArray = self.assetDict.sorted { $0.0 < $1.0 }
        } else {
            assetArray = self.assetDict.sorted { $0.0 > $1.0 }
        }
        
        var yearArray: [PHAsset] = []
        for (_, assets) in assetArray {
            if let asset = assets.first {
                yearArray.append(asset)
            }
        }
        yearArray.reverse()
        let yearDic = ("Rewind", yearArray)
        assetArray.insert(yearDic, at: 0)
        
        assetSequence.removeAll()
        for (_, assets) in assetArray {
            for asset in assets {
                assetSequence.append(asset)
            }
        }
    }
    
    func nextDay() async {
        if day < maxday() {
            day = day + 1
        } else {
            if month < 12 {
                month = month + 1
                day = 1
            } else {
                month = 1
                day = 1
            }
        }
        
        await fetchPhoto()
    }
    
    func previousDay() async {
        if day == 1 {
            if month == 1 {
                month = 12
                day = maxday()
            } else {
                month = month - 1
                day = maxday()
            }
        } else {
            day = day - 1
        }
        
        await fetchPhoto()
    }
    
    func maxday() -> Int {
        switch month {
        case 1, 3, 5, 7, 8, 10, 12:
            return 31
        case 4, 6, 9, 11:
            return 30
        case 2:
            // Check for leap year
            let calendar = Calendar.current
            let currentYear = calendar.component(.year, from: Date())
            let isLeapYear = calendar.range(of: .day, in: .month, for: calendar.date(from: DateComponents(year: currentYear, month: 2, day: 1))!)!.count == 29
            return isLeapYear ? 29 : 28
        default:
            return 30
        }
    }
    
    func findLocations() async {
        guard !assetDict.isEmpty else { return }
        
        // Use TaskGroup to fetch locations concurrently for all years
        await withTaskGroup(of: (String, String?).self) { group in
            for (year, assets) in assetDict {
                group.addTask {
                    let location = await self.findLocation(year: year, assets: assets)
                    return (year, location)
                }
            }
            
            // Collect results
            for await (year, location) in group {
                if let location = location {
                    self.locationDict[year] = location
                }
            }
        }
    }
    
    /// Fetches locations with progress updates
    func findLocationsWithProgress(progressHandler: @escaping (PhotoFetchProgress) -> Void) async {
        guard !assetDict.isEmpty else { return }
        
        let totalYears = assetDict.count
        var completedYears = 0
        
        // Use TaskGroup to fetch locations concurrently for all years
        await withTaskGroup(of: (String, String?).self) { group in
            for (year, assets) in assetDict {
                group.addTask {
                    let location = await self.findLocation(year: year, assets: assets)
                    return (year, location)
                }
            }
            
            // Collect results with progress updates
            for await (year, location) in group {
                if let location = location {
                    self.locationDict[year] = location
                }
                
                completedYears += 1
                progressHandler(.fetchingLocations(year: year, current: completedYears, total: totalYears))
            }
        }
    }
    
    private func findLocation(year: String, assets: [PHAsset]) async -> String? {
        // Check first and last asset for different locations
        var locations: [String] = []
        
        // Try first asset
        if let firstAsset = assets.first, let location = firstAsset.location {
            if let locationName = await reverseGeocode(location: location) {
                locations.append(locationName)
            }
        }
        
        // Try last asset if different from first
        if assets.count > 1, let lastAsset = assets.last, let location = lastAsset.location {
            if let locationName = await reverseGeocode(location: location) {
                if locations.isEmpty || locations.first != locationName {
                    locations.append(locationName)
                }
            }
        }
        
        // Return combined location string
        if locations.count == 2 {
            return "\(locations[0]) & \(locations[1])"
        } else if locations.count == 1 {
            return locations[0]
        }
        
        return nil
    }
    
    private func reverseGeocode(location: CLLocation) async -> String? {
        // Check cache first
        if let cached = await LocationCache.shared.getCachedLocation(for: location) {
            return cached
        }
        
        do {
            let placemarks = try await CLGeocoder().reverseGeocodeLocation(location)
            
            guard let placemark = placemarks.first else { return nil }
            
            // Return the most specific location available
            var locationName: String?
            if let subCity = placemark.subLocality {
                locationName = subCity
            } else if let city = placemark.locality {
                locationName = city
            } else if let state = placemark.administrativeArea {
                locationName = state
            } else if let country = placemark.country {
                locationName = country
            }
            
            // Cache the result for future use
            if let locationName = locationName {
                await LocationCache.shared.cacheLocation(locationName, for: location)
            }
            
            return locationName
        } catch {
            // Silently handle geocoding errors
            return nil
        }
    }
}

//
//  PhotoManager.swift
//  PhotoFlashBack
//
//  Created by Yang Song on 3/30/23.
//

import UIKit
import Photos

actor PhotoManager {
    static let shared = PhotoManager()

    // Shared App Group storage used to hand photos off to the Today widget.
    private static let sharedSuiteName = "group.com.YangSong.PhotoFlashBack.Today"
    // Maximum number of stored assets, matching the widget's systemLarge case (see TodayWidget.swift)
    // and the `count: 6` callers in AppDelegate/SceneDelegate.
    private static let maxStoredAssetCount = 6

    private init() {}

    private static func imageKey(for index: Int) -> String {
        index == 0 ? "randomAssetImageData" : "randomAssetImageData_\(index)"
    }

    private static func metadataKey(for index: Int) -> String {
        index == 0 ? "randomAssetMetadata" : "randomAssetMetadata_\(index)"
    }

    func requestPhotoLibraryAuthorization() async -> Bool {
        await withCheckedContinuation { continuation in
            PHPhotoLibrary.requestAuthorization { status in
                switch status {
                case .authorized, .limited:
                    continuation.resume(returning: true)
                case .denied, .restricted, .notDetermined:
                    continuation.resume(returning: false)
                @unknown default:
                    print("Warning: Unknown photo library authorization status")
                    continuation.resume(returning: false)
                }
            }
        }
    }

    /// Fetches and stores multiple random assets for widget (for medium/large widgets)
    func fetchAndStoreMultipleAssets(count: Int = 6) async -> Bool {
        let assets = await fetchMultipleRandomAssetsFromSameDayInPast(count: count)
        
        guard !assets.isEmpty else {
            print("No matching assets found.")
            return false
        }
        
        return await storeMultipleAssets(assets)
    }

    /// Fetches multiple random assets from different years
    func fetchMultipleRandomAssetsFromSameDayInPast(count: Int) async -> [PHAsset] {
        return await Task.detached(priority: .userInitiated) {
            let today = Date()
            let calendar = Calendar.current
            let todayComponents = calendar.dateComponents([.day, .month, .year], from: today)
            
            guard let day = todayComponents.day, let month = todayComponents.month, let currentYear = todayComponents.year else {
                return []
            }
            
            let fetchOptions = PHFetchOptions()
            let predicates = Helper.compoundPredicateFrom(day: day, month: month)
            let predicate2 = NSPredicate(format: "mediaType = %d", PHAssetMediaType.image.rawValue)
            let compoundPredicate1 = NSCompoundPredicate(type: .or, subpredicates: predicates)
            let compoundPredicate3 = NSCompoundPredicate(type: .and, subpredicates: [compoundPredicate1, predicate2])
            
            fetchOptions.predicate = compoundPredicate3
            
            let sameDayAndMonthPhotos = PHAsset.fetchAssets(with: fetchOptions)
            
            var assetsByYear: [Int: [PHAsset]] = [:]
            sameDayAndMonthPhotos.enumerateObjects { (asset, _, _) in
                guard let creationDate = asset.creationDate else { return }
                let assetDateComponents = calendar.dateComponents([.day, .month, .year], from: creationDate)
                guard let assetDay = assetDateComponents.day,
                      let assetMonth = assetDateComponents.month,
                      let assetYear = assetDateComponents.year,
                      assetDay == day,
                      assetMonth == month,
                      assetYear != currentYear else {
                    return
                }
                guard !asset.mediaSubtypes.contains(.photoScreenshot) else {
                    return
                }
                
                if assetsByYear[assetYear] == nil {
                    assetsByYear[assetYear] = []
                }
                assetsByYear[assetYear]?.append(asset)
            }
            
            // Select random assets from randomly selected years
            var selectedAssets: [PHAsset] = []
            var availableYears = Array(assetsByYear.keys)
            
            // Randomly shuffle the years to get variety
            availableYears.shuffle()
            
            for year in availableYears {
                guard selectedAssets.count < count else { break }
                
                if let assetsInYear = assetsByYear[year],
                   let randomAsset = assetsInYear.randomElement() {
                    selectedAssets.append(randomAsset)
                }
            }
            
            return selectedAssets
        }.value
    }



    private func storeAsset(_ asset: PHAsset, index: Int = 0) async -> Bool {
        // The PHImageManager result handler can fire on an arbitrary queue and, in some
        // cases (cancellation, a degraded-only delivery, or an iCloud download failure),
        // more than once or with only a degraded result. Guard against both leaking the
        // continuation (never resuming) and double-resuming it (which traps).
        let hasResumed = NSLock()
        var didResume = false

        return await withCheckedContinuation { continuation in
            let resume: (Bool) -> Void = { result in
                hasResumed.lock()
                let alreadyResumed = didResume
                didResume = true
                hasResumed.unlock()
                guard !alreadyResumed else { return }
                continuation.resume(returning: result)
            }

            let options = PHImageRequestOptions()
            options.isSynchronous = false
            options.isNetworkAccessAllowed = true
            options.version = .current
            options.deliveryMode = .highQualityFormat
            options.resizeMode = .fast

            let targetSize = CGSize(width: 500, height: 500)
            PHImageManager.default().requestImage(
                for: asset,
                targetSize: targetSize,
                contentMode: .aspectFill,
                options: options
            ) { (image, info) in
                if (info?[PHImageCancelledKey] as? Bool) == true || info?[PHImageErrorKey] != nil {
                    resume(false)
                    return
                }

                let isDegraded = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false
                guard !isDegraded else { return }

                guard let image = image,
                      let imageData = image.jpegData(compressionQuality: 0.8) else {
                    resume(false)
                    return
                }

                let metadata: [String: Any] = [
                    "creationDate": asset.creationDate ?? Date(),
                    "localIdentifier": asset.localIdentifier,
                    "pixelWidth": asset.pixelWidth,
                    "pixelHeight": asset.pixelHeight
                ]

                let sharedDefaults = UserDefaults(suiteName: PhotoManager.sharedSuiteName)
                let imageKey = PhotoManager.imageKey(for: index)
                let metadataKey = PhotoManager.metadataKey(for: index)

                sharedDefaults?.set(imageData, forKey: imageKey)
                sharedDefaults?.set(metadata, forKey: metadataKey)

                resume(true)
            }
        }
    }
    
    private func storeMultipleAssets(_ assets: [PHAsset]) async -> Bool {
        var success = true

        // Store assets with different keys for each
        for (index, asset) in assets.enumerated() {
            let result = await storeAsset(asset, index: index)
            if !result {
                success = false
            }
        }

        // Clear any leftover keys from a previous run that stored more assets than this run
        // did, so the widget can't read stale (wrong-day) entries at higher indices.
        clearStaleAssetKeys(from: assets.count)

        return success
    }

    /// Removes stored image/metadata keys for indices `startIndex..<maxStoredAssetCount`,
    /// which may hold data from a previous run that found more matching assets than this one did.
    private func clearStaleAssetKeys(from startIndex: Int) {
        guard startIndex < PhotoManager.maxStoredAssetCount else { return }
        let sharedDefaults = UserDefaults(suiteName: PhotoManager.sharedSuiteName)
        for index in startIndex..<PhotoManager.maxStoredAssetCount {
            sharedDefaults?.removeObject(forKey: PhotoManager.imageKey(for: index))
            sharedDefaults?.removeObject(forKey: PhotoManager.metadataKey(for: index))
        }
    }
}


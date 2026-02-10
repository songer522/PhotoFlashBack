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

    private init() {}

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

    func fetchAndStoreRandomAsset() async -> Bool {
        guard let asset = await fetchRandomAssetFromSameDayInPast() else {
            print("No matching asset found.")
            return false
        }
        
        return await storeAsset(asset)
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

    func fetchRandomAssetFromSameDayInPast() async -> PHAsset? {
        let assets = await fetchMultipleRandomAssetsFromSameDayInPast(count: 1)
        return assets.first
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
                
                if assetsByYear[assetYear] == nil {
                    assetsByYear[assetYear] = []
                }
                assetsByYear[assetYear]?.append(asset)
            }
            
            // Select random assets from different years
            var selectedAssets: [PHAsset] = []
            let sortedYears = assetsByYear.keys.sorted(by: >) // Recent years first
            
            for year in sortedYears {
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
        await withCheckedContinuation { continuation in
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
                guard let info = info else {
                    continuation.resume(returning: false)
                    return
                }
                
                let isDegraded = (info[PHImageResultIsDegradedKey] as? Bool) ?? false
                guard !isDegraded else { return }
                
                guard let image = image,
                      let imageData = image.jpegData(compressionQuality: 0.8) else {
                    continuation.resume(returning: false)
                    return
                }

                let metadata: [String: Any] = [
                    "creationDate": asset.creationDate ?? Date(),
                    "localIdentifier": asset.localIdentifier,
                    "pixelWidth": asset.pixelWidth,
                    "pixelHeight": asset.pixelHeight
                ]
                
                let sharedDefaults = UserDefaults(suiteName: "group.com.YangSong.PhotoFlashBack.Today")
                let imageKey = index == 0 ? "randomAssetImageData" : "randomAssetImageData_\(index)"
                let metadataKey = index == 0 ? "randomAssetMetadata" : "randomAssetMetadata_\(index)"
                
                sharedDefaults?.set(imageData, forKey: imageKey)
                sharedDefaults?.set(metadata, forKey: metadataKey)
                
                continuation.resume(returning: true)
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
        
        return success
    }
}


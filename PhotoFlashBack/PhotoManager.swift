//
//  PhotoManager.swift
//  PhotoFlashBack
//
//  Created by Yang Song on 3/30/23.
//

import UIKit
import Photos

class PhotoManager {
    static let shared = PhotoManager()

    private init() {}

    func requestPhotoLibraryAuthorization(completion: @escaping (Bool) -> Void) {
        PHPhotoLibrary.requestAuthorization { (status) in
            switch status {
            case .authorized:
                completion(true)
            case .denied, .restricted, .notDetermined:
                completion(false)
            @unknown default:
                fatalError("Unexpected status for photo library access.")
            }
        }
    }

    func fetchAndStoreRandomAsset(completion: @escaping (Bool) -> Void) {
        fetchRandomAssetFromSameDayInPast { (asset) in
            guard let asset = asset else {
                print("No matching asset found.")
                completion(false)
                return
            }
            
            self.storeAsset(asset, completion: completion)
        }
    }

    func fetchRandomAssetFromSameDayInPast(completion: @escaping (PHAsset?) -> Void) {
        let today = Date()
        let calendar = Calendar.current
        let todayComponents = calendar.dateComponents([.day, .month], from: today)
        
        let fetchOptions = PHFetchOptions()
        let predicates = Helper.compoundPredicateFrom(day: todayComponents.day!, month: todayComponents.month!)
        let predicate2 = NSPredicate(format: "mediaType = %d", PHAssetMediaType.image.rawValue)
        let compoundPredicate1 = NSCompoundPredicate(type: .or, subpredicates: predicates)
        let compoundPredicate3 = NSCompoundPredicate(type: .and, subpredicates: [compoundPredicate1,predicate2])
        
        
        fetchOptions.predicate = compoundPredicate3
        
        let sameDayAndMonthPhotos = PHAsset.fetchAssets(with: fetchOptions)
        
        var matchingAssets: [PHAsset] = []
        
//        sameDayAndMonthPhotos.enumerateObjects { (asset, _, _) in
//            let creationDate = asset.creationDate
//
//            guard let creationDate = creationDate else { return }
//
//            let creationDateComponents = calendar.dateComponents([.year], from: creationDate)
//            let todayComponents = calendar.dateComponents([.year], from: today)
//
//            if creationDateComponents.year != todayComponents.year {
//                matchingAssets.append(asset)
//            }
//        }
//
//        if matchingAssets.isEmpty {
//            completion(nil)
//        } else {
//            let randomIndex = Int(arc4random_uniform(UInt32(matchingAssets.count)))
//            completion(matchingAssets[randomIndex])
//        }
        
        var assetsByYear: [Int: [PHAsset]] = [:]
        sameDayAndMonthPhotos.enumerateObjects { (asset, _, _) in
            guard let creationDate = asset.creationDate else { return }
            let assetDateComponents = calendar.dateComponents([.day, .month, .year], from: creationDate)
            if assetDateComponents.day == todayComponents.day, assetDateComponents.month == todayComponents.month, assetDateComponents.year != todayComponents.year {
                let year = assetDateComponents.year!
                if assetsByYear[year] == nil {
                    assetsByYear[year] = []
                }
                assetsByYear[year]?.append(asset)
            }
        }
        
        if let randomYear = assetsByYear.keys.randomElement(), let randomAsset = assetsByYear[randomYear]?.randomElement() {
            completion(randomAsset)
        } else {
            completion(nil)
        }
    }



    private func storeAsset(_ asset: PHAsset, completion: @escaping (Bool) -> Void) {
        let options = PHImageRequestOptions()
        options.isSynchronous = false
        options.isNetworkAccessAllowed = true
        options.version = .current
        options.deliveryMode = .opportunistic
        options.resizeMode = .fast

        let targetSize = CGSize(width: 500, height: 500)
        PHImageManager.default().requestImage(for: asset,
                                              targetSize: targetSize,
                                              contentMode: .aspectFill,
                                              options: options) { (image, info) in
            guard let info = info else { return }
            let isDegraded = (info[PHImageResultIsDegradedKey] as? Bool) ?? false

            guard !isDegraded else {return}
            
            guard let image = image,
                  let imageData = image.jpegData(compressionQuality: 1.0) else {
                completion(false)
                return
            }

            let metadata: [String: Any] = [
                "creationDate": asset.creationDate ?? Date(),
                "localIdentifier": asset.localIdentifier,
                "pixelWidth": asset.pixelWidth,
                "pixelHeight": asset.pixelHeight
            ]
            let sharedDefaults = UserDefaults(suiteName: "group.com.YangSong.PhotoFlashBack.Today")
            sharedDefaults?.set(imageData, forKey: "randomAssetImageData")
            sharedDefaults?.set(metadata, forKey: "randomAssetMetadata")
            completion(true)
        }
    }
}


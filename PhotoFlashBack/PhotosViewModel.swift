//
//  PhotosViewModel.swift
//  PhotoFlashBack
//
//  Created by Yang Song on 9/19/22.
//

import UIKit
import Photos

class PhotosViewModel {
    var assetArray : [(String, [PHAsset])] = []
    var assetSequence : [PHAsset] = []
    var assetDict : [String: [PHAsset]] = Dictionary()
    let assetManager = PHImageManager.default()
    var month = 1
    var day = 1
    var monthArray = ["January", "Feburay", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"]
    
    init() {
        day = Calendar.current.component(.day, from: Date())
        month = Calendar.current.component(.month, from: Date())
    }
    
    func displayDate() -> String {
        return String(monthArray[month - 1] + " " + String(day))
    }
    
    func fetchPhoto(completion: () -> Void){
        assetArray.removeAll()
        assetDict.removeAll()
        assetSequence.removeAll()
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        options.predicate = NSPredicate(format: "mediaType = %d", PHAssetMediaType.image.rawValue)
        let assetsFetchResults = PHAsset.fetchAssets(with: options)
        assetsFetchResults.enumerateObjects({ [self] (object: AnyObject, count: Int, stop: UnsafeMutablePointer<ObjCBool>) in
            if let asset = object as? PHAsset {
                
                let assetDay = Calendar.current.component(.day, from: asset.creationDate!)
                let assetMonth = Calendar.current.component(.month, from: asset.creationDate!)
                let assetYear = Calendar.current.component(.year, from: asset.creationDate!)
                if assetDay == self.day && assetMonth == self.month {
                    if var assetArray = self.assetDict[String(assetYear)] {
                        assetArray.append(asset)
                        self.assetDict.updateValue(assetArray, forKey: String(assetYear))
                    }else {
                        self.assetDict.updateValue([asset], forKey: String(assetYear))
                    }
                    
                    
                }
            }
        })
        
        assetArray = self.assetDict.sorted { $0.0 < $1.0 }
        if assetArray.count > 0 {
            //noPhotoLabel.isHidden = true
        } else {
            //noPhotoLabel.isHidden = false
        }
        
        for (_, assets) in assetArray {
            
            for asset in assets {
                assetSequence.append(asset)
            }
            
        }
        completion()
        // self.photoCollectionView.contentOffset = CGPoint(x: 0, y: -80)
        //self.photoCollectionView.reloadData()
    }
    
    func nextDay(completion: () -> Void) {

        if day < maxday() {
            day = day + 1
        }else {
            if month < 12 {
                month = month + 1
                day = 1
            }else {
                month = 1
                day = 1
            }
        }
        
//        let dayString = String(day)
//        titleTextField?.text = String(monthArray[month - 1] + " " + dayString)
//        titleTextField?.resignFirstResponder()
        
        fetchPhoto(completion: completion)
        
    }
    
    func previousDay(completion: () -> Void) {
        if day == 1 {
            if month == 1 {
                month = 12
                day = maxday()
            }else {
                month = month - 1
                day = maxday()
            }
        }else {
        day = day - 1
        }
//        let dayString = String(day)
//        titleTextField?.text = String(monthArray[month - 1] + " " + dayString)
//        titleTextField?.resignFirstResponder()
        
        fetchPhoto(completion: completion)
        
    }
    
    func maxday() -> Int{
        if month == 1 || month == 3 || month == 5 || month == 7 || month == 8 || month == 10 || month == 12 {
            return 31
        }else if month == 4 || month == 6 || month == 9 || month == 11 {
            return 30
        }else if month == 2 {
            return 29
        }else {
            return 30
        }
    }
}

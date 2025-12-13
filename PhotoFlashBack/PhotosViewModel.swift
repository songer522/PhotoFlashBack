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
    var assetDict : [String: [PHAsset]] = [:]
    var locationDict : [String: String] = [:]
    let assetManager = PHImageManager.default()
    var month = 1
    var day = 1
    var monthArray = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"]
    var yearIndex = 0
    
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
    
    func fetchPhoto(completion: () -> Void){
        
        locationDict.removeAll()
        assetArray.removeAll()
        assetDict.removeAll()
        assetSequence.removeAll()
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        
        let predicates = Helper.compoundPredicateFrom(day: day, month: month)
        let predicate2 = NSPredicate(format: "mediaType = %d", PHAssetMediaType.image.rawValue)
        let predicate3 = NSPredicate(format: "mediaType = %d", PHAssetMediaType.video.rawValue)
        let compoundPredicate1 = NSCompoundPredicate(type: .or, subpredicates: predicates)
        let compoundPredicate2 = NSCompoundPredicate(type: .or, subpredicates: [predicate2, predicate3])
        let compoundPredicate3 = NSCompoundPredicate(type: .and, subpredicates: [compoundPredicate1,compoundPredicate2])
        options.predicate = compoundPredicate3
        let assetsFetchResults = PHAsset.fetchAssets(with: options)
        assetsFetchResults.enumerateObjects({ [self] (object: AnyObject, count: Int, stop: UnsafeMutablePointer<ObjCBool>) in
            if let asset = object as? PHAsset {
                guard let creationDate = asset.creationDate else {
                    return // Skip assets without creation date
                }
                
                let assetDay = Calendar.current.component(.day, from: creationDate)
                let assetMonth = Calendar.current.component(.month, from: creationDate)
                let assetYear = Calendar.current.component(.year, from: creationDate)
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
        
        sortAssetArray()
        completion()
    }
    
    func sortAssetArray() {
        if Helper.isAscendingOrder() {
            assetArray = self.assetDict.sorted { $0.0 < $1.0 }
        } else {
            assetArray = self.assetDict.sorted { $0.0 > $1.0 }
        }
        
        if assetArray.count > 0 {
            //noPhotoLabel.isHidden = true
        } else {
            //noPhotoLabel.isHidden = false
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
        
        for (_, assets) in assetArray {
            
            for asset in assets {
                assetSequence.append(asset)
            }
            
        }
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
    func findLocations(completion:@escaping () -> Void) {
        guard assetDict.keys.count > 0 else {
            completion()
            return
        }
        
        let keys = Array(assetDict.keys)
        guard yearIndex >= 0 && yearIndex < keys.count else {
            yearIndex = 0
            completion()
            return
        }
        
        let key = keys[yearIndex]
        if let value = assetDict[key] {
            findLocation(year: key, assetArray: value, currentIndex: 0) {
                if self.assetDict.keys.count - 1 > self.yearIndex {
                    self.yearIndex = self.yearIndex + 1
                    self.findLocations(completion: completion)
                } else {
                    self.yearIndex = 0
                    completion()
                }
            }
        } else {
            completion()
        }
    }
    
    
    func findLocation(year: String, assetArray: [PHAsset], currentIndex: Int, completion: @escaping () -> Void) {
        let geocoder = CLGeocoder()
        if currentIndex <= assetArray.count - 1 {
            let asset = assetArray[currentIndex]
            if let location = asset.location {
                geocoder.reverseGeocodeLocation(location, completionHandler: { (placemarks, error) -> Void in
                    // Place details
                    DispatchQueue.main.async {
                        guard error == nil else {
                            // Handle geocoding error gracefully
                            self.findLocation(year: year, assetArray: assetArray, currentIndex: currentIndex + 1, completion: completion)
                            return
                        }
                        
                        guard let placemarks = placemarks, !placemarks.isEmpty else {
                            self.findLocation(year: year, assetArray: assetArray, currentIndex: currentIndex + 1, completion: completion)
                            return
                        }
                        
                        let placeMark = placemarks[0]
                        var array : [String] = []
                        if let subCity = placeMark.subLocality {
                            array.append(subCity)
                        } else if let city = placeMark.locality {
                            array.append(city)
                        } else if let state = placeMark.administrativeArea {
                            array.append(state)
                        } else if let country = placeMark.country {
                            array.append(country)
                        }
                        
                        if array.count > 0 {
                            if let location = self.locationDict[year], let secondLocation = array.first, location != secondLocation {
                                //too expensive to do this
                                let newLocation = location + " & " + secondLocation
                                self.locationDict[year] = newLocation
                                completion()
                            } else {
                                self.locationDict[year] = array.first
                                if currentIndex == assetArray.count - 1 {
                                    completion()
                                } else {
                                    self.findLocation(year: year, assetArray: assetArray, currentIndex: assetArray.count - 1, completion: completion)
                                }
                            }
                        } else {
                            self.findLocation(year: year, assetArray: assetArray, currentIndex: currentIndex + 1, completion: completion)
                        }
                    }
                })
            } else {
                self.findLocation(year: year, assetArray: assetArray, currentIndex: currentIndex + 1, completion: completion)
            }
        } else {
            completion()
        }
    }
}

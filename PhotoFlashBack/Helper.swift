//
//  Helper.swift
//  PhotoFlashBack
//
//  Created by Yang Song on 9/20/22.
//

import Foundation
import Photos
import UIKit
import CoreLocation

class Helper {
    class func compoundPredicateFrom(day: Int, month: Int) -> [NSPredicate] {
        let calendar = Calendar.current
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-M-d"
        var predicates: [NSPredicate] = []
        for year in 1970...2050 {
            let dateString = String(year) + "-" + String(month) + "-" + String(day)
            if let date = dateFormatter.date(from: dateString) {
                let dateFrom = calendar.startOfDay(for: date) // eg. 2016-10-10 00:00:00
                let dateTo = calendar.date(byAdding: .day, value: 1, to: dateFrom)
                let predicate1 = NSPredicate(format: "creationDate <= %@", dateTo! as CVarArg)
                let predicate2 = NSPredicate(format: "creationDate > %@",  dateFrom as CVarArg)
                predicates.append(NSCompoundPredicate(type: .and, subpredicates: [predicate1,predicate2]))
            }
        }
        return predicates
    }
    
    
    // too bad PHFetchOption doesn't support predicate block
    class func predicateMatchingYearAndMonthInDate(day: Int, month: Int) -> NSPredicate {
        let predicate = NSPredicate { (obj, bindings) -> Bool in
            if let phAsset = obj as? PHAsset, let creationDate = phAsset.creationDate
            {
                let creationDay = Calendar.current.component(.day, from: creationDate)
                let creationMonth = Calendar.current.component(.month, from: creationDate)
                return day == creationDay && month == creationMonth && phAsset.mediaType == .image
            } else {
                return false
            }
        }
        return predicate
    }
    
    class func durationFormatter(duration: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .abbreviated
        formatter.allowedUnits = [.hour, .minute, .second]
        return formatter.string(from: duration) ?? ""
    }
    
    class func formatDateAndTime(_ date: Date) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .short
        
        return dateFormatter.string(from: date)
    }
    
    class func getYear(from asset: PHAsset) -> String {
        guard let creationDate = asset.creationDate else { return "" }
        let calendar = Calendar.current
        let year = calendar.component(.year, from: creationDate)
        return String(year)
    }
    
    class func updateAssetInfoLabelWithLocationName(asset: PHAsset, label: UILabel) {
        let creationDate = asset.creationDate ?? Date()
        let formattedDate = Helper.formatDateAndTime(creationDate)
        
        guard let location = asset.location else {
            label.text = "\(formattedDate)"
            return
        }
        
        Task {
            do {
                let placemarks = try await CLGeocoder().reverseGeocodeLocation(location)
                
                guard let placemark = placemarks.first else {
                    await MainActor.run {
                        label.text = "\(formattedDate)"
                    }
                    return
                }
                
                var locationName = ""
                
                if let city = placemark.locality {
                    locationName += city
                }
                
                if let state = placemark.administrativeArea {
                    if !locationName.isEmpty {
                        locationName += ", "
                    }
                    locationName += state
                }
                
                await MainActor.run {
                    if !locationName.isEmpty {
                        label.text = "\(locationName)\n\(formattedDate)"
                    } else {
                        label.text = "\(formattedDate)"
                    }
                }
            } catch {
                await MainActor.run {
                    label.text = "\(formattedDate)"
                }
            }
        }
    }
    
    class func windowSize() -> CGSize? {
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let sceneDelegate = scene.delegate as? SceneDelegate,
           let window = sceneDelegate.window {
            return window.bounds.size
        }
        return nil
    }
    
    class func isLandscape() -> Bool {
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let sceneDelegate = scene.delegate as? SceneDelegate,
           let window = sceneDelegate.window {
            return window.bounds.width > window.bounds.height
        }
        
        let bounds = UIScreen.main.bounds
        return bounds.width > bounds.height
    }
    
    class func isClassicLayout() -> Bool {
        UserDefaults.standard.bool(forKey: "isClassicLayout")
    }
    
    class func changeLayout() {
        let isClassicLayout = isClassicLayout()
        UserDefaults.standard.set(!isClassicLayout, forKey: "isClassicLayout")
    }
    
    class func isAscendingOrder() -> Bool {
        UserDefaults.standard.bool(forKey: "isAscendingOrder")
    }
    
    class func changeSortingOrder() {
        let isAscendingOrder = isAscendingOrder()
        UserDefaults.standard.set(!isAscendingOrder, forKey: "isAscendingOrder")
    }
}

extension UIView {
    func autoLayoutFullScreen(parentView: UIView) {
        self.translatesAutoresizingMaskIntoConstraints = false
        self.leadingAnchor.constraint(equalTo: parentView.leadingAnchor).isActive = true
        self.trailingAnchor.constraint(equalTo: parentView.trailingAnchor).isActive = true
        self.topAnchor.constraint(equalTo: parentView.topAnchor).isActive = true
        self.bottomAnchor.constraint(equalTo: parentView.bottomAnchor).isActive = true
    }
    
    func parentViewController() -> UIViewController? {
        var responder: UIResponder? = self
        while let nextResponder = responder?.next {
            if let viewController = nextResponder as? UIViewController {
                return viewController
            }
            responder = nextResponder
        }
        return nil
    }
}

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
        
        if let location = asset.location {
            let geocoder = CLGeocoder()
            geocoder.reverseGeocodeLocation(location) { placemarks, error in
                if let placemark = placemarks?.first {
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
                    
                    if !locationName.isEmpty {
                        label.text = "\(locationName)\n\(formattedDate)"
                    } else {
                        label.text = "\(formattedDate)"
                    }
                } else {
                    label.text = "\(formattedDate)"
                }
            }
        } else {
            label.text = "\(formattedDate)"
        }
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

//
//  Helper.swift
//  PhotoFlashBack
//
//  Created by Yang Song on 9/20/22.
//

import Foundation
import Photos

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
}

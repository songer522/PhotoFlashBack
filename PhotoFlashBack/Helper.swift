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
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.calendar = calendar
        dateFormatter.timeZone = .current
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
    
    @MainActor
    class func updateAssetInfoLabelWithLocationName(asset: PHAsset, label: UILabel) {
        let creationDate = asset.creationDate ?? Date()
        let formattedDate = Helper.formatDateAndTime(creationDate)
        let expectedIdentifier = asset.localIdentifier

        guard let location = asset.location else {
            expect(expectedIdentifier, for: label)
            label.text = "\(formattedDate)"
            return
        }

        expect(expectedIdentifier, for: label)

        Task {
            // Check cache first
            if let cachedLocation = await LocationCache.shared.getCachedLocation(for: location) {
                await MainActor.run {
                    guard shouldApplyLabelResult(label: label, expecting: expectedIdentifier) else { return }
                    label.text = "\(cachedLocation)\n\(formattedDate)"
                }
                return
            }

            do {
                let placemarks = try await CLGeocoder().reverseGeocodeLocation(location)

                guard let placemark = placemarks.first else {
                    await MainActor.run {
                        guard shouldApplyLabelResult(label: label, expecting: expectedIdentifier) else { return }
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

                // Cache the result
                if !locationName.isEmpty {
                    await LocationCache.shared.cacheLocation(locationName, for: location)
                }

                await MainActor.run {
                    guard shouldApplyLabelResult(label: label, expecting: expectedIdentifier) else { return }
                    if !locationName.isEmpty {
                        label.text = "\(locationName)\n\(formattedDate)"
                    } else {
                        label.text = "\(formattedDate)"
                    }
                }
            } catch {
                await MainActor.run {
                    guard shouldApplyLabelResult(label: label, expecting: expectedIdentifier) else { return }
                    label.text = "\(formattedDate)"
                }
            }
        }
    }

    /// `updateAssetInfoLabelWithLocationName` can have several reverse-geocode lookups in flight at
    /// once (e.g. swiping quickly through geo-tagged photos). Track which asset each label is
    /// currently supposed to display, keyed by the label instance, so a slow, stale lookup can't
    /// overwrite the label with a previous asset's info after a newer request has started.
    /// Weak keys so an entry disappears with its label: keying by `ObjectIdentifier` would both
    /// grow without bound and risk a freed label's address being reused by a new one.
    @MainActor
    private static let expectedAssetIdentifiers = NSMapTable<UILabel, NSString>.weakToStrongObjects()

    @MainActor
    private static func expect(_ identifier: String, for label: UILabel) {
        expectedAssetIdentifiers.setObject(identifier as NSString, forKey: label)
    }

    @MainActor
    private static func shouldApplyLabelResult(label: UILabel, expecting identifier: String) -> Bool {
        expectedAssetIdentifiers.object(forKey: label) as String? == identifier
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

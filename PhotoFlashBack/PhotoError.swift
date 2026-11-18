//
//  PhotoError.swift
//  PhotoFlashBack
//
//  Created for improved error handling
//

import Foundation

enum PhotoError: LocalizedError {
    case noPhotosFound
    case authorizationDenied
    case networkError(Error)
    case invalidAsset
    case invalidDate
    case arrayIndexOutOfBounds
    case invalidMonth(Int)
    case creationDateMissing
    case geocodingError(Error?)
    case imageProcessingFailed
    case unknown(Error?)
    
    var errorDescription: String? {
        switch self {
        case .noPhotosFound:
            return String(localized: "No photos found")
        case .authorizationDenied:
            return String(localized: "Photo library access is required")
        case .networkError(let error):
            return String(localized: "Network error: \(error.localizedDescription)")
        case .invalidAsset:
            return String(localized: "Invalid photo asset")
        case .invalidDate:
            return String(localized: "Invalid date")
        case .arrayIndexOutOfBounds:
            return String(localized: "Index out of range")
        case .invalidMonth(let month):
            return String(localized: "Invalid month: \(month)")
        case .creationDateMissing:
            return String(localized: "The photo has no creation date")
        case .geocodingError(let error):
            return String(localized: "Couldn't look up the location: \(error?.localizedDescription ?? String(localized: "Unknown error"))")
        case .imageProcessingFailed:
            return String(localized: "Image processing failed")
        case .unknown(let error):
            return String(localized: "Unknown error: \(error?.localizedDescription ?? String(localized: "Unknown"))")
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .noPhotosFound:
            return String(localized: "Try selecting a different date")
        case .authorizationDenied:
            return String(localized: "Grant photo library access in Settings")
        case .networkError:
            return String(localized: "Check your network connection and try again")
        case .invalidAsset, .invalidDate, .arrayIndexOutOfBounds, .invalidMonth:
            return String(localized: "Refresh and try again")
        case .creationDateMissing, .imageProcessingFailed:
            return String(localized: "This photo may be damaged; skip it")
        case .geocodingError:
            return String(localized: "Location information may be unavailable")
        case .unknown:
            return String(localized: "Try again later")
        }
    }
}

// Safe array access
extension Collection {
    subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

// Safe dictionary access
extension Dictionary {
    func safeValue(forKey key: Key) -> Value? {
        return self[key]
    }
}


//
//  ImageLoadingManager.swift
//  PhotoFlashBack
//
//  Created for optimized image loading
//

import UIKit
import Photos

class ImageLoadingManager {
    static let shared = ImageLoadingManager()
    
    private let imageManager: PHCachingImageManager

    private init() {
        imageManager = PHCachingImageManager()
    }
    
    // MARK: - Image Request Options Factory
    
    static func thumbnailOptions() -> PHImageRequestOptions {
        let options = PHImageRequestOptions()
        options.deliveryMode = .opportunistic
        options.resizeMode = .fast
        options.isNetworkAccessAllowed = true
        options.isSynchronous = false
        return options
    }
    
    static func fullScreenOptions() -> PHImageRequestOptions {
        let options = PHImageRequestOptions()
        options.deliveryMode = .opportunistic // Progressive loading: show low quality first, then high quality
        options.resizeMode = .none // Don't crop; keep the original aspect ratio and size
        options.isNetworkAccessAllowed = true
        options.isSynchronous = false
        options.version = .current
        return options
    }
    
    // MARK: - Optimized Size Calculation
    
    static func thumbnailSize(for cellSize: CGSize, scale: CGFloat = UIScreen.main.scale) -> CGSize {
        // Thumbnails only need 2x resolution
        return CGSize(width: cellSize.width * 2, height: cellSize.height * 2)
    }
    
    // MARK: - Prefetching
    
    func startCaching(assets: [PHAsset], targetSize: CGSize, contentMode: PHImageContentMode = .aspectFill) {
        guard !assets.isEmpty else { return }
        imageManager.startCachingImages(for: assets, targetSize: targetSize, contentMode: contentMode, options: ImageLoadingManager.thumbnailOptions())
    }
    
    func startCachingFullScreen(assets: [PHAsset], targetSize: CGSize, contentMode: PHImageContentMode = .aspectFit) {
        guard !assets.isEmpty else { return }
        imageManager.startCachingImages(for: assets, targetSize: targetSize, contentMode: contentMode, options: ImageLoadingManager.fullScreenOptions())
    }
    
    func stopCaching(assets: [PHAsset], targetSize: CGSize, contentMode: PHImageContentMode = .aspectFill) {
        guard !assets.isEmpty else { return }
        imageManager.stopCachingImages(for: assets, targetSize: targetSize, contentMode: contentMode, options: ImageLoadingManager.thumbnailOptions())
    }
    
    func stopCachingFullScreen(assets: [PHAsset], targetSize: CGSize, contentMode: PHImageContentMode = .aspectFit) {
        guard !assets.isEmpty else { return }
        imageManager.stopCachingImages(for: assets, targetSize: targetSize, contentMode: contentMode, options: ImageLoadingManager.fullScreenOptions())
    }
    
    func stopCachingAll() {
        imageManager.stopCachingImagesForAllAssets()
    }
    
    // MARK: - Image Request
    
    func requestImage(for asset: PHAsset,
                     targetSize: CGSize,
                     contentMode: PHImageContentMode = .aspectFill,
                     options: PHImageRequestOptions? = nil,
                     resultHandler: @escaping (UIImage?, [AnyHashable: Any]?) -> Void) -> PHImageRequestID {
        let requestOptions = options ?? ImageLoadingManager.thumbnailOptions()
        return imageManager.requestImage(for: asset,
                                         targetSize: targetSize,
                                         contentMode: contentMode,
                                         options: requestOptions,
                                         resultHandler: resultHandler)
    }
    
    func cancelRequest(_ requestID: PHImageRequestID) {
        imageManager.cancelImageRequest(requestID)
    }

    /// Full-screen cells are reused while PHImageManager callbacks are still in flight.
    /// Only apply a result if the cell still represents the asset that started the request.
    static func shouldApplyResult(to cellIdentifier: String?,
                                  requestedIdentifier: String,
                                  info: [AnyHashable: Any]?) -> Bool {
        if (info?[PHImageCancelledKey] as? Bool) == true {
            return false
        }
        guard let cellIdentifier else {
            return false
        }
        return cellIdentifier == requestedIdentifier
    }
}


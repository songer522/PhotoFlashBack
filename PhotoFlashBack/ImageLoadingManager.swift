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
    private let thumbnailCache = NSCache<NSString, UIImage>()
    
    private init() {
        imageManager = PHCachingImageManager()
        thumbnailCache.countLimit = 200 // 缓存最多200张缩略图
        thumbnailCache.totalCostLimit = 50 * 1024 * 1024 // 50MB内存限制
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
    
    static func highQualityOptions() -> PHImageRequestOptions {
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.resizeMode = .none // 不裁剪，保持原始比例
        options.isNetworkAccessAllowed = true
        options.isSynchronous = false
        return options
    }
    
    static func fullScreenOptions() -> PHImageRequestOptions {
        let options = PHImageRequestOptions()
        options.deliveryMode = .opportunistic // 渐进式加载：先显示低质量，再加载高质量
        options.resizeMode = .none // 不裁剪，保持原始比例和尺寸
        options.isNetworkAccessAllowed = true
        options.isSynchronous = false
        options.version = .current
        return options
    }
    
    static func fastOptions() -> PHImageRequestOptions {
        let options = PHImageRequestOptions()
        options.deliveryMode = .fastFormat
        options.resizeMode = .fast
        options.isNetworkAccessAllowed = true
        options.isSynchronous = false
        return options
    }
    
    // MARK: - Optimized Size Calculation
    
    static func thumbnailSize(for cellSize: CGSize, scale: CGFloat = UIScreen.main.scale) -> CGSize {
        // 缩略图只需要2倍分辨率即可
        return CGSize(width: cellSize.width * 2, height: cellSize.height * 2)
    }
    
    static func fullScreenSize(for viewSize: CGSize, scale: CGFloat = UIScreen.main.scale) -> CGSize {
        // 全屏图片使用实际屏幕分辨率
        return CGSize(width: viewSize.width * scale, height: viewSize.height * scale)
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
    
    // MARK: - Thumbnail Cache
    
    func cachedThumbnail(for identifier: String) -> UIImage? {
        return thumbnailCache.object(forKey: identifier as NSString)
    }
    
    func cacheThumbnail(_ image: UIImage, for identifier: String) {
        let cost = Int(image.size.width * image.size.height * 4) // 估算内存成本
        thumbnailCache.setObject(image, forKey: identifier as NSString, cost: cost)
    }
}


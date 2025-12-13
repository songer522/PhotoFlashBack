//
//  PhotosViewController+CollectionView.swift
//  PhotoFlashBack
//
//  Created by Yang Song on 9/19/22.
//

import UIKit
import Photos

extension PhotosViewController: UICollectionViewDelegate {
    
    enum Section {
        case main
    }
    
    func scrollToSection(_ section: Int, collectionView: UICollectionView) {
        let indexPath = IndexPath(item: 0, section: section)
        collectionView.scrollToItem(at: indexPath, at: .top, animated: true)
    }
    
    func scrollToItem(_ section: Int, row: Int, collectionView: UICollectionView) {
        let indexPath = IndexPath(item: row, section: section)
        collectionView.scrollToItem(at: indexPath, at: .top, animated: true)
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard indexPath.section >= 0 && indexPath.section < viewModel.assetArray.count else {
            return
        }
        
        if indexPath.section == 0 {
            let section = viewModel.assetArray.count - 1 - indexPath.row
            guard section >= 0 && section < viewModel.assetArray.count else {
                return
            }
            scrollToSection(section, collectionView: collectionView)
            return
        }
        itemTappedAt(indexPath: indexPath)
    }
    
    func itemTappedAt(indexPath: IndexPath) {
        guard indexPath.section >= 0 && indexPath.section < viewModel.assetArray.count else {
            return
        }
        guard indexPath.row >= 0 && indexPath.row < viewModel.assetArray[indexPath.section].1.count else {
            return
        }
        
        let asset = viewModel.assetArray[indexPath.section].1[indexPath.row]
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        if let imageViewerVC = storyboard.instantiateViewController(withIdentifier: "imageViewer") as? PhotoViewController, let cell = photoCollectionView.cellForItem(at: indexPath) {
            imageViewerVC.viewModel = viewModel
            let currentIndex = viewModel.assetSequence.lastIndex(of: asset) ?? 0
            guard currentIndex >= 0 && currentIndex < viewModel.assetSequence.count else {
                return
            }
            imageViewerVC.currentIndex = currentIndex
            
            imageViewerVC.modalPresentationStyle = .fullScreen
            imageViewerVC.modalPresentationCapturesStatusBarAppearance = true
            
            let customTransitioningDelegate = CustomTransitioningDelegate(sourceView: cell)
            imageViewerVC.transitioningDelegate = customTransitioningDelegate
            
            present(imageViewerVC, animated: true)
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        
        let view = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "Header", for: indexPath)
        guard indexPath.section >= 0 && indexPath.section < viewModel.assetArray.count else {
            return view
        }
        
        if let header = view as? PhotoCollectionHeaderView {
            let key = viewModel.assetArray[indexPath.section].0
            header.yearLabel.text = key
            header.dateTextField.delegate = self
            header.dateTextField.isHidden = indexPath.section != 0
            header.dateTextField.text = viewModel.displayDate()
            if let location = viewModel.locationDict[key] {
                header.locationLabel.text = location
                header.locationLabel.isHidden = indexPath.section != 0
            } else {
                header.locationLabel.text = ""
            }
            return header
        }
        
        return view
        
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, referenceSizeForHeaderInSection section: Int) -> CGSize {
        
        return CGSize(width: collectionView.bounds.width, height: 50)
    }
    
    func collectionView(_ collectionView: UICollectionView, didEndDisplayingSupplementaryView view: UICollectionReusableView, forElementOfKind elementKind: String, at indexPath: IndexPath) {
        if var headers = collectionView.visibleSupplementaryViews(ofKind: "UICollectionElementKindSectionHeader") as? [PhotoCollectionHeaderView], !headers.isEmpty {
            headers.sort {
                $0.frame.origin.y < $1.frame.origin.y
            }
            headers.first?.dateTextField.isHidden = false
            headers.first?.locationLabel.isHidden = false
        }
        
    }
    
    func collectionView(_ collectionView: UICollectionView, willDisplaySupplementaryView view: UICollectionReusableView, forElementKind elementKind: String, at indexPath: IndexPath) {
        if var headers = collectionView.visibleSupplementaryViews(ofKind: "UICollectionElementKindSectionHeader") as? [PhotoCollectionHeaderView], !headers.isEmpty, let headerView = view as? PhotoCollectionHeaderView {
            headers.sort {
                $0.frame.origin.y < $1.frame.origin.y
            }
            headers.first?.dateTextField.isHidden = headerView.frame.origin.y < (headers.first?.frame.origin.y)!
            headers.first?.locationLabel.isHidden = headerView.frame.origin.y < (headers.first?.frame.origin.y)!
            headerView.dateTextField.isHidden = headerView.frame.origin.y > (headers.first?.frame.origin.y)!
            headerView.locationLabel.isHidden = headerView.frame.origin.y > (headers.first?.frame.origin.y)!
        }
    }
    
    
    
}

extension PhotosViewController: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        guard section >= 0 && section < viewModel.assetArray.count else {
            return 0
        }
        return viewModel.assetArray[section].1.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        if let collectionCell = collectionView.dequeueReusableCell(withReuseIdentifier: "photoCell", for: indexPath) as? PhotoCollectionViewCell {
            let targetSize = CGSize(width: collectionCell.bounds.width * 2, height: collectionCell.bounds.height * 2)
            guard viewModel.assetArray.count - 1 >= indexPath.section, viewModel.assetArray[indexPath.section].1.count - 1 >= indexPath.row else {
                return collectionCell
            }
            let asset = viewModel.assetArray[indexPath.section].1[indexPath.row]
            collectionCell.identifier = asset.localIdentifier
            
            // 使用优化的图片加载管理器
            let loadingManager = ImageLoadingManager.shared
            let options = ImageLoadingManager.thumbnailOptions()
            
            // 显示骨架屏
            collectionCell.showSkeleton()
            
            collectionCell.currentImageRequestID = loadingManager.requestImage(for: asset,
                                                targetSize: targetSize,
                                                contentMode: .aspectFill,
                                                options: options,
                                                resultHandler: { [weak collectionCell] image, info in
                DispatchQueue.main.async { [weak collectionCell, weak self] in
                    guard let cell = collectionCell,
                          let self = self,
                          cell.identifier == asset.localIdentifier else {
                        return
                    }
                    
                    // 隐藏骨架屏
                    cell.hideSkeleton()
                    
                    cell.itemImageView.image = image
                    cell.itemImageView.clipsToBounds = true
                    cell.videoLengthLabel.isHidden = true
                    if indexPath.section == 0 {
                        cell.itemImageView.layer.cornerRadius = 10
                        cell.yearLabel.isHidden = false
                        cell.yearLabel.text = Helper.getYear(from: asset)
                        cell.stopVideo()
                        cell.playerView.removeFromSuperview()
                    } else {
                        cell.itemImageView.layer.cornerRadius = 0
                        cell.yearLabel.isHidden = true
                        cell.yearLabel.text = ""
                    }
                    if asset.mediaType == .video, indexPath.section != 0 {
                        cell.videoLengthLabel.isHidden = false
                        cell.videoLengthLabel.text = Helper.durationFormatter(duration: asset.duration)
                        
                        let options = PHVideoRequestOptions()
                        options.version = .current
                        options.isNetworkAccessAllowed = true
                        options.deliveryMode = .fastFormat
                        cell.currentVideoRequestID = self.viewModel.assetManager.requestPlayerItem(forVideo: asset, options: options) { [weak cell] playerItem, info in
                            DispatchQueue.main.async {
                                guard let cell = cell,
                                      let playerItem = playerItem,
                                      let requestResultID = info?["PHImageResultRequestIDKey"] as? NSNumber,
                                      requestResultID.int32Value == cell.currentVideoRequestID else {
                                    return
                                }
                                cell.setupPlayerView()
                                cell.playVideo(playerItem: playerItem)
                            }
                        }
                    }
                }
            })
            return collectionCell
        } else {
            return UICollectionViewCell()
        }
    }
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return viewModel.assetArray.count
    }
}

// MARK: - Prefetching Support
extension PhotosViewController: UICollectionViewDataSourcePrefetching {
    func collectionView(_ collectionView: UICollectionView, prefetchItemsAt indexPaths: [IndexPath]) {
        let loadingManager = ImageLoadingManager.shared
        var assetsToPrefetch: [PHAsset] = []
        
        for indexPath in indexPaths {
            guard indexPath.section >= 0 && indexPath.section < viewModel.assetArray.count else {
                continue
            }
            guard indexPath.row >= 0 && indexPath.row < viewModel.assetArray[indexPath.section].1.count else {
                continue
            }
            let asset = viewModel.assetArray[indexPath.section].1[indexPath.row]
            assetsToPrefetch.append(asset)
        }
        
        if !assetsToPrefetch.isEmpty {
            // 预加载缩略图
            let thumbnailSize = CGSize(width: 200 * 2, height: 200 * 2) // 2x scale for retina
            loadingManager.startCaching(assets: assetsToPrefetch, targetSize: thumbnailSize)
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, cancelPrefetchingForItemsAt indexPaths: [IndexPath]) {
        let loadingManager = ImageLoadingManager.shared
        var assetsToCancel: [PHAsset] = []
        
        for indexPath in indexPaths {
            guard indexPath.section >= 0 && indexPath.section < viewModel.assetArray.count else {
                continue
            }
            guard indexPath.row >= 0 && indexPath.row < viewModel.assetArray[indexPath.section].1.count else {
                continue
            }
            let asset = viewModel.assetArray[indexPath.section].1[indexPath.row]
            assetsToCancel.append(asset)
        }
        
        if !assetsToCancel.isEmpty {
            let thumbnailSize = CGSize(width: 200 * 2, height: 200 * 2)
            loadingManager.stopCaching(assets: assetsToCancel, targetSize: thumbnailSize)
        }
    }
}

extension PhotosViewController {
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        
        // In order to get the corrent size for the view, we need get the size of the container view when the animation happens or finishes (so we autolayout computes the final sizes)
        coordinator.animate(alongsideTransition: { [weak self] context in
            guard let `self` = self else { return }
            let size = context.containerView.bounds.size
            self.photoCollectionView.setCollectionViewLayout(self.createLayout(isLandscape: Helper.isLandscape(), size: size), animated: true, completion: nil)
        })
    }
    
    private func createLayout(isLandscape: Bool = false, size: CGSize) -> UICollectionViewLayout {
        return UICollectionViewCompositionalLayout { (sectionIndex, layoutEnv) -> NSCollectionLayoutSection? in
            
            if sectionIndex == 0 {
                return CustomLayouts.headerLayout()
            } else {
                if Helper.isClassicLayout() {
                    return isLandscape ? CustomLayouts.layoutB(itemSizeFraction: 0.20) : CustomLayouts.layoutB(itemSizeFraction: 0.25)
                    
                } else {
                    return isLandscape ? CustomLayouts.layoutALandscape(size: size) : CustomLayouts.layoutAPotrait(size: size)
                }
    
            }
        }
    }
    
    func configureHierarchy() {
        photoCollectionView.collectionViewLayout = createLayout(isLandscape: Helper.isLandscape(), size: view.bounds.size)
        photoCollectionView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        photoCollectionView.backgroundColor = UIColor(red: 31/255, green: 27/255, blue: 13/255, alpha: 1.0) //warmAlmostBlack
    }
    
    @objc func orientationChanged() {
        if isLandscape != Helper.isLandscape() {
            isLandscape = Helper.isLandscape()
            photoCollectionView.setCollectionViewLayout(createLayout(isLandscape: Helper.isLandscape(), size: view.bounds.size), animated: true)
        }
        
       
    }

}

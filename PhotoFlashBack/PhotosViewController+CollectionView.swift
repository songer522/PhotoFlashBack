//
//  PhotosViewController+CollectionView.swift
//  PhotoFlashBack
//
//  Created by Yang Song on 9/19/22.
//

import UIKit
import Photos
import SkeletonView

extension PhotosViewController: UICollectionViewDelegate {
    
    enum Section {
        case main
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let asset =  viewModel.assetArray[indexPath.section].1[indexPath.row]
            let storyboard = UIStoryboard(name: "Main", bundle: nil)
            if let imageViewerVC = storyboard.instantiateViewController(withIdentifier: "imageViewer") as? PhotoViewController {
                imageViewerVC.viewModel = viewModel
                let currentIndex = viewModel.assetSequence.firstIndex(of: asset) ?? 0
                imageViewerVC.currentIndex = currentIndex
                imageViewerVC.modalPresentationStyle = .fullScreen
                present(imageViewerVC, animated: true)
            }
    }
    
    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        
        let view = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "Header", for: indexPath)
        if let header = view as? PhotoCollectionHeaderView, viewModel.assetArray.count - 1 >= indexPath.section {
            let key = viewModel.assetArray[indexPath.section].0
            header.yearLabel.text = key
           // header.dateLabel.isHidden = indexPath.section != 0
            //header.dateLabel.text = viewModel.displayDate()
            header.dateTextField.delegate = self
            header.dateTextField.isHidden = indexPath.section != 0
            header.dateTextField.text = viewModel.displayDate() + " ✐"
            if let location = viewModel.locationDict[key] {
                header.locationLabel.text = location
                header.locationLabel.isHidden = indexPath.section != 0
            } else {
                header.locationLabel.text = ""
            }
            return header
        } else {
            let animation = GradientDirection.leftRight.slidingAnimation()
            let gradient = SkeletonGradient(baseColor: .asbestos)
            view.isSkeletonable = true
            view.showAnimatedGradientSkeleton(usingGradient: gradient, animation: animation)
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
           // headers.first?.dateLabel.isHidden = false
            headers.first?.dateTextField.isHidden = false
            headers.first?.locationLabel.isHidden = false
        }
        
    }
    
    func collectionView(_ collectionView: UICollectionView, willDisplaySupplementaryView view: UICollectionReusableView, forElementKind elementKind: String, at indexPath: IndexPath) {
        if var headers = collectionView.visibleSupplementaryViews(ofKind: "UICollectionElementKindSectionHeader") as? [PhotoCollectionHeaderView], !headers.isEmpty, let headerView = view as? PhotoCollectionHeaderView {
            headers.sort {
                $0.frame.origin.y < $1.frame.origin.y
            }
            
            //headers.first?.dateLabel.isHidden = headerView.frame.origin.y < (headers.first?.frame.origin.y)!
            headers.first?.dateTextField.isHidden = headerView.frame.origin.y < (headers.first?.frame.origin.y)!
            headers.first?.locationLabel.isHidden = headerView.frame.origin.y < (headers.first?.frame.origin.y)!
           // headerView.dateLabel.isHidden = headerView.frame.origin.y > (headers.first?.frame.origin.y)!
            headerView.dateTextField.isHidden = headerView.frame.origin.y > (headers.first?.frame.origin.y)!
            headerView.locationLabel.isHidden = headerView.frame.origin.y > (headers.first?.frame.origin.y)!
        }
    }
    
    
    
}

extension PhotosViewController: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return viewModel.assetArray[section].1.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let collectionCell = collectionView.dequeueReusableCell(withReuseIdentifier: "photoCell", for: indexPath) as? PhotoCollectionViewCell
        collectionCell?.playerView.isHidden = true
        collectionCell?.stopVideo()
        collectionCell?.tag = 0
        let targetSize = CGSize(width: 300, height: 300)
        guard viewModel.assetArray.count - 1 >= indexPath.section, viewModel.assetArray[indexPath.section].1.count - 1 >= indexPath.row else {
            return collectionCell!
        }
        let asset =  viewModel.assetArray[indexPath.section].1[indexPath.row]
        viewModel.assetManager.requestImage(for: asset,
                                            targetSize: targetSize,
                                            contentMode: .aspectFill,
                                            options: nil,
                                            resultHandler: { image, info in
            
            collectionCell?.itemImageView.image = image
            collectionCell?.videoLengthLabel.isHidden = asset.mediaType != .video
            if asset.mediaType == .video {
                collectionCell?.videoLengthLabel.text = Helper.durationFormatter(duration: asset.duration)
                
                let options = PHVideoRequestOptions()
                options.version = .current
                options.isNetworkAccessAllowed = true
                options.deliveryMode = .fastFormat
                let requestID = self.viewModel.assetManager.requestPlayerItem(forVideo: asset, options: options) { playerItem, info in
                    DispatchQueue.main.async {
                        if let playerItem = playerItem, let requestResultID = info?["PHImageResultRequestIDKey"] as? NSNumber  {
                            if requestResultID.intValue == collectionCell?.tag {
                                collectionCell?.playerView.isHidden = false
                                collectionCell?.setupPlayerView()
                                collectionCell?.playVideo(playerItem: playerItem)
                            }
                        }
                    }
                }
                collectionCell?.tag = Int(requestID)
            }
            
            //                                        if self.fullFeatureUnlocked == false && self.month != NSCalendar.currentCalendar().component(.Month, fromDate: NSDate()){
            //                                           collectionCell?.blurEffectView.hidden = false
            //                                        }else {
            //                                            collectionCell?.blurEffectView.hidden = true
            //                                        }
            
        })
        return collectionCell!
    }
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return viewModel.assetDict.count
    }
    
    //    func collectionView(_ collectionView: UICollectionView,
    //                          layout collectionViewLayout: UICollectionViewLayout,
    //                                 sizeForItemAtIndexPath indexPath: IndexPath) -> CGSize {
    //
    //        let width = (UIScreen.main.bounds.width - 6)/3
    //
    //        return CGSize(width: width, height: width)
    //    }
}

extension PhotosViewController {
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        
        // In order to get the corrent size for the view, we need get the size of the container view when the animation happens or finishes (so we autolayout computes the final sizes)
        coordinator.animate(alongsideTransition: { [weak self] context in
            guard let `self` = self else { return }
            let size = context.containerView.bounds.size
            
            switch UIDevice.current.orientation {
            case .landscapeLeft, .landscapeRight:
                let layout = self.createLayout(isLandscape: true, size: size)
                self.photoCollectionView.setCollectionViewLayout(layout, animated: true, completion: nil)
                self.photoCollectionView.collectionViewLayout = layout
            case .portrait, .portraitUpsideDown:
                let layout = self.createLayout(isLandscape: false, size: size)
                self.photoCollectionView.setCollectionViewLayout(layout, animated: true, completion: nil)
            default:
                return
            }
        })
    }
    
    private func createLayout(isLandscape: Bool = false, size: CGSize) -> UICollectionViewLayout {
        return UICollectionViewCompositionalLayout { (sectionIndex, layoutEnv) -> NSCollectionLayoutSection? in
            let leadingItemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(0.5),
                                                         heightDimension: .fractionalHeight(1.0))
            let leadingItem = NSCollectionLayoutItem(layoutSize: leadingItemSize)
            leadingItem.contentInsets = NSDirectionalEdgeInsets(top: 1, leading: 1, bottom: 1, trailing: 1)
            
            let trailingItemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0),
                                                          heightDimension: .fractionalHeight(0.3))
            let trailingItem = NSCollectionLayoutItem(layoutSize: trailingItemSize)
            trailingItem.contentInsets = NSDirectionalEdgeInsets(top: 1, leading: 1, bottom: 1, trailing: 1)
            
            let trailingLeftGroup = NSCollectionLayoutGroup.vertical(
                layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(0.25),
                                                   heightDimension: .fractionalHeight(1.0)),
                subitem: trailingItem, count: 2)
            
            let trailingRightGroup = NSCollectionLayoutGroup.vertical(
                layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(0.25),
                                                   heightDimension: .fractionalHeight(1.0)),
                subitem: trailingItem, count: 2)
            
            let fractionalHeight = isLandscape ? NSCollectionLayoutDimension.fractionalHeight(0.8) : NSCollectionLayoutDimension.fractionalHeight(0.4)
            let groupDimensionHeight: NSCollectionLayoutDimension = fractionalHeight
            
            let rightGroup = NSCollectionLayoutGroup.horizontal(
                layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0),
                                                   heightDimension: groupDimensionHeight),
                subitems: [leadingItem, trailingLeftGroup, trailingRightGroup])
            
            let leftGroup = NSCollectionLayoutGroup.horizontal(
                layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0),
                                                   heightDimension: groupDimensionHeight),
                subitems: [trailingRightGroup, trailingLeftGroup, leadingItem])
            
            let height = isLandscape ? size.height / 0.9 : size.height / 1.25
            let megaGroup = NSCollectionLayoutGroup.vertical(
                layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0),
                                                   heightDimension: .estimated(height)),
                subitems: [rightGroup, leftGroup])
            
            let section = NSCollectionLayoutSection(group: megaGroup)
            
            let footerHeaderSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0),
                                                          heightDimension: .absolute(50.0))
            let header = NSCollectionLayoutBoundarySupplementaryItem(
                layoutSize: footerHeaderSize,
                elementKind: UICollectionView.elementKindSectionHeader,
                alignment: .top)
            header.pinToVisibleBounds = true
            section.boundarySupplementaryItems = [header]
            return section
        }
    }
    
    func configureHierarchy() {
        photoCollectionView.collectionViewLayout = createLayout(size: view.bounds.size)
        photoCollectionView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        photoCollectionView.backgroundColor = UIColor(red: 31/255, green: 27/255, blue: 13/255, alpha: 1.0) //warmAlmostBlack

        
    }
}

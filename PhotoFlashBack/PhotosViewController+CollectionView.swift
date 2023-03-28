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
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if indexPath.section == 0 {
            let section = viewModel.assetArray.count - 1 - indexPath.row
            scrollToSection(section, collectionView: collectionView)
            return
        }
        let asset =  viewModel.assetArray[indexPath.section].1[indexPath.row]
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        if let imageViewerVC = storyboard.instantiateViewController(withIdentifier: "imageViewer") as? PhotoViewController, let cell = collectionView.cellForItem(at: indexPath) {
            imageViewerVC.viewModel = viewModel
            let currentIndex = viewModel.assetSequence.lastIndex(of: asset) ?? 0
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
        if let header = view as? PhotoCollectionHeaderView, viewModel.assetArray.count - 1 >= indexPath.section {
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
        return viewModel.assetArray[section].1.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        if let collectionCell = collectionView.dequeueReusableCell(withReuseIdentifier: "photoCell", for: indexPath) as? PhotoCollectionViewCell {
            let targetSize = CGSize(width: collectionCell.bounds.width * 2, height: collectionCell.bounds.height * 2)
            let options = PHImageRequestOptions()
            options.isNetworkAccessAllowed = true
            options.version = .current
            options.deliveryMode = .opportunistic
            options.resizeMode = .fast
            guard viewModel.assetArray.count - 1 >= indexPath.section, viewModel.assetArray[indexPath.section].1.count - 1 >= indexPath.row else {
                return collectionCell
            }
            let asset =  viewModel.assetArray[indexPath.section].1[indexPath.row]
            collectionCell.identifier = asset.localIdentifier
            collectionCell.currentImageRequestID = viewModel.assetManager.requestImage(for: asset,
                                                targetSize: targetSize,
                                                contentMode: .aspectFill,
                                                options: options,
                                                resultHandler: { image, info in
                DispatchQueue.main.async {
                    if collectionCell.identifier == asset.localIdentifier {
                        collectionCell.itemImageView.image = image
                        collectionCell.itemImageView.clipsToBounds = true
                        collectionCell.videoLengthLabel.isHidden = true
                        if indexPath.section == 0 {
                            collectionCell.itemImageView.layer.cornerRadius = 10
                            collectionCell.yearLabel.isHidden = false
                            collectionCell.yearLabel.text = Helper.getYear(from: asset)
                            collectionCell.stopVideo()
                            collectionCell.playerView.removeFromSuperview()
                        } else {
                            collectionCell.itemImageView.layer.cornerRadius = 0
                            collectionCell.yearLabel.isHidden = true
                            collectionCell.yearLabel.text = ""
                        }
                        if asset.mediaType == .video, indexPath.section != 0 {
                            collectionCell.videoLengthLabel.isHidden = false
                            collectionCell.videoLengthLabel.text = Helper.durationFormatter(duration: asset.duration)
                            
                            let options = PHVideoRequestOptions()
                            options.version = .current
                            options.isNetworkAccessAllowed = true
                            options.deliveryMode = .fastFormat
                            collectionCell.currentVideoRequestID = self.viewModel.assetManager.requestPlayerItem(forVideo: asset, options: options) { playerItem, info in
                                DispatchQueue.main.async {
                                    if let playerItem = playerItem, let requestResultID = info?["PHImageResultRequestIDKey"] as? NSNumber  {
                                        if requestResultID.int32Value == collectionCell.currentVideoRequestID {
                                            collectionCell.setupPlayerView()
                                            collectionCell.playVideo(playerItem: playerItem)
                                        }
                                    }
                                }
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
                let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(Helper.isLandscape() ? 0.25 : 1/3), heightDimension: .fractionalHeight(1.0))
                let item = NSCollectionLayoutItem(layoutSize: itemSize)
                item.contentInsets = NSDirectionalEdgeInsets(top: 5, leading: 5, bottom: 5, trailing: 5)
                
                let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .absolute(150.0))
                let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])
                
                let section = NSCollectionLayoutSection(group: group)
                let footerHeaderSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0),
                                                              heightDimension: .absolute(50.0))
                let header = NSCollectionLayoutBoundarySupplementaryItem(
                    layoutSize: footerHeaderSize,
                    elementKind: UICollectionView.elementKindSectionHeader,
                    alignment: .top)
                header.pinToVisibleBounds = true
                section.boundarySupplementaryItems = [header]
                section.orthogonalScrollingBehavior = .continuous
                
                return section
            } else {
                
                return isLandscape ? CustomLayouts.layoutB(size: size) : CustomLayouts.layoutA(size: size)
    
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

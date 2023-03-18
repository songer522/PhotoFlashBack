//
//  PhotoViewController.swift
//  PhotoFlashBack
//
//  Created by Yang Song on 10/7/22.
//

import UIKit
import Photos

class PhotoViewController: UIViewController {
    
    
    @IBOutlet weak var photoCollectionView: UICollectionView!
    var viewModel = PhotosViewModel()
    var currentIndex: Int = 0
    private let shareButton: UIButton = {
        let button = UIButton(type: .custom)
        button.setImage( UIImage(systemName: "square.and.arrow.up"), for: .normal)
        button.imageView?.tintColor = .white
        button.tintColor = .white
        button.addTarget(self, action: #selector(shareButtonTapped), for: .touchUpInside)
        return button
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let fullScreenFlowLayout = FullScreenFlowLayout()
        fullScreenFlowLayout.scrollDirection = .horizontal
        fullScreenFlowLayout.minimumLineSpacing = 0
        fullScreenFlowLayout.minimumInteritemSpacing = 0
        fullScreenFlowLayout.sectionInset = UIEdgeInsets.zero
        photoCollectionView.setCollectionViewLayout(fullScreenFlowLayout, animated: false)
        
        photoCollectionView.isPagingEnabled = true
        setupViews()
        photoCollectionView.reloadData()
        photoCollectionView.layoutIfNeeded()
        photoCollectionView.scrollToItem(at: IndexPath(item: currentIndex, section: 0), at: .centeredHorizontally, animated: false)
        setupShareButton()
        // Do any additional setup after loading the view.
    }
    
    private func setupShareButton() {
            view.addSubview(shareButton)
            shareButton.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                shareButton.widthAnchor.constraint(equalToConstant: 60),
                shareButton.heightAnchor.constraint(equalToConstant: 60),
                shareButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -8),
                shareButton.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -8)
            ])
            shareButton.imageView?.contentMode = .scaleAspectFill
        }
    func setupViews() {
        photoCollectionView.delegate = self
        photoCollectionView.dataSource = self
        photoCollectionView.contentInsetAdjustmentBehavior = .never
    }
    
    @objc private func shareButtonTapped() {
        guard let indexPath = photoCollectionView.indexPathsForVisibleItems.first,
              let cell = photoCollectionView.cellForItem(at: indexPath) as? ImageViewerCollectionViewCell,
              let image = cell.itemImageView.image else {
            return
        }

        let activityViewController = UIActivityViewController(activityItems: [image], applicationActivities: nil)
        activityViewController.popoverPresentationController?.sourceView = shareButton
        present(activityViewController, animated: true, completion: nil)
    }
}

extension PhotoViewController: UICollectionViewDelegate, UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        viewModel.assetSequence.count
    }
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        1
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let collectionCell = collectionView.dequeueReusableCell(withReuseIdentifier: "ImageViewer", for: indexPath) as? ImageViewerCollectionViewCell
        collectionCell?.playerView.isHidden = true
        collectionCell?.stopVideo()
        collectionCell?.tag = 0
        let targetSize = CGSize(width: collectionView.bounds.width, height: collectionView.bounds.height)
        let options = PHImageRequestOptions()
        options.isNetworkAccessAllowed = true
        options.version = .current
        options.deliveryMode = .opportunistic
        let asset =  viewModel.assetSequence[indexPath.row]
        viewModel.assetManager.requestImage(for: asset,
                                            targetSize: targetSize,
                                            contentMode: .aspectFill,
                                            options: options,
                                            resultHandler: { image, info in
            collectionCell?.itemImageView.image = image
            collectionCell?.videoLengthLabel.isHidden = asset.mediaType != .video
            collectionCell?.layoutSubviews()
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
        })
        return collectionCell!
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        dismiss(animated: true)
    }
}

extension PhotoViewController: UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        sizeForItemAt indexPath: IndexPath) -> CGSize {
        return CGSize(width: collectionView.bounds.width, height: collectionView.bounds.height)
    }
    
    func collectionView(_ collectionView: UICollectionView, layout
                        collectionViewLayout: UICollectionViewLayout,
                        minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        return 0
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumInteritemSpacingForSectionAt section: Int) -> CGFloat {
        return 0
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        
        // Store the current indexPath
        let currentIndexPath = photoCollectionView.indexPathsForVisibleItems.first
        
        coordinator.animate(alongsideTransition: { _ in
            self.photoCollectionView.collectionViewLayout.invalidateLayout()
            
            if let indexPath = currentIndexPath {
                // Scroll to the previously visible cell
                self.photoCollectionView.scrollToItem(at: indexPath, at: .centeredHorizontally, animated: false)
            }
        }, completion: nil)
    }
    
    
    
}

class FullScreenFlowLayout: UICollectionViewFlowLayout {
    override func shouldInvalidateLayout(forBoundsChange newBounds: CGRect) -> Bool {
        return true
    }
}

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
    override func viewDidLoad() {
        super.viewDidLoad()
        setupViews()
        photoCollectionView.reloadData()
        photoCollectionView.layoutIfNeeded()
        photoCollectionView.scrollToItem(at: IndexPath(item: currentIndex, section: 0), at: .centeredHorizontally, animated: false)
        // Do any additional setup after loading the view.
    }
    
    func setupViews() {
        photoCollectionView.delegate = self
        photoCollectionView.dataSource = self
        photoCollectionView.contentInsetAdjustmentBehavior = .never
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

}

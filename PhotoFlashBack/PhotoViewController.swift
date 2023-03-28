//
//  PhotoViewController.swift
//  PhotoFlashBack
//
//  Created by Yang Song on 10/7/22.
//

import UIKit
import Photos
import Player

class PhotoViewController: UIViewController {
    
    
    @IBOutlet weak var photoCollectionView: UICollectionView!
    var viewModel = PhotosViewModel()
    var currentIndex: Int = 0
    var player = Player()
    
    private let shareButton: UIButton = {
        let button = UIButton(type: .custom)
        button.setImage( UIImage(systemName: "square.and.arrow.up"), for: .normal)
        button.tintColor = .white
        button.addTarget(self, action: #selector(shareButtonTapped), for: .touchUpInside)
        button.backgroundColor = .lightGray
        return button
    }()
    
    private let assetInfoLabel: UILabel = {
        let label = UILabel()
        label.textColor = UIColor(red: 235/255, green: 226/255, blue: 203/255, alpha: 1.0)
        label.font = .preferredFont(forTextStyle: .body)
        label.textAlignment = .center
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    
    private let playPauseButton: UIButton = {
         let button = UIButton(type: .system)
         button.setImage(UIImage(systemName: "pause.fill"), for: .normal)
         button.tintColor = .white
         button.addTarget(self, action: #selector(playPauseButtonTapped), for: .touchUpInside)
         button.backgroundColor = .lightGray
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
        
        photoCollectionView.isPagingEnabled = false
        setupViews()
        photoCollectionView.reloadData()
        photoCollectionView.layoutIfNeeded()
        photoCollectionView.scrollToItem(at: IndexPath(item: currentIndex, section: 0), at: .centeredHorizontally, animated: true)
        let asset = viewModel.assetSequence[currentIndex]
        Helper.updateAssetInfoLabelWithLocationName(asset: asset, label: assetInfoLabel)
        photoCollectionView.isPagingEnabled = true
        setupShareButton()
        setupVideoPlayer()
        setupAssetInfoLabel()
        showVideoIfNeeded()
        // Do any additional setup after loading the view.
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        dismissVideo()
    }
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        .lightContent
    }
    
    private func setupShareButton() {
            view.addSubview(shareButton)
            shareButton.translatesAutoresizingMaskIntoConstraints = false
            let buttonSize: CGFloat = 50
            NSLayoutConstraint.activate([
                shareButton.widthAnchor.constraint(equalToConstant: buttonSize),
                shareButton.heightAnchor.constraint(equalToConstant: buttonSize),
                shareButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),
                shareButton.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -16)
            ])
            shareButton.imageView?.contentMode = .scaleAspectFill
            shareButton.layer.cornerRadius = buttonSize / 2
        }
    
    private func setupPlayPauseButton() {
        view.addSubview(playPauseButton)
        playPauseButton.isHidden = true
        playPauseButton.translatesAutoresizingMaskIntoConstraints = false
        let buttonSize: CGFloat = 60
        NSLayoutConstraint.activate([
            playPauseButton.centerXAnchor.constraint(equalTo: photoCollectionView.centerXAnchor),
            playPauseButton.centerYAnchor.constraint(equalTo: photoCollectionView.centerYAnchor),
            playPauseButton.widthAnchor.constraint(equalToConstant: buttonSize),
            playPauseButton.heightAnchor.constraint(equalToConstant: buttonSize)
        ])
        playPauseButton.layer.cornerRadius = buttonSize / 2
    }

    func setupAssetInfoLabel() {
        view.addSubview(assetInfoLabel)

        let gradientView = GradientView()
        gradientView.translatesAutoresizingMaskIntoConstraints = false
        view.insertSubview(gradientView, belowSubview: assetInfoLabel)

        NSLayoutConstraint.activate([
            assetInfoLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 0),
            assetInfoLabel.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 0),
            assetInfoLabel.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: 0),
            
            gradientView.topAnchor.constraint(equalTo: assetInfoLabel.topAnchor),
            gradientView.leadingAnchor.constraint(equalTo: assetInfoLabel.leadingAnchor),
            gradientView.trailingAnchor.constraint(equalTo: assetInfoLabel.trailingAnchor),
            gradientView.bottomAnchor.constraint(equalTo: assetInfoLabel.bottomAnchor)
        ])
    }


    func setupViews() {
        photoCollectionView.delegate = self
        photoCollectionView.dataSource = self
        photoCollectionView.contentInsetAdjustmentBehavior = .never
    }
    
    @objc private func shareButtonTapped() {
        guard let indexPath = photoCollectionView.indexPathsForVisibleItems.first,
              let cell = photoCollectionView.cellForItem(at: indexPath) as? ImageViewerCollectionViewCell else {
            return
        }
        var items: [Any] = []
        if !player.playerView.isHidden, let url = player.url {
            items.append(url)
        } else if let image = cell.itemImageView.image {
            items.append(image)
        }
        guard !items.isEmpty else { return }

        let activityViewController = UIActivityViewController(activityItems: items, applicationActivities: nil)
        activityViewController.popoverPresentationController?.sourceView = shareButton
        present(activityViewController, animated: true, completion: nil)
    }
    
    @objc func playPauseButtonTapped() {
        if let currentImage = playPauseButton.currentImage, currentImage == UIImage(systemName: "play.fill") {
            playPauseButton.setImage(UIImage(systemName: "pause.fill"), for: .normal)
            playPauseButton.isHidden = true
            player.playFromCurrentTime()
            // Add your logic to start playing here
        } else {
            playPauseButton.setImage(UIImage(systemName: "play.fill"), for: .normal)
            player.pause()
            // Add your logic to pause here
        }
    }

    
    func setupVideoPlayer() {
        player.playerDelegate = self
        player.view.frame = self.view.bounds
        player.playerView.playerBackgroundColor = .black
        let tapGestureRecognizer: UITapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(PhotoViewController.showHideOverlayButtons))
        tapGestureRecognizer.numberOfTapsRequired = 1
        player.view.addGestureRecognizer(tapGestureRecognizer)
        
        let downSwipeGestureRecognizer = UISwipeGestureRecognizer(target: self, action: #selector(PhotoViewController.dismissPage))
        downSwipeGestureRecognizer.direction = .down
        player.view.addGestureRecognizer(downSwipeGestureRecognizer)
        
        let rightSwipeGestureRecognizer = UISwipeGestureRecognizer(target: self, action: #selector(PhotoViewController.swipeRight))
        rightSwipeGestureRecognizer.direction = .right
        player.view.addGestureRecognizer(rightSwipeGestureRecognizer)
        
        let leftSwipeGestureRecognizer = UISwipeGestureRecognizer(target: self, action: #selector(PhotoViewController.swipeLeft))
        leftSwipeGestureRecognizer.direction = .left
        player.view.addGestureRecognizer(leftSwipeGestureRecognizer)
    }
    
    func playVideo(_ asset: PHAsset) {
        let options = PHVideoRequestOptions()
        options.version = .current
        options.deliveryMode = .automatic
        options.isNetworkAccessAllowed = true
        addChild(self.player)
        view.insertSubview(self.player.view, belowSubview: shareButton)
        player.didMove(toParent: self)
        player.view.autoLayoutFullScreen(parentView: view)
        player.playerView.isHidden = false
        viewModel.assetManager.requestAVAsset(forVideo: asset, options: options) { avAsset, adudioMix, info in
            if let urlAsset = avAsset as? AVURLAsset {
                DispatchQueue.main.async {
                    self.player.url = urlAsset.url
                    self.player.playFromBeginning()
                }
            }
        }
    }
    
    @objc func dismissVideo() {
        player.stop()
        player.playerView.isHidden = true
        player.willMove(toParent: nil)
        player.view.removeFromSuperview()
        player.removeFromParent()
        playPauseButton.removeFromSuperview()
        
    }
    
    @objc func dismissPage() {
        dismiss(animated: true)
    }
    
    @objc func swipeLeft() {
        guard currentIndex < viewModel.assetSequence.count - 1 else {
            return
        }
        currentIndex = currentIndex + 1
        photoCollectionView.scrollToItem(at: IndexPath(item: currentIndex, section: 0), at: .centeredHorizontally, animated: true)
        showVideoIfNeeded()
    }
    
    @objc func swipeRight() {
        guard currentIndex > 0 else {
            return
        }
        currentIndex = currentIndex - 1
        photoCollectionView.scrollToItem(at: IndexPath(item: currentIndex, section: 0), at: .centeredHorizontally, animated: true)
        showVideoIfNeeded()
    }
    
    @objc func showHideOverlayButtons() {
        playPauseButton.isHidden = !playPauseButton.isHidden
    }
    
    func showVideoIfNeeded() {
        dismissVideo()
        let asset =  viewModel.assetSequence[currentIndex]
        if asset.mediaType == .video {
            setupPlayPauseButton()
            playVideo(asset)
        }
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
        let targetSize = CGSize(width: collectionView.bounds.width * UIScreen.main.scale, height: collectionView.bounds.height * UIScreen.main.scale)
        let options = PHImageRequestOptions()
        options.isNetworkAccessAllowed = true
        options.version = .current
        options.deliveryMode = .opportunistic
        options.resizeMode = .fast
        let asset =  viewModel.assetSequence[indexPath.row]
        viewModel.assetManager.requestImage(for: asset,
                                            targetSize: targetSize,
                                            contentMode: .aspectFill,
                                            options: options,
                                            resultHandler: { image, info in
            collectionCell?.itemImageView.image = image
            collectionCell?.videoLengthLabel.isHidden = asset.mediaType != .video
            collectionCell?.layoutSubviews()
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

extension PhotoViewController: UIScrollViewDelegate {
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        dismissVideo()
        let pageIndex = Int(scrollView.contentOffset.x / photoCollectionView.bounds.width)
        currentIndex = pageIndex
        let asset =  viewModel.assetSequence[pageIndex]
        if asset.mediaType == .video {
            setupPlayPauseButton()
            playVideo(asset)
        }
        Helper.updateAssetInfoLabelWithLocationName(asset: asset, label: assetInfoLabel)
    }
}

class FullScreenFlowLayout: UICollectionViewFlowLayout {
    override func shouldInvalidateLayout(forBoundsChange newBounds: CGRect) -> Bool {
        return true
    }
}

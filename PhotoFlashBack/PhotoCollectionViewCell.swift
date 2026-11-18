//
//  PhotoCollectionViewCell.swift
//  PhotoFlashBack
//
//  Created by Yang Song on 9/19/22.
//

import UIKit
import AVFoundation
import Photos

class PhotoCollectionViewCell: UICollectionViewCell {
    @IBOutlet weak var itemImageView: UIImageView!
    @IBOutlet weak var videoLengthLabel: UILabel!
    @IBOutlet weak var yearLabel: UILabel!
    var currentImageRequestID: PHImageRequestID?
    var currentVideoRequestID: PHImageRequestID?
    var identifier: String?
    
    var playerView: PlayerView = {
        var player = PlayerView()
        player.backgroundColor = .clear
        return player
    }()
    
    var videoPlayer = AVQueuePlayer()
    var playerLooper: AVPlayerLooper?
    
    // Skeleton
    private lazy var skeletonOverlay: SkeletonCellOverlay = {
        let skeleton = SkeletonCellOverlay()
        skeleton.translatesAutoresizingMaskIntoConstraints = false
        return skeleton
    }()
    
    private var isSkeletonSetup = false
    
    override func awakeFromNib() {
        super.awakeFromNib()
        setupSkeletonView()
    }
    
    private func setupSkeletonView() {
        guard !isSkeletonSetup else { return }
        isSkeletonSetup = true
        
        contentView.addSubview(skeletonOverlay)
        NSLayoutConstraint.activate([
            skeletonOverlay.topAnchor.constraint(equalTo: contentView.topAnchor),
            skeletonOverlay.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            skeletonOverlay.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            skeletonOverlay.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])
        skeletonOverlay.isHidden = true
    }
    
    func showSkeleton() {
        setupSkeletonView()
        contentView.bringSubviewToFront(skeletonOverlay)
        skeletonOverlay.startAnimating()
    }
    
    func hideSkeleton() {
        skeletonOverlay.stopAnimating()
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        itemImageView.image = nil
        itemImageView.backgroundColor = UIColor(red: 31/255, green: 27/255, blue: 13/255, alpha: 1.0)
        showSkeleton() // Show the skeleton on reuse
        stopVideo()
        playerView.removeFromSuperview()
        
        // Release playerLooper: AVPlayerLooper needs no explicit invalidation; clearing the reference is enough
        playerLooper = nil
        
        // Stop and release videoPlayer
        videoPlayer.pause()
        videoPlayer.removeAllItems()
        videoPlayer = AVQueuePlayer()
        
        if let requestID = currentImageRequestID {
            ImageLoadingManager.shared.cancelRequest(requestID)
            currentImageRequestID = nil
        }
        if let videoRequestID = currentVideoRequestID {
            PHImageManager.default().cancelImageRequest(videoRequestID)
            currentVideoRequestID = nil
        }
    }
    
    deinit {
        // Make sure resources are released in deinit
        stopVideo()
        // Release the looper reference and clear the queue
        playerLooper = nil
        videoPlayer.removeAllItems()
    }
    
    func setupPlayerView() {
        addSubview(playerView)
        playerView.translatesAutoresizingMaskIntoConstraints = false
        playerView.topAnchor.constraint(equalTo: topAnchor).isActive = true
        playerView.leftAnchor.constraint(equalTo: leftAnchor).isActive = true
        playerView.rightAnchor.constraint(equalTo: rightAnchor).isActive = true
        playerView.bottomAnchor.constraint(equalTo: bottomAnchor).isActive = true
    }
    
    func playVideo(playerItem: AVPlayerItem) {
        // Stop any previous playback first
        stopVideo()
        
        videoPlayer = AVQueuePlayer(playerItem: playerItem)
        playerLooper = AVPlayerLooper(player: videoPlayer, templateItem: playerItem)
        videoPlayer.isMuted = true
        videoPlayer.playImmediately(atRate: 1)
        
        playerView.player = videoPlayer
    }
    
    func stopVideo() {
        playerView.player?.pause()
        // AVPlayerLooper doesn't need invalidate; just release the reference
        playerLooper = nil
        videoPlayer.removeAllItems()
    }
}

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
    
    // 骨架屏
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
        showSkeleton() // 重用时显示骨架屏
        stopVideo()
        playerView.removeFromSuperview()
        
        // 释放 playerLooper：AVPlayerLooper 无需显式失效，清空引用即可
        playerLooper = nil
        
        // 停止并释放 videoPlayer
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
        // 确保在 deinit 时释放资源
        stopVideo()
        // 释放 looper 引用并清空队列
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
        // 先停止之前的播放
        stopVideo()
        
        videoPlayer = AVQueuePlayer(playerItem: playerItem)
        playerLooper = AVPlayerLooper(player: videoPlayer, templateItem: playerItem)
        videoPlayer.isMuted = true
        videoPlayer.playImmediately(atRate: 1)
        
        playerView.player = videoPlayer
    }
    
    func stopVideo() {
        playerView.player?.pause()
        // AVPlayerLooper 不需要调用 invalidate，直接释放引用
        playerLooper = nil
        videoPlayer.removeAllItems()
    }
}

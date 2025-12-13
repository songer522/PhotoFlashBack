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
    var playerLooper: NSObject?
    
    override func prepareForReuse() {
        super.prepareForReuse()
        itemImageView.image = nil
        itemImageView.backgroundColor = UIColor(red: 31/255, green: 27/255, blue: 13/255, alpha: 1.0)
        stopVideo()
        playerView.removeFromSuperview()
        
        if let requestID = currentImageRequestID {
            ImageLoadingManager.shared.cancelRequest(requestID)
            currentImageRequestID = nil
        }
        if let videoRequestID = currentVideoRequestID {
            PHImageManager.default().cancelImageRequest(videoRequestID)
            currentVideoRequestID = nil
        }
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
        videoPlayer = AVQueuePlayer(playerItem: playerItem)
        playerLooper = AVPlayerLooper(player: videoPlayer, templateItem: playerItem)
        videoPlayer.isMuted = true
        videoPlayer.playImmediately(atRate: 1)
        
        playerView.player = videoPlayer
    }
    
    func stopVideo() {
        playerView.player?.pause()
    }
}

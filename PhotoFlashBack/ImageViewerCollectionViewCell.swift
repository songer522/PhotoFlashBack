//
//  ImageViewerCollectionViewCell.swift
//  PhotoFlashBack
//
//  Created by Yang Song on 10/7/22.
//

import UIKit
import AVFoundation

class ImageViewerCollectionViewCell: UICollectionViewCell {
    @IBOutlet weak var itemImageView: UIImageView!
    @IBOutlet weak var videoLengthLabel: UILabel!
    
    var playerView: PlayerView = {
        var player = PlayerView()
        player.backgroundColor = .clear
        return player
    }()
    
    var videoPlayer = AVQueuePlayer()
    var playerLooper: NSObject?
    
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

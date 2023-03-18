//
//  ImageViewerCollectionViewCell.swift
//  PhotoFlashBack
//
//  Created by Yang Song on 10/7/22.
//

import UIKit
import AVFoundation

class ImageViewerCollectionViewCell: UICollectionViewCell, UIScrollViewDelegate {
    var scrollView: UIScrollView!
    var itemImageView: UIImageView!
    @IBOutlet weak var videoLengthLabel: UILabel!
    
    var playerView: PlayerView = {
        var player = PlayerView()
        player.backgroundColor = .clear
        return player
    }()
    
    var videoPlayer = AVQueuePlayer()
    var playerLooper: NSObject?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupScrollView()
        setupImageView()
    }
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupScrollView()
        setupImageView()
    }
    
    private func setupScrollView() {
        scrollView = UIScrollView(frame: contentView.bounds)
        scrollView.delegate = self
        scrollView.minimumZoomScale = 1.0
        scrollView.maximumZoomScale = 3.0
        contentView.addSubview(scrollView)
        setupGestureRecognizers()
    }
    
    private func setupImageView() {
        itemImageView = UIImageView(frame: scrollView.bounds)
        itemImageView.contentMode = .scaleAspectFit
        scrollView.addSubview(itemImageView)
    }
    
    private func setupGestureRecognizers() {
        let singleTapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(handleSingleTap(_:)))
        singleTapGestureRecognizer.numberOfTapsRequired = 1
        scrollView.addGestureRecognizer(singleTapGestureRecognizer)

        let doubleTapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap(_:)))
        doubleTapGestureRecognizer.numberOfTapsRequired = 2
        scrollView.addGestureRecognizer(doubleTapGestureRecognizer)

        singleTapGestureRecognizer.require(toFail: doubleTapGestureRecognizer)
        
        let swipeGestureRecognizer = UISwipeGestureRecognizer(target: self, action: #selector(handleSingleTap(_:)))
        swipeGestureRecognizer.direction = .down
        scrollView.addGestureRecognizer(swipeGestureRecognizer)
    }

    @objc private func handleSingleTap(_ gestureRecognizer: UITapGestureRecognizer) {
        if let parentViewController = self.parentViewController() as? PhotoViewController {
            parentViewController.dismiss(animated: true, completion: nil)
        }
    }

    @objc private func handleDoubleTap(_ gestureRecognizer: UITapGestureRecognizer) {
        if scrollView.zoomScale == scrollView.minimumZoomScale {
            scrollView.setZoomScale(scrollView.maximumZoomScale, animated: true)
        } else {
            scrollView.setZoomScale(scrollView.minimumZoomScale, animated: true)
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
    
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return itemImageView
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        scrollView.frame = contentView.bounds
        itemImageView.frame = scrollView.bounds
        scrollView.contentSize = itemImageView.bounds.size
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        scrollView.setZoomScale(1.0, animated: false)
    }
}

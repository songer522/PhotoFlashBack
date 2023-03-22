//
//  PlayerView.swift
//  PhotoFlashBack
//
//  Created by Yang Song on 9/21/22.
//

import UIKit
import AVFoundation

class PlayerView: UIView {

    override static var layerClass: AnyClass {
        return AVPlayerLayer.self
    }

    var isFullScreen: Bool = false
    var playerLayer: AVPlayerLayer {
    
        return layer as! AVPlayerLayer
    }

    var player: AVPlayer? {
        get {
            return playerLayer.player
        }
    
        set {
            playerLayer.videoGravity =  isFullScreen ? .resizeAspect : .resizeAspectFill
            playerLayer.player = newValue
        }
    }
}

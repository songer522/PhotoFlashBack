//
//  GlobalActivityIndicator.swift
//  PhotoFlashBack
//
//  Created by Yang Song on 3/29/23.
//

import UIKit

class GlobalActivityIndicator {
    static let shared = GlobalActivityIndicator()
    
    private init() {}
    
    private let activityIndicator = UIActivityIndicatorView(style: .large)
    
    func show(on viewController: UIViewController) {
        DispatchQueue.main.async {
            self.activityIndicator.color = .darkGray
            self.activityIndicator.center = viewController.view.center
            self.activityIndicator.hidesWhenStopped = true
            viewController.view.addSubview(self.activityIndicator)
            self.activityIndicator.startAnimating()
        }
    }
    
    func hide() {
        DispatchQueue.main.async {
            self.activityIndicator.stopAnimating()
            self.activityIndicator.removeFromSuperview()
        }
    }
}

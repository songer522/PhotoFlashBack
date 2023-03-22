//
//  ImageViewerCollectionViewCell.swift
//  PhotoFlashBack
//
//  Created by Yang Song on 10/7/22.
//

import UIKit

class ImageViewerCollectionViewCell: UICollectionViewCell, UIScrollViewDelegate {
    var scrollView: UIScrollView!
    var itemImageView: UIImageView!
    @IBOutlet weak var videoLengthLabel: UILabel!

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

//
//  ViewController.swift
//  PhotoFlashBack
//
//  Created by Yang Song on 9/19/22.
//

import UIKit

class PhotosViewController: UIViewController {
    @IBOutlet weak var photoCollectionView: UICollectionView!
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    var viewModel = PhotosViewModel()
    override func viewDidLoad() {
        super.viewDidLoad()
        photoCollectionView.register(UICollectionViewCell.self, forCellWithReuseIdentifier: "Header")
        if let layout = photoCollectionView.collectionViewLayout as? UICollectionViewFlowLayout {
            layout.sectionHeadersPinToVisibleBounds = true
        }
        configureHierarchy()
        activityIndicator.startAnimating()
        activityIndicator.hidesWhenStopped = true
        photoCollectionView.reloadData()
        DispatchQueue.global(qos: .userInteractive).async {
            self.viewModel.fetchPhoto {
                DispatchQueue.main.async {
                    self.photoCollectionView.reloadData()
                    self.activityIndicator.stopAnimating()
                    self.viewModel.findLocations {
                        DispatchQueue.main.async {
                            self.photoCollectionView.collectionViewLayout.invalidateLayout()
                        }
                    }
                }
            }
        }
        // Do any additional setup after loading the view.
    }
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        setNeedsStatusBarAppearanceUpdate()
    }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        .lightContent
    }

}


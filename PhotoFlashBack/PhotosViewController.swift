//
//  ViewController.swift
//  PhotoFlashBack
//
//  Created by Yang Song on 9/19/22.
//

import UIKit

class PhotosViewController: UIViewController {
    @IBOutlet weak var photoCollectionView: UICollectionView!
    var viewModel = PhotosViewModel()
    override func viewDidLoad() {
        super.viewDidLoad()
        photoCollectionView.register(UICollectionViewCell.self, forCellWithReuseIdentifier: "Header")
        if let layout = photoCollectionView.collectionViewLayout as? UICollectionViewFlowLayout {
            layout.sectionHeadersPinToVisibleBounds = true
        }
        viewModel.fetchPhoto {
            DispatchQueue.main.async {
                self.photoCollectionView.reloadData()
            }
        }
        // Do any additional setup after loading the view.
    }


}


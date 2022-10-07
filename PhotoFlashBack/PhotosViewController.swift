//
//  ViewController.swift
//  PhotoFlashBack
//
//  Created by Yang Song on 9/19/22.
//

import UIKit
import SkeletonView
import Photos
import Player

class PhotosViewController: UIViewController {

    
    @IBOutlet weak var photoCollectionView: UICollectionView!
    @IBOutlet weak var emptyStateLabel: UILabel!
    var isFetching = false
    var viewModel = PhotosViewModel()
    var picker = UIPickerView()
    var player = Player()
    override func viewDidLoad() {
        super.viewDidLoad()
       // NotificationCenter.default.addObserver(self, selector: #selector(PhotosViewController.fetchPhotos), name: Notification.Name("AppToForeground"), object: nil)
        setupViews()
        if PHPhotoLibrary.authorizationStatus(for: .readWrite) != .authorized {
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
                switch status {
                case .notDetermined:
                    self.showEmptyState()
                    break
                    // The user hasn't determined this app's access.
                case .restricted:
                    self.showEmptyState()
                    break
                    // The system restricted this app's access.
                case .denied:
                    self.showEmptyState()
                    break
                    // The user explicitly denied this app's access.
                case .authorized:
                    self.fetchPhotos()
                    break
                    // The user authorized this app to access Photos data.
                case .limited:
                    self.showEmptyState()
                    break
                    // The user authorized this app for limited Photos access.
                @unknown default:
                    self.showEmptyState()
                    fatalError()
                }
            }
        } else {
            fetchPhotos()
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
    
    func setupViews() {
        photoCollectionView.register(UICollectionViewCell.self, forCellWithReuseIdentifier: "Header")
        showLoadingScreen()
        if let layout = photoCollectionView.collectionViewLayout as? UICollectionViewFlowLayout {
            layout.sectionHeadersPinToVisibleBounds = true
        }
        picker.backgroundColor = .systemFill
        picker.delegate = self
        picker.selectRow(viewModel.month - 1, inComponent: 0, animated: false)
        picker.selectRow(viewModel.day - 1, inComponent: 1, animated: false)
        configureHierarchy()
        photoCollectionView.reloadData()
        setupVideoPlayer()
    }
    
    func showLoadingScreen() {
        let animation = GradientDirection.leftRight.slidingAnimation()
        let gradient = SkeletonGradient(baseColor: .asbestos)
        photoCollectionView.isSkeletonable = true
        photoCollectionView.showAnimatedGradientSkeleton(usingGradient: gradient, animation: animation)
    }
    
   @objc func fetchPhotos() {
       print("FetchPhotos!!!!")
       guard !isFetching else {return}
       isFetching = true
        DispatchQueue.global(qos: .userInteractive).async {
            self.viewModel.fetchPhoto {
                DispatchQueue.main.async {
                    self.photoCollectionView.hideSkeleton()
                    self.photoCollectionView.reloadData()
                    self.isFetching = false
                    self.viewModel.findLocations {
                        DispatchQueue.main.async {
                            self.photoCollectionView.collectionViewLayout.invalidateLayout()
                        }
                    }
                }
            }
        }
    }
    
    func showEmptyState() {
        DispatchQueue.main.async {
            self.photoCollectionView.isHidden = true
            self.emptyStateLabel.isHidden = false
        }
    }
    
    @objc func datePicked () {
        view.endEditing(true)
        photoCollectionView.setContentOffset(CGPoint(x: 0, y: -100), animated: false)
        showLoadingScreen()
        DispatchQueue.global(qos: .userInteractive).async {
            self.viewModel.fetchPhoto {
                DispatchQueue.main.async {
                    self.photoCollectionView.hideSkeleton()
                    self.photoCollectionView.reloadData()
                    self.viewModel.findLocations {
                        DispatchQueue.main.async {
                            self.photoCollectionView.collectionViewLayout.invalidateLayout()
                        }
                    }
                }
            }
        }

        
    }
    
    @objc func dateCancelled () {
        view.endEditing(true)
    }
    
    func setupVideoPlayer() {
        player.playerDelegate = self
        //self.player.playbackDelegate = self
        player.view.frame = self.view.bounds
        player.playerView.playerBackgroundColor = .black
        let tapGestureRecognizer: UITapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(PhotosViewController.dismissVideo))
        tapGestureRecognizer.numberOfTapsRequired = 1
        player.view.addGestureRecognizer(tapGestureRecognizer)
    }
    
    @objc func dismissVideo() {
        player.stop()
        player.playerView.isHidden = true
        player.willMove(toParent: nil)
        player.view.removeFromSuperview()
        player.removeFromParent()
    }

}


//
//  ViewController.swift
//  PhotoFlashBack
//
//  Created by Yang Song on 9/19/22.
//

import UIKit
import Photos
import WidgetKit

class PhotosViewController: UIViewController {
    
    
    @IBOutlet weak var photoCollectionView: UICollectionView!
    @IBOutlet weak var emptyStateLabel: UILabel!
    private let refreshControl = UIRefreshControl()
    var isFetching = false
    var isLandscape = Helper.isLandscape()
    var viewModel = PhotosViewModel()
    
    // 加载进度视图
    private lazy var loadingProgressView: LoadingProgressView = {
        let view = LoadingProgressView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    // 空状态视图
    private lazy var emptyStateView: EmptyStateView = {
        let view = EmptyStateView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isHidden = true
        return view
    }()
    
    var picker: UIPickerView = {
        let picker = UIPickerView(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 250))
        return picker
    }()
    
    private let settingsButton: UIButton = {
        let button = UIButton(type: .custom)
        button.tintColor = .white
        if let image = UIImage(systemName: "gearshape") {
            button.setImage(image, for: .normal)
        }
        button.addTarget(self, action: #selector(settingsButtonTapped), for: .touchUpInside)
        return button
    }()
    
    private let layoutButton: UIButton = {
        let button = UIButton(type: .custom)
        button.tintColor = .white
        if let image = UIImage(systemName: "rectangle.grid.3x2") {
            button.setImage(image, for: .normal)
        }
        button.addTarget(self, action: #selector(changLayoutButtonTapped), for: .touchUpInside)
        return button
    }()
    
    private let sortingButton: UIButton = {
        let button = UIButton(type: .custom)
        button.tintColor = .white
        if let image = UIImage(systemName: "arrow.up.arrow.down") {
            button.setImage(image, for: .normal)
        }
        button.addTarget(self, action: #selector(changSortingOrderTapped), for: .touchUpInside)
        return button
    }()
    
    private let editButton: UIButton = {
        let button = UIButton(type: .custom)
        button.setImage( UIImage(systemName: "clock"), for: .normal)
        button.tintColor = .white
        button.addTarget(self, action: #selector(selectDate), for: .touchUpInside)
        button.backgroundColor = .lightGray
        return button
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupViews()
        if PHPhotoLibrary.authorizationStatus(for: .readWrite) != .authorized {
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { [weak self] status in
                guard let self = self else { return }
                switch status {
                case .notDetermined:
                    self.showEmptyState(type: .noPermission)
                    // The user hasn't determined this app's access.
                case .restricted:
                    self.showEmptyState(type: .noPermission)
                    // The system restricted this app's access.
                case .denied:
                    self.showEmptyState(type: .noPermission)
                    // The user explicitly denied this app's access.
                case .authorized:
                    self.fetchPhotos()
                    // The user authorized this app to access Photos data.
                case .limited:
                    // 有限访问权限也可以使用
                    self.fetchPhotos()
                    // The user authorized this app for limited Photos access.
                @unknown default:
                    self.showEmptyState(type: .noPermission)
                }
            }
        } else {
            fetchPhotos()

        }
        NotificationCenter.default.addObserver(self, selector: #selector(orientationChanged), name: UIDevice.orientationDidChangeNotification, object: nil)
       // NotificationCenter.default.addObserver(self, selector: #selector(PhotosViewController.fetchPhotos), name: Notification.Name("AppToForeground"), object: nil)

    }
    
    func refreshIfNotToday() {
        if !viewModel.isToday() {
            viewModel.day = Calendar.current.component(.day, from: Date())
            viewModel.month = Calendar.current.component(.month, from: Date())
            picker.selectRow(viewModel.month - 1, inComponent: 0, animated: false)
            picker.selectRow(viewModel.day - 1, inComponent: 1, animated: false)
            fetchPhotos()
        } else {
            scrollToItemIfNeeded()
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self, name: UIDevice.orientationDidChangeNotification, object: nil)
    }

    
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        setNeedsStatusBarAppearanceUpdate()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        .lightContent
    }
    
    func setupLoadingAndEmptyStateViews() {
        // 添加加载进度视图
        view.addSubview(loadingProgressView)
        NSLayoutConstraint.activate([
            loadingProgressView.topAnchor.constraint(equalTo: view.topAnchor),
            loadingProgressView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            loadingProgressView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            loadingProgressView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
        // 添加空状态视图
        view.addSubview(emptyStateView)
        NSLayoutConstraint.activate([
            emptyStateView.topAnchor.constraint(equalTo: view.topAnchor),
            emptyStateView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            emptyStateView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            emptyStateView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
        // 设置空状态视图的操作回调
        emptyStateView.onActionTapped = { [weak self] in
            self?.handleEmptyStateAction()
        }
    }
    
    private func handleEmptyStateAction() {
        // 检查当前空状态类型并执行相应操作
        if PHPhotoLibrary.authorizationStatus(for: .readWrite) != .authorized {
            // 前往设置
            if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(settingsUrl)
            }
        } else {
            // 选择日期
            selectDate()
        }
    }
    
    func showLoadingSpinner() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.emptyStateView.isHidden = true
            self.loadingProgressView.show(title: "Searching for memories...")
        }
    }
    
    func updateLoadingProgress(_ progress: Float, loaded: Int, total: Int) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            let detail = "Found \(loaded) photos"
            self.loadingProgressView.updateProgress(progress, detail: detail)
        }
    }
    
    func hideLoadingSpinner() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.loadingProgressView.hide()
        }
    }
    
    
    func setupViews() {
        photoCollectionView.register(UICollectionViewCell.self, forCellWithReuseIdentifier: "Header")
        photoCollectionView.refreshControl = refreshControl
        refreshControl.addTarget(self, action: #selector(handleRefresh), for: .valueChanged)
        if let layout = photoCollectionView.collectionViewLayout as? UICollectionViewFlowLayout {
            layout.sectionHeadersPinToVisibleBounds = true
        }
        photoCollectionView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 300, right: 0)
        picker.backgroundColor = .systemFill
        picker.delegate = self
        picker.selectRow(viewModel.month - 1, inComponent: 0, animated: false)
        picker.selectRow(viewModel.day - 1, inComponent: 1, animated: false)
        configureHierarchy()
        // 启用预加载
        if #available(iOS 10.0, *) {
            photoCollectionView.prefetchDataSource = self
        }
        photoCollectionView.reloadData()
        setupSettingsButton()
        setupLayoutButton()
        setupSortingButton()
        setupEditButton()
        setupLoadingAndEmptyStateViews()
    }
    
    @objc private func handleRefresh() {
        // Perform your data fetching or other tasks here
        fetchPhotos()
    }

    
    private func setupSettingsButton() {
        view.addSubview(settingsButton)
        settingsButton.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            settingsButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 0),
            settingsButton.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -16),
            settingsButton.widthAnchor.constraint(equalToConstant: 31),
            settingsButton.heightAnchor.constraint(equalToConstant: 31)
        ])
    }
    
    private func setupLayoutButton() {
        view.addSubview(layoutButton)
        layoutButton.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            layoutButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 0),
            layoutButton.trailingAnchor.constraint(equalTo: settingsButton.safeAreaLayoutGuide.leadingAnchor, constant: -10),
            layoutButton.widthAnchor.constraint(equalToConstant: 31),
            layoutButton.heightAnchor.constraint(equalToConstant: 31)
        ])
    }
    
    private func setupSortingButton() {
        view.addSubview(sortingButton)
        sortingButton.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            sortingButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 0),
            sortingButton.trailingAnchor.constraint(equalTo: layoutButton.safeAreaLayoutGuide.leadingAnchor, constant: -10),
            sortingButton.widthAnchor.constraint(equalToConstant: 31),
            sortingButton.heightAnchor.constraint(equalToConstant: 31)
        ])
    }
    
    private func setupEditButton() {
        view.addSubview(editButton)
        editButton.translatesAutoresizingMaskIntoConstraints = false
        let buttonSize: CGFloat = 50
        NSLayoutConstraint.activate([
            editButton.widthAnchor.constraint(equalToConstant: buttonSize),
            editButton.heightAnchor.constraint(equalToConstant: buttonSize),
            editButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),
            editButton.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -16)
        ])
        editButton.imageView?.contentMode = .scaleAspectFill
        editButton.layer.cornerRadius = buttonSize / 2
    }
    
    @objc func fetchPhotos() {
        print("FetchPhotos!!!!")
        guard !isFetching else { return }
        
        isFetching = true
        showLoadingSpinner()
        hideEmptyState()
        
        Task {
            // Use progress tracking version
            for await progress in viewModel.fetchPhotoWithProgress() {
                // Update UI based on progress
                switch progress.phase {
                case .fetchingPhotos(let current, let total):
                    updateLoadingProgress(Float(progress.overallProgress), loaded: current, total: total)
                    
                case .groupingByYear:
                    loadingProgressView.updateProgress(Float(progress.overallProgress), detail: "Organizing memories...")
                    
                case .fetchingLocations(let year, let current, let total):
                    loadingProgressView.updateProgress(Float(progress.overallProgress), detail: "Finding locations (\(current)/\(total))...")
                    
                case .completed:
                    let hasPhotos = viewModel.assetSequence.count > 0
                    
                    if hasPhotos {
                        hideEmptyState()
                        photoCollectionView.reloadData()
                        photoCollectionView.collectionViewLayout.invalidateLayout()
                        scrollToItemIfNeeded()
                    } else {
                        showEmptyState(type: .noPhotosForDate(viewModel.displayDate()))
                    }
                    
                    isFetching = false
                    hideLoadingSpinner()
                    refreshControl.endRefreshing()
                    
                case .failed(let error):
                    print("Fetch failed: \(error)")
                    showEmptyState(type: .noPhotosForDate(viewModel.displayDate()))
                    isFetching = false
                    hideLoadingSpinner()
                    refreshControl.endRefreshing()
                }
            }
        }
    }
    
    func scrollToItemIfNeeded() {
        if let itemToGo = UserDefaults.standard.object(forKey: "ItemToGo") as? [String: Any], let assetId = itemToGo["localIdentifier"] as? String, let date = itemToGo["creationDate"] as? Date  {
            let calendar = Calendar.current
            let year = calendar.component(.year, from: date)
            let yearString = String(year)
            
            let filteredArrayWithIndex = viewModel.assetArray.enumerated().compactMap { index, yearArray -> (Int, (String, [PHAsset]))? in
                return yearArray.0 == yearString ? (index, yearArray) : nil
            }
            
            let filteredItemWithIndex = filteredArrayWithIndex.first?.1.1.enumerated().compactMap {index, asset -> (Int, PHAsset)? in
                return asset.localIdentifier == assetId ? (index, asset) : nil
            }
            if let section = filteredArrayWithIndex.first?.0, let row = filteredItemWithIndex?.first?.0 {
                scrollToItem(section, row: row, collectionView: photoCollectionView)
                let delayInSeconds: TimeInterval = 0.5 // Delay of 5 seconds

                DispatchQueue.main.asyncAfter(deadline: .now() + delayInSeconds) {
                    self.itemTappedAt(indexPath: IndexPath(item: row, section: section))
                }
                
            }
            UserDefaults.standard.set(nil, forKey: "ItemToGo")
        }
    }
    
    func showEmptyState(type: EmptyStateView.EmptyStateType? = nil) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.photoCollectionView.isHidden = true
            self.emptyStateLabel.isHidden = true // 隐藏旧的空状态标签
            self.emptyStateView.isHidden = false
            
            // 根据类型配置空状态视图
            let stateType: EmptyStateView.EmptyStateType
            if let type = type {
                stateType = type
            } else if PHPhotoLibrary.authorizationStatus(for: .readWrite) != .authorized {
                stateType = .noPermission
            } else {
                stateType = .noPhotosForDate(self.viewModel.displayDate())
            }
            self.emptyStateView.configure(for: stateType)
        }
    }
    
    func hideEmptyState() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.photoCollectionView.isHidden = false
            self.emptyStateLabel.isHidden = true
            self.emptyStateView.isHidden = true
        }
    }
    
    func getTopVisibleSectionHeader() -> UICollectionReusableView? {
        let headerKind = UICollectionView.elementKindSectionHeader
        let visibleHeaderIndexPaths = photoCollectionView.indexPathsForVisibleSupplementaryElements(ofKind: headerKind)
        
        if !visibleHeaderIndexPaths.isEmpty {
            let sortedIndexPaths = visibleHeaderIndexPaths.sorted { $0.section < $1.section }
            let topHeaderIndexPath = sortedIndexPaths.first!
            return photoCollectionView.supplementaryView(forElementKind: headerKind, at: topHeaderIndexPath)
        } else {
            return nil
        }
    }
    
    @objc func selectDate() {
        if let header = getTopVisibleSectionHeader() as? PhotoCollectionHeaderView {
            header.dateTextField.becomeFirstResponder()
        }
    }
    
    @objc func datePicked() {
        view.endEditing(true)
        photoCollectionView.setContentOffset(CGPoint(x: 0, y: -100), animated: false)
        showLoadingSpinner()
        hideEmptyState()
        
        Task {
            // Use progress tracking for date picker as well
            for await progress in viewModel.fetchPhotoWithProgress() {
                switch progress.phase {
                case .fetchingPhotos(let current, let total):
                    updateLoadingProgress(Float(progress.overallProgress), loaded: current, total: total)
                    
                case .groupingByYear:
                    loadingProgressView.updateProgress(Float(progress.overallProgress), detail: "Organizing memories...")
                    
                case .fetchingLocations(let year, let current, let total):
                    loadingProgressView.updateProgress(Float(progress.overallProgress), detail: "Finding locations (\(current)/\(total))...")
                    
                case .completed:
                    let hasPhotos = viewModel.assetSequence.count > 0
                    
                    if hasPhotos {
                        hideEmptyState()
                        photoCollectionView.reloadData()
                        photoCollectionView.collectionViewLayout.invalidateLayout()
                    } else {
                        showEmptyState(type: .noPhotosForDate(viewModel.displayDate()))
                    }
                    
                    hideLoadingSpinner()
                    
                case .failed(let error):
                    print("Fetch failed: \(error)")
                    showEmptyState(type: .noPhotosForDate(viewModel.displayDate()))
                    hideLoadingSpinner()
                }
            }
        }
    }
    
    @objc func dateCancelled () {
        view.endEditing(true)
    }
    
    @objc func settingsButtonTapped() {
        let settingsViewController = SettingsViewController()
        let navigationController = UINavigationController(rootViewController: settingsViewController)
        navigationController.modalPresentationStyle = .fullScreen
        present(navigationController, animated: true, completion: nil)
    }
    
    @objc func changLayoutButtonTapped() {
        Helper.changeLayout()
        photoCollectionView.reloadData()
        photoCollectionView.setContentOffset(CGPoint(x: 0, y: -photoCollectionView.contentInset.top), animated: true)

    }
    
    @objc func changSortingOrderTapped() {
        Helper.changeSortingOrder()
        viewModel.sortAssetArray()
        photoCollectionView.reloadData()
        photoCollectionView.setContentOffset(CGPoint(x: 0, y: -photoCollectionView.contentInset.top), animated: true)

    }
    
    
}


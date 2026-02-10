//
//  SkeletonView.swift
//  PhotoFlashBack
//
//  Created for loading state optimization
//

import UIKit

// MARK: - Skeleton View for Loading States
class SkeletonView: UIView {
    
    private var gradientLayer: CAGradientLayer?
    private var isAnimating = false
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupSkeleton()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupSkeleton()
    }
    
    private func setupSkeleton() {
        backgroundColor = UIColor(red: 45/255, green: 40/255, blue: 25/255, alpha: 1.0)
        layer.cornerRadius = 4
        clipsToBounds = true
    }
    
    func startAnimating() {
        guard !isAnimating else { return }
        isAnimating = true
        
        // 创建渐变层
        let gradient = CAGradientLayer()
        gradient.colors = [
            UIColor(red: 45/255, green: 40/255, blue: 25/255, alpha: 1.0).cgColor,
            UIColor(red: 60/255, green: 55/255, blue: 35/255, alpha: 1.0).cgColor,
            UIColor(red: 45/255, green: 40/255, blue: 25/255, alpha: 1.0).cgColor
        ]
        gradient.locations = [0, 0.5, 1]
        gradient.startPoint = CGPoint(x: 0, y: 0.5)
        gradient.endPoint = CGPoint(x: 1, y: 0.5)
        gradient.frame = CGRect(x: -bounds.width, y: 0, width: bounds.width * 3, height: bounds.height)
        
        layer.addSublayer(gradient)
        gradientLayer = gradient
        
        // 创建动画
        let animation = CABasicAnimation(keyPath: "transform.translation.x")
        animation.fromValue = -bounds.width
        animation.toValue = bounds.width
        animation.duration = 1.5
        animation.repeatCount = .infinity
        animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        
        gradient.add(animation, forKey: "shimmer")
    }
    
    func stopAnimating() {
        isAnimating = false
        gradientLayer?.removeAllAnimations()
        gradientLayer?.removeFromSuperlayer()
        gradientLayer = nil
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        gradientLayer?.frame = CGRect(x: -bounds.width, y: 0, width: bounds.width * 3, height: bounds.height)
    }
}

// MARK: - Skeleton Cell Overlay
class SkeletonCellOverlay: UIView {
    
    private let skeletonView = SkeletonView()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }
    
    private func setup() {
        backgroundColor = .clear
        addSubview(skeletonView)
        skeletonView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            skeletonView.topAnchor.constraint(equalTo: topAnchor),
            skeletonView.leadingAnchor.constraint(equalTo: leadingAnchor),
            skeletonView.trailingAnchor.constraint(equalTo: trailingAnchor),
            skeletonView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }
    
    func startAnimating() {
        isHidden = false
        skeletonView.startAnimating()
    }
    
    func stopAnimating() {
        skeletonView.stopAnimating()
        isHidden = true
    }
}

// MARK: - Loading Progress View
class LoadingProgressView: UIView {
    
    private let containerView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor(red: 31/255, green: 27/255, blue: 13/255, alpha: 0.95)
        view.layer.cornerRadius = 16
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let progressView: UIProgressView = {
        let progress = UIProgressView(progressViewStyle: .default)
        progress.progressTintColor = UIColor(red: 235/255, green: 226/255, blue: 203/255, alpha: 1.0)
        progress.trackTintColor = UIColor(red: 60/255, green: 55/255, blue: 35/255, alpha: 1.0)
        progress.translatesAutoresizingMaskIntoConstraints = false
        progress.layer.cornerRadius = 2
        progress.clipsToBounds = true
        return progress
    }()
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = "Loading photos..."
        label.textColor = UIColor(red: 235/255, green: 226/255, blue: 203/255, alpha: 1.0)
        label.font = .systemFont(ofSize: 15, weight: .medium)
        label.textAlignment = .center
        label.numberOfLines = 0
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.8
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let detailLabel: UILabel = {
        let label = UILabel()
        label.text = ""
        label.textColor = UIColor(red: 180/255, green: 170/255, blue: 150/255, alpha: 1.0)
        label.font = .systemFont(ofSize: 12, weight: .regular)
        label.textAlignment = .center
        label.numberOfLines = 0
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.8
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let spinner: UIActivityIndicatorView = {
        let spinner = UIActivityIndicatorView(style: .medium)
        spinner.color = UIColor(red: 235/255, green: 226/255, blue: 203/255, alpha: 1.0)
        spinner.translatesAutoresizingMaskIntoConstraints = false
        return spinner
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }
    
    private func setup() {
        backgroundColor = .clear
        isHidden = true
        
        addSubview(containerView)
        containerView.addSubview(spinner)
        containerView.addSubview(titleLabel)
        containerView.addSubview(progressView)
        containerView.addSubview(detailLabel)
        
        NSLayoutConstraint.activate([
            containerView.centerXAnchor.constraint(equalTo: centerXAnchor),
            containerView.centerYAnchor.constraint(equalTo: centerYAnchor),
            containerView.widthAnchor.constraint(greaterThanOrEqualToConstant: 240),
            containerView.widthAnchor.constraint(lessThanOrEqualTo: widthAnchor, multiplier: 0.8),
            
            spinner.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 20),
            spinner.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            
            titleLabel.topAnchor.constraint(equalTo: spinner.bottomAnchor, constant: 16),
            titleLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20),
            
            progressView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 16),
            progressView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 24),
            progressView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -24),
            progressView.heightAnchor.constraint(equalToConstant: 4),
            
            detailLabel.topAnchor.constraint(equalTo: progressView.bottomAnchor, constant: 12),
            detailLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),
            detailLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20),
            detailLabel.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -20)
        ])
    }
    
    func show(title: String = "Loading photos...") {
        titleLabel.text = title
        progressView.progress = 0
        detailLabel.text = ""
        spinner.startAnimating()
        isHidden = false
        alpha = 0
        containerView.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
        
        // Spring animation for appearance
        UIView.animate(withDuration: 0.5, delay: 0, usingSpringWithDamping: 0.7, initialSpringVelocity: 0.5, options: .curveEaseOut) {
            self.alpha = 1
            self.containerView.transform = .identity
        }
    }
    
    func updateProgress(_ progress: Float, detail: String? = nil) {
        // Smooth spring animation for progress bar
        UIView.animate(withDuration: 0.5, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.5, options: [.curveEaseOut, .allowUserInteraction]) {
            self.progressView.setProgress(progress, animated: true)
        }
        
        // Animate detail label changes with fade transition
        if let detail = detail, detail != detailLabel.text {
            UIView.transition(with: detailLabel, duration: 0.3, options: .transitionCrossDissolve) {
                self.detailLabel.text = detail
            }
        }
    }
    
    func hide() {
        // Spring animation for disappearance
        UIView.animate(withDuration: 0.4, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.3, options: .curveEaseIn) {
            self.alpha = 0
            self.containerView.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
        } completion: { _ in
            self.isHidden = true
            self.spinner.stopAnimating()
            self.containerView.transform = .identity
        }
    }
}

// MARK: - Empty State View
class EmptyStateView: UIView {
    
    private let containerStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()
    
    private let iconImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.tintColor = UIColor(red: 150/255, green: 140/255, blue: 120/255, alpha: 1.0)
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.textColor = UIColor(red: 235/255, green: 226/255, blue: 203/255, alpha: 1.0)
        label.font = .systemFont(ofSize: 20, weight: .semibold)
        label.textAlignment = .center
        label.numberOfLines = 0
        label.lineBreakMode = .byWordWrapping
        return label
    }()
    
    private let messageLabel: UILabel = {
        let label = UILabel()
        label.textColor = UIColor(red: 150/255, green: 140/255, blue: 120/255, alpha: 1.0)
        label.font = .systemFont(ofSize: 15, weight: .regular)
        label.textAlignment = .center
        label.numberOfLines = 0
        label.lineBreakMode = .byWordWrapping
        return label
    }()
    
    private let actionButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitleColor(UIColor(red: 235/255, green: 226/255, blue: 203/255, alpha: 1.0), for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 15, weight: .medium)
        button.titleLabel?.numberOfLines = 1
        button.titleLabel?.adjustsFontSizeToFitWidth = true
        button.titleLabel?.minimumScaleFactor = 0.8
        button.backgroundColor = UIColor(red: 60/255, green: 55/255, blue: 35/255, alpha: 1.0)
        button.layer.cornerRadius = 20
        button.contentEdgeInsets = UIEdgeInsets(top: 12, left: 28, bottom: 12, right: 28)
        button.isHidden = true
        return button
    }()
    
    var onActionTapped: (() -> Void)?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }
    
    private func setup() {
        backgroundColor = UIColor(red: 31/255, green: 27/255, blue: 13/255, alpha: 1.0)
        
        addSubview(containerStack)
        containerStack.addArrangedSubview(iconImageView)
        containerStack.addArrangedSubview(titleLabel)
        containerStack.addArrangedSubview(messageLabel)
        containerStack.addArrangedSubview(actionButton)
        
        containerStack.setCustomSpacing(24, after: iconImageView)
        containerStack.setCustomSpacing(8, after: titleLabel)
        containerStack.setCustomSpacing(24, after: messageLabel)
        
        NSLayoutConstraint.activate([
            containerStack.centerXAnchor.constraint(equalTo: centerXAnchor),
            containerStack.centerYAnchor.constraint(equalTo: centerYAnchor, constant: -40),
            containerStack.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 32),
            containerStack.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -32),
            containerStack.widthAnchor.constraint(lessThanOrEqualTo: widthAnchor, multiplier: 0.85),
            
            iconImageView.widthAnchor.constraint(equalToConstant: 80),
            iconImageView.heightAnchor.constraint(equalToConstant: 80)
        ])
        
        actionButton.addTarget(self, action: #selector(actionButtonTapped), for: .touchUpInside)
    }
    
    @objc private func actionButtonTapped() {
        onActionTapped?()
    }
    
    enum EmptyStateType {
        case noPhotos
        case noPhotosForDate(String)
        case noPermission
        case loading
        case error(String)
    }
    
    func configure(for type: EmptyStateType) {
        switch type {
        case .noPhotos:
            iconImageView.image = UIImage(systemName: "photo.on.rectangle.angled")
            titleLabel.text = "No Photos"
            messageLabel.text = "Your photo library is empty"
            actionButton.isHidden = true
            
        case .noPhotosForDate(let date):
            iconImageView.image = UIImage(systemName: "calendar.badge.clock")
            titleLabel.text = "No Photos on This Day"
            messageLabel.text = "No photos found for \(date)\nTry selecting a different date"
            actionButton.setTitle("Select Date", for: .normal)
            actionButton.isHidden = false
            
        case .noPermission:
            iconImageView.image = UIImage(systemName: "lock.shield")
            titleLabel.text = "Permission Required"
            messageLabel.text = "Please grant photo library access\nin Settings to view your memories"
            actionButton.setTitle("Go to Settings", for: .normal)
            actionButton.isHidden = false
            
        case .loading:
            iconImageView.image = UIImage(systemName: "hourglass")
            titleLabel.text = "Loading..."
            messageLabel.text = "Searching for memories"
            actionButton.isHidden = true
            
        case .error(let message):
            iconImageView.image = UIImage(systemName: "exclamationmark.triangle")
            titleLabel.text = "Something Went Wrong"
            messageLabel.text = message
            actionButton.setTitle("Retry", for: .normal)
            actionButton.isHidden = false
        }
    }
}


//
//  SettingsViewController.swift
//  PhotoFlashBack
//
//  Created by Yang Song on 3/18/23.
//

import UIKit
import MessageUI
import SwiftTipJar

class SettingsViewController: UITableViewController {
    
    private let options = [
        "Rate the App",
        "Provide Feedback",
        "Send Tips",
        "Share with Friends"
    ]
    
    let tipJar = SwiftTipJar(tipsIdentifiers: Set([
        "com.YangSong.PhotoFalshBack.tip"
    ]))
    
    lazy var activityIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .large)
        indicator.hidesWhenStopped = true
        return indicator
    }()
    
    var isIAPAvailable = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        navigationItem.title = "Settings"
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        
        let closeButton = UIBarButtonItem(image: UIImage(systemName: "xmark"),
                                          style: .plain,
                                          target: self,
                                          action: #selector(closeButtonTapped))
        closeButton.tintColor = .secondaryLabel
        navigationItem.leftBarButtonItem = closeButton
        setupLoadingSpinner()
        tipJar.startObservingPaymentQueue()
        tipJar.productsReceivedBlock = allowTip
        tipJar.transactionSuccessfulBlock = showThankYou
        tipJar.transactionFailedBlock = tipCancelled
        tipJar.productsRequest?.start()
    }
    
    func setupLoadingSpinner() {
        view.addSubview(activityIndicator)
            activityIndicator.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                activityIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
                activityIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor)
            ])
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        tipJar.stopObservingPaymentQueue()
    }
    
    @objc private func closeButtonTapped() {
        dismiss(animated: true, completion: nil)
    }
    
    // MARK: - Table view data source
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return options.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        cell.textLabel?.text = options[indexPath.row]
        return cell
    }
    
    // MARK: - Table view delegate
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        // Your logic to handle the selected option
        if indexPath.row == 0 {
            //UIApplication.shared.openURL(URL.init(string: "https://itunes.apple.com/us/app/rewind-all-your-photos-taken/id1137168287?ls=1&mt=8")!)
            UIApplication.shared.open(URL.init(string: "https://itunes.apple.com/us/app/rewind-all-your-photos-taken/id1137168287?ls=1&mt=8")!)
        }
        
        if indexPath.row == 1 {
            email()
        }
        
        if indexPath.row == 2 { // Assuming "Send Tips" is the third option
            guard isIAPAvailable else { return }
            if let tip = tipJar.tips.first {
                showPurchaseConfirmationAlert(for: tip) { confirmed in
                    if confirmed {
                        self.activityIndicator.startAnimating()
                        self.tipJar.initiatePurchase(productIdentifier: tip.identifier)
                    } else {
                        tableView.deselectRow(at: indexPath, animated: true)
                    }
                }
            }
        }
        
        if indexPath.row == 3 {
            shareApp()
        }
    }
    
    func email() {
        
        if MFMailComposeViewController.canSendMail() {
            let mailVC = MFMailComposeViewController()
            mailVC.setToRecipients(["rewind.feedback@gmail.com"])
            mailVC.mailComposeDelegate = self
            self.present(mailVC, animated: true, completion: nil)
        } else {
            let email = "rewind.feedback@gmail.com"
            let url = URL(string: "mailto:\(email)")
            if UIApplication.shared.canOpenURL(url!) {
                UIApplication.shared.open(url!)
                
            } else {
                
            }
        }
        
    }

    func shareApp() {
        let yourAppID = "1137168287"
        let appStoreURL = "https://apps.apple.com/app/id\(yourAppID)"
        let shareText = "Check out this amazing app I've been using:"
        
        let activityViewController = UIActivityViewController(activityItems: [shareText, appStoreURL], applicationActivities: nil)
        self.present(activityViewController, animated: true, completion: nil)
    }

    
    func showPurchaseConfirmationAlert(for tip: Tip, completion: @escaping (Bool) -> Void) {
        let alertController = UIAlertController(title: "Send Tip", message: "Would you like to send a $0.99 Tip?", preferredStyle: .alert)
        
        let confirmAction = UIAlertAction(title: "Confirm", style: .default) { _ in
            completion(true)
        }
        
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel) { _ in
            completion(false)
        }
        
        alertController.addAction(confirmAction)
        alertController.addAction(cancelAction)
        present(alertController, animated: true, completion: nil)
    }
    
    private func showThankYou() {
        // Must run on main thread because it will be called from background but is setting up UI elements
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.activityIndicator.stopAnimating()
            let alertController = UIAlertController(title: "Thank You!", message: "Your support is greatly appreciated.", preferredStyle: .alert)
            let okAction = UIAlertAction(title: "OK", style: .default, handler: nil)
            alertController.addAction(okAction)
            self.present(alertController, animated: true, completion: nil)
            
        }
    }
    
    private func allowTip() {
        // Must run on main thread because it will be called from background but is setting up UI elements
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.isIAPAvailable = true
        }
    }
    
    private func tipCancelled() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.activityIndicator.stopAnimating()
        }
    }
}

extension SettingsViewController: MFMailComposeViewControllerDelegate {
    
    func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
        self.dismiss(animated: true, completion: nil)
    }
}

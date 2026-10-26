//
//  SettingsViewController.swift
//  PhotoFlashBack
//
//  Created by Yang Song on 3/18/23.
//

import UIKit
import MessageUI
import SwiftTipJar
import UserNotifications

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

    private var reminderShownOn = false
    private var pendingRefresh: Task<Void, Never>?

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
        tipJar.productsReceivedBlock = { [weak self] in
            self?.allowTip()
        }
        tipJar.transactionSuccessfulBlock = { [weak self] in
            self?.showThankYou()
        }
        tipJar.transactionFailedBlock = { [weak self] in
            self?.tipCancelled()
        }
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

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        UNUserNotificationCenter.current().getNotificationSettings { [weak self] settings in
            let authorized = settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional
            let shown = MemoryReminderSettingsStore.load().enabled && authorized
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.reminderShownOn = shown
                self.tableView.reloadSections(IndexSet(integer: 0), with: .none)
            }
        }
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
        return 2
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == 0 { return reminderShownOn ? 2 : 1 }
        return options.count
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return section == 0 ? "Daily Reminder" : nil
    }

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        return section == 0 ? "Get a notification each day when you have memories from that date." : nil
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
        if indexPath.section == 0 {
            cell.selectionStyle = .none
            if indexPath.row == 0 {
                cell.textLabel?.text = "Memory of the Day"
                let toggle = UISwitch()
                toggle.isOn = reminderShownOn
                toggle.addTarget(self, action: #selector(reminderSwitchChanged(_:)), for: .valueChanged)
                cell.accessoryView = toggle
            } else {
                cell.textLabel?.text = "Time"
                let settings = MemoryReminderSettingsStore.load()
                let picker = UIDatePicker()
                picker.datePickerMode = .time
                picker.preferredDatePickerStyle = .compact
                picker.date = Calendar.current.date(bySettingHour: settings.hour, minute: settings.minute, second: 0, of: Date()) ?? Date()
                picker.addTarget(self, action: #selector(reminderTimeChanged(_:)), for: .valueChanged)
                picker.sizeToFit()
                cell.accessoryView = picker
            }
            return cell
        }
        cell.textLabel?.text = options[indexPath.row]
        return cell
    }

    // MARK: - Daily reminder
    private let timeRowIndexPath = IndexPath(row: 1, section: 0)

    @objc private func reminderSwitchChanged(_ sender: UISwitch) {
        if sender.isOn {
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { [weak self] granted, _ in
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    if granted {
                        self.setReminderEnabled(true)
                    } else {
                        sender.setOn(false, animated: true)
                        self.showNotificationsOffAlert()
                    }
                }
            }
        } else {
            setReminderEnabled(false)
        }
    }

    private func setReminderEnabled(_ enabled: Bool) {
        var settings = MemoryReminderSettingsStore.load()
        settings.enabled = enabled
        MemoryReminderSettingsStore.save(settings)
        Task { await MemoryReminderScheduler.shared.refresh() }
        guard reminderShownOn != enabled else { return }
        reminderShownOn = enabled
        if enabled {
            tableView.insertRows(at: [timeRowIndexPath], with: .automatic)
        } else {
            tableView.deleteRows(at: [timeRowIndexPath], with: .automatic)
        }
    }

    @objc private func reminderTimeChanged(_ sender: UIDatePicker) {
        let components = Calendar.current.dateComponents([.hour, .minute], from: sender.date)
        var settings = MemoryReminderSettingsStore.load()
        settings.hour = components.hour ?? settings.hour
        settings.minute = components.minute ?? settings.minute
        MemoryReminderSettingsStore.save(settings)
        pendingRefresh?.cancel()
        pendingRefresh = Task {
            try? await Task.sleep(nanoseconds: 500_000_000)
            guard !Task.isCancelled else { return }
            await MemoryReminderScheduler.shared.refresh()
        }
    }

    private func showNotificationsOffAlert() {
        let alert = UIAlertController(title: "Notifications are turned off for Rewind", message: nil, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Open Settings", style: .default) { _ in
            if let url = URL(string: UIApplication.openNotificationSettingsURLString) {
                UIApplication.shared.open(url)
            }
        })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }

    // MARK: - Table view delegate
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard indexPath.section == 1 else { return }

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
                showPurchaseConfirmationAlert(for: tip) { [weak self] confirmed in
                    guard let self = self else { return }
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

        // Configure popover for iPad
        if let popoverController = activityViewController.popoverPresentationController {
            // Find the cell for "Share with Friends" (index 3)
            let indexPath = IndexPath(row: 3, section: 1)
            if let cell = tableView.cellForRow(at: indexPath) {
                popoverController.sourceView = cell
                popoverController.sourceRect = cell.bounds
            } else {
                // Fallback to table view center
                popoverController.sourceView = tableView
                popoverController.sourceRect = CGRect(x: tableView.bounds.midX, y: tableView.bounds.midY, width: 0, height: 0)
            }
            popoverController.permittedArrowDirections = [.up, .down]
        }

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

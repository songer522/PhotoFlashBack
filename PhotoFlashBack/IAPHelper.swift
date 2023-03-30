//
//  IAPHelper.swift
//  PhotoFlashBack
//
//  Created by Yang Song on 3/29/23.
//

import SwiftTipJar
import UIKit

class IAPHelper {
    static let shared = IAPHelper()
    
    let tipJar = SwiftTipJar(tipsIdentifiers: Set([
        "com.YangSong.PhotoFalshBack.tip"
    ]))
    
    var isIAPAvailable = false
    weak var presenter: UIViewController?
    
    func setupTipJar(presentingVC: UIViewController) {
        GlobalActivityIndicator.shared.show(on: presentingVC)
        if isIAPAvailable {
            initiatePurchase(presentingVC: presentingVC)
        } else {
            tipJar.startObservingPaymentQueue()
            tipJar.productsReceivedBlock = {self.allowTip(presentingVC: presentingVC)}
            tipJar.transactionSuccessfulBlock = showThankYou
            tipJar.transactionFailedBlock = tipCancelled
            tipJar.productsRequest?.start()
        }
    }
    
    func initiatePurchase(presentingVC: UIViewController) {
        guard isIAPAvailable else { return }
        presenter = presentingVC
        if let tip = tipJar.tips.first {
            showPurchaseRequestAlert(for: tip)
        }
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
        presenter?.present(alertController, animated: true, completion: nil)
    }
    
    func showPurchaseRequestAlert(for tip: Tip) {
        let alertController = UIAlertController(title: "Enjoying the App?",
                                               message: "If you're enjoying the app and find it helpful, please consider supporting the developer with a tip. Your support helps us continue to improve the app and add new features!",
                                               preferredStyle: .alert)

        // Add actions to the alert controller, for example:
        let tipAction = UIAlertAction(title: "Send a Tip", style: .default) { _ in
            // Code to handle the tip action
            self.showPurchaseConfirmationAlert(for: tip) { confirmed in
                if confirmed {
                    self.tipJar.initiatePurchase(productIdentifier: tip.identifier)
                } else {
                    GlobalActivityIndicator.shared.hide()
                }
            }
        }

        let noThanksAction = UIAlertAction(title: "No, Thanks", style: .cancel) { _ in
            // Code to handle the no thanks action
        }

        alertController.addAction(tipAction)
        alertController.addAction(noThanksAction)

        // Present the alert controller from your view controller
        presenter?.present(alertController, animated: true, completion: nil)

    }
    
    
    private func showThankYou() {
        // Must run on main thread because it will be called from background but is setting up UI elements
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            GlobalActivityIndicator.shared.hide()
            let alertController = UIAlertController(title: "Thank You!", message: "Your support is greatly appreciated.", preferredStyle: .alert)
            let okAction = UIAlertAction(title: "OK", style: .default, handler: nil)
            alertController.addAction(okAction)
            self.presenter?.present(alertController, animated: true, completion: nil)
         
            
        }
    }
    
    private func allowTip(presentingVC: UIViewController) {
        // Must run on main thread because it will be called from background but is setting up UI elements
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.isIAPAvailable = true
            self.initiatePurchase(presentingVC: presentingVC)
        }
    }
    
    private func tipCancelled() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            GlobalActivityIndicator.shared.hide()
        }
    }
}

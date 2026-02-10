//
//  PhotosViewController+TextField.swift
//  PhotoFlashBack
//
//  Created by Yang Song on 9/28/22.
//

import UIKit

extension PhotosViewController: UITextFieldDelegate {
    internal func textFieldShouldBeginEditing(_ textField: UITextField) -> Bool {
        picker.reloadAllComponents()
        setupInputView(textField: textField)
        let keyboardDoneButtonView = UIToolbar()
        keyboardDoneButtonView.sizeToFit()
        
        // Modern iOS 18 style - use system background with subtle blur
        let blurEffect = UIBlurEffect(style: .systemMaterial)
        let blurView = UIVisualEffectView(effect: blurEffect)
        blurView.frame = keyboardDoneButtonView.bounds
        blurView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        keyboardDoneButtonView.insertSubview(blurView, at: 0)
        
        let item = UIBarButtonItem(title: "Select", style: .done, target: self, action: #selector(PhotosViewController.datePicked))
        let item2 = UIBarButtonItem(title: "Cancel", style: .plain, target: self, action: #selector(PhotosViewController.dateCancelled))
        
        let flexSpace = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        let toolbarButtons = [item2, flexSpace, item]
        
        keyboardDoneButtonView.setItems(toolbarButtons, animated: false)
        textField.inputAccessoryView = keyboardDoneButtonView
        return true
    }
    
    func setupInputView(textField: UITextField) {
        let customInputView = UIView(frame: CGRect(x: 0, y: 0, width: view.frame.width, height: 250))
        customInputView.translatesAutoresizingMaskIntoConstraints = false
        
        // Modern light blur effect
        let blurEffect = UIBlurEffect(style: .systemMaterial)
        let visualEffectView = UIVisualEffectView(effect: blurEffect)
        customInputView.addSubview(visualEffectView)
        visualEffectView.frame = customInputView.bounds
        visualEffectView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        
        picker.backgroundColor = .clear
        picker.translatesAutoresizingMaskIntoConstraints = false
        customInputView.addSubview(picker)
        
        NSLayoutConstraint.activate([
            picker.topAnchor.constraint(equalTo: customInputView.topAnchor),
            picker.leadingAnchor.constraint(equalTo: customInputView.leadingAnchor),
            picker.trailingAnchor.constraint(equalTo: customInputView.trailingAnchor),
            picker.bottomAnchor.constraint(equalTo: customInputView.bottomAnchor)
        ])
        
        textField.inputView = customInputView
    }
}

extension PhotosViewController: UIScrollViewDelegate {
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        view.endEditing(true)
    }
}

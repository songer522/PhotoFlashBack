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
        textField.keyboardAppearance = .dark
        setupInputView(textField: textField)

        let accessoryHeight: CGFloat = 56
        let bottomMargin: CGFloat = 12
        let accessoryContainer = UIView(frame: CGRect(x: 0, y: 0, width: view.bounds.width, height: accessoryHeight))
        accessoryContainer.backgroundColor = .clear
        accessoryContainer.overrideUserInterfaceStyle = .dark
        accessoryContainer.autoresizingMask = [.flexibleWidth]

        let keyboardDoneButtonView = UIToolbar(frame: CGRect(x: 0, y: 0, width: view.bounds.width, height: accessoryHeight - bottomMargin))
        keyboardDoneButtonView.overrideUserInterfaceStyle = .dark
        keyboardDoneButtonView.translatesAutoresizingMaskIntoConstraints = false
        keyboardDoneButtonView.tintColor = .white

        let selectButton = UIBarButtonItem(title: "Select", style: .plain, target: self, action: #selector(PhotosViewController.datePicked))
        selectButton.tintColor = .white
        selectButton.setTitleTextAttributes([.font: UIFont.systemFont(ofSize: 17, weight: .semibold), .foregroundColor: UIColor.white], for: .normal)
        selectButton.setTitleTextAttributes([.font: UIFont.systemFont(ofSize: 17, weight: .semibold), .foregroundColor: UIColor.white], for: .highlighted)

        let cancelButton = UIBarButtonItem(title: "Cancel", style: .plain, target: self, action: #selector(PhotosViewController.dateCancelled))
        cancelButton.tintColor = .white
        cancelButton.setTitleTextAttributes([.foregroundColor: UIColor.white], for: .normal)
        cancelButton.setTitleTextAttributes([.foregroundColor: UIColor.white], for: .highlighted)

        let flexSpace = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        keyboardDoneButtonView.setItems([cancelButton, flexSpace, selectButton], animated: false)

        accessoryContainer.addSubview(keyboardDoneButtonView)
        NSLayoutConstraint.activate([
            keyboardDoneButtonView.topAnchor.constraint(equalTo: accessoryContainer.topAnchor),
            keyboardDoneButtonView.leadingAnchor.constraint(equalTo: accessoryContainer.leadingAnchor),
            keyboardDoneButtonView.trailingAnchor.constraint(equalTo: accessoryContainer.trailingAnchor),
            keyboardDoneButtonView.bottomAnchor.constraint(equalTo: accessoryContainer.bottomAnchor, constant: -bottomMargin)
        ])

        textField.inputAccessoryView = accessoryContainer
        return true
    }

    func setupInputView(textField: UITextField) {
        let customInputView = UIInputView(frame: CGRect(x: 0, y: 0, width: view.bounds.width, height: 250), inputViewStyle: .keyboard)
        customInputView.overrideUserInterfaceStyle = .dark
        customInputView.autoresizingMask = [.flexibleWidth]

        let blurEffect = UIBlurEffect(style: .systemMaterialDark)
        let visualEffectView = UIVisualEffectView(effect: blurEffect)
        visualEffectView.overrideUserInterfaceStyle = .dark
        visualEffectView.translatesAutoresizingMaskIntoConstraints = false
        customInputView.addSubview(visualEffectView)

        picker.removeFromSuperview()
        picker.overrideUserInterfaceStyle = .dark
        picker.backgroundColor = .clear
        picker.translatesAutoresizingMaskIntoConstraints = false
        customInputView.addSubview(picker)

        NSLayoutConstraint.activate([
            visualEffectView.topAnchor.constraint(equalTo: customInputView.topAnchor),
            visualEffectView.leadingAnchor.constraint(equalTo: customInputView.leadingAnchor),
            visualEffectView.trailingAnchor.constraint(equalTo: customInputView.trailingAnchor),
            visualEffectView.bottomAnchor.constraint(equalTo: customInputView.bottomAnchor),

            picker.topAnchor.constraint(equalTo: customInputView.topAnchor),
            picker.leadingAnchor.constraint(equalTo: customInputView.leadingAnchor),
            picker.trailingAnchor.constraint(equalTo: customInputView.trailingAnchor),
            picker.bottomAnchor.constraint(equalTo: customInputView.bottomAnchor)
        ])

        textField.inputView = customInputView
    }
}

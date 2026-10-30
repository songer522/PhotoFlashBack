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
        let keyboardDoneButtonView = UIToolbar(frame: CGRect(x: 0, y: 0, width: view.bounds.width, height: 44))
        keyboardDoneButtonView.autoresizingMask = [.flexibleWidth]

        let appearance = UIToolbarAppearance()
        appearance.configureWithDefaultBackground()
        appearance.backgroundEffect = UIBlurEffect(style: .systemMaterial)
        keyboardDoneButtonView.standardAppearance = appearance
        keyboardDoneButtonView.compactAppearance = appearance
        keyboardDoneButtonView.scrollEdgeAppearance = appearance
        keyboardDoneButtonView.tintColor = .label

        let selectButton = UIBarButtonItem(title: "Select", style: .plain, target: self, action: #selector(PhotosViewController.datePicked))
        selectButton.tintColor = .label
        selectButton.setTitleTextAttributes([.font: UIFont.systemFont(ofSize: 17, weight: .semibold)], for: .normal)
        selectButton.setTitleTextAttributes([.font: UIFont.systemFont(ofSize: 17, weight: .semibold)], for: .highlighted)

        let cancelButton = UIBarButtonItem(title: "Cancel", style: .plain, target: self, action: #selector(PhotosViewController.dateCancelled))
        cancelButton.tintColor = .label

        let flexSpace = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        keyboardDoneButtonView.setItems([cancelButton, flexSpace, selectButton], animated: false)
        textField.inputAccessoryView = keyboardDoneButtonView
        return true
    }

    func setupInputView(textField: UITextField) {
        let customInputView = UIInputView(frame: CGRect(x: 0, y: 0, width: view.bounds.width, height: 250), inputViewStyle: .keyboard)
        customInputView.autoresizingMask = [.flexibleWidth]

        let blurEffect = UIBlurEffect(style: .systemMaterial)
        let visualEffectView = UIVisualEffectView(effect: blurEffect)
        visualEffectView.translatesAutoresizingMaskIntoConstraints = false
        customInputView.addSubview(visualEffectView)

        picker.removeFromSuperview()
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

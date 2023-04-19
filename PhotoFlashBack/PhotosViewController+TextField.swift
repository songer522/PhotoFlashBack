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
        keyboardDoneButtonView.backgroundColor = UIColor(red: 31/255, green: 27/255, blue: 13/255, alpha: 1.0)
        keyboardDoneButtonView.barTintColor = UIColor(red: 31/255, green: 27/255, blue: 13/255, alpha: 1.0)
        keyboardDoneButtonView.tintColor = UIColor.white
        let item = UIBarButtonItem(title: "Select", style: UIBarButtonItem.Style.plain, target: self, action: #selector(PhotosViewController.datePicked) )
        let item2 = UIBarButtonItem(title: "Cancel", style: UIBarButtonItem.Style.plain, target: self, action: #selector(PhotosViewController.dateCancelled) )
        let font = UIFont.preferredFont(forTextStyle: .body)
            item.setTitleTextAttributes([NSAttributedString.Key.font: font], for: UIControl.State())
            item2.setTitleTextAttributes([NSAttributedString.Key.font: font], for: UIControl.State())
        let title = UILabel.init(frame: CGRect(x: 0, y: 0, width: 120, height: 30))
        title.text = "Memory Lane"
        title.textAlignment = .center
        title.textColor = UIColor.white
        title.font = font
        let item3 = UIBarButtonItem.init(customView: title)
        
        let flexSpace = UIBarButtonItem(barButtonSystemItem: UIBarButtonItem.SystemItem.flexibleSpace, target: nil, action: nil)
        
        let toolbarButtons = [item2,flexSpace,item3,flexSpace,item]
        
        keyboardDoneButtonView.setItems(toolbarButtons, animated: false)
        textField.inputAccessoryView = keyboardDoneButtonView
        return true
    }
    
    func setupInputView(textField: UITextField) {
        let customInputView = UIView(frame: CGRect(x: 0, y: 0, width: view.frame.width, height: 250))
            customInputView.translatesAutoresizingMaskIntoConstraints = false
             let imageView = UIImageView()
             imageView.translatesAutoresizingMaskIntoConstraints = false
             imageView.contentMode = .scaleAspectFill
             imageView.clipsToBounds = true
             
             customInputView.addSubview(imageView)
             
             NSLayoutConstraint.activate([
                imageView.topAnchor.constraint(equalTo: customInputView.topAnchor),
                imageView.leadingAnchor.constraint(equalTo: customInputView.leadingAnchor),
                imageView.trailingAnchor.constraint(equalTo: customInputView.trailingAnchor),
                imageView.bottomAnchor.constraint(equalTo: customInputView.bottomAnchor)
             ])
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

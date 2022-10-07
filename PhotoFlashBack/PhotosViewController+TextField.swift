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
        textField.inputView = picker
        textField.inputView?.backgroundColor = .black
        let keyboardDoneButtonView = UIToolbar()
        keyboardDoneButtonView.sizeToFit()
        keyboardDoneButtonView.backgroundColor = UIColor.init(red: 47.0/255.0, green: 198.0/255.0, blue: 107.0/255.0, alpha: 1)
        keyboardDoneButtonView.barTintColor = UIColor.init(red: 47.0/255.0, green: 198.0/255.0, blue: 107.0/255.0, alpha: 1)
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
}

extension PhotosViewController: UIScrollViewDelegate {
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        view.endEditing(true)
    }
}

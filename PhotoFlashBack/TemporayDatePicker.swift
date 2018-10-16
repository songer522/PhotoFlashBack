//
//  TemporayDatePicker.swift
//  PhotoFlashBack
//
//  Created by Song, Yang on 4/22/16.
//  Copyright © 2016 Yang Song. All rights reserved.
//

import UIKit

class TemporayDatePicker: UIViewController {
    @IBOutlet weak var monthField: UITextField!
    @IBOutlet weak var dayField: UITextField!
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
  
    }
    @IBAction func findTapped(_ sender: AnyObject) {
        let storyBoard = UIStoryboard.init(name: "Main", bundle: nil)
        
        let photoCollectionVC = storyBoard.instantiateViewController(withIdentifier: "photos") as? ViewController
        photoCollectionVC?.month = Int(monthField.text!)!
        photoCollectionVC?.day = Int(dayField.text!)!
        
        self.navigationController?.pushViewController(photoCollectionVC!, animated: true)
        
    }
}

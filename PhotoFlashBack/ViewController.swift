//
//  ViewController.swift
//  PhotoFlashBack
//
//  Created by Song, Yang on 4/22/16.
//  Copyright © 2016 Yang Song. All rights reserved.
//

import UIKit
import Photos
import GSImageViewerController

class ViewController: UIViewController {
    @IBOutlet weak var titleCustomView: UIView!
    @IBOutlet weak var titleTextField: UITextField!
    @IBOutlet weak var photoCollectionView: UICollectionView!
    @IBOutlet weak var datePickBtn : UIButton!
    @IBOutlet weak var noPhotoLabel : UILabel!
    var datePicker: UIDatePicker = UIDatePicker.init()
    var picker : UIPickerView = UIPickerView.init()
    var assetArray : [(String, [PHAsset])] = []
    var assetSequence : [PHAsset] = []
    var assetDict : [String: [PHAsset]] = Dictionary()
    let assetManager = PHImageManager.default()
    var month = 1
    var day = 1
    var monthArray = ["January", "Feburay", "March", "April", "May", "June", "July", "August", "Septemper", "October", "November", "December"]
    var selectedImage : UIImage?
    var canOpenImageViewer = true
    //var fullFeatureUnlocked = false
    
    override func viewDidLoad() {

        super.viewDidLoad()
        navigationItem.titleView = titleCustomView
        picker.delegate = self
        picker.backgroundColor = UIColor.black
        day = (Calendar.current as NSCalendar).component(.day, from: Date())
        month = (Calendar.current as NSCalendar).component(.month, from: Date())
        let dayString = String(day)
        titleTextField?.text = String(monthArray[month - 1] + " " + dayString)
        fetchPhoto(day, month: month)
        picker.selectRow(month - 1, inComponent: 0, animated: false)
        picker.selectRow(day - 1, inComponent: 1, animated: false)
        rerenderDatePickButton()
        showSettingButton()
        addSwipeGesture()
        photoCollectionView.contentInset = UIEdgeInsetsMake(0, 0, 80, 0)
        photoCollectionView.register(UICollectionViewCell.self, forCellWithReuseIdentifier: "Header")
        NotificationCenter.default.addObserver(self, selector: #selector(ViewController.rotated), name: NSNotification.Name.UIApplicationDidChangeStatusBarFrame, object: nil)
        
        
//        if let isPurchased = NSUserDefaults.standardUserDefaults().objectForKey("fullFeature") as? String{
//            if isPurchased == "YES" {
//            fullFeatureUnlocked = true
//            }else {
//            fullFeatureUnlocked = false
//            }
//        }else {
//            
//            
//            let isPurchased = RewindProducts.store.isProductPurchased(RewindProducts.Unlock)
//            if isPurchased == true {
//            NSUserDefaults.standardUserDefaults().setObject("YES", forKey: "fullFeature")
//            }else {
//            NSUserDefaults.standardUserDefaults().setObject("NO", forKey: "fullFeature")
//            }
//            NSUserDefaults.standardUserDefaults().synchronize()
//            fullFeatureUnlocked = isPurchased
//        }
//        NSNotificationCenter.defaultCenter().addObserver(self, selector: Selector("completePurchase"), name: IAPHelper.IAPHelperPurchaseNotification, object: nil)
        // Do any additional setup after loading the view, typically from a nib.
    }
    
    override func viewWillAppear(_ animated: Bool) {
        if assetArray.count > 0 {
            photoCollectionView.reloadData()
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    func completePurchase() {
//        fullFeatureUnlocked = true
        photoCollectionView.reloadData()
    }
    
    func showSettingButton() {
        let origImage = UIImage(named: "ic_settings_48pt");
        let tintedImage = origImage?.withRenderingMode(UIImageRenderingMode.alwaysTemplate)
        let settingBtn = UIButton.init(frame: CGRect(x: 0, y: 0, width: 44, height: 44))
        settingBtn.setImage(tintedImage, for: UIControlState())
        settingBtn.setImage(tintedImage, for: .highlighted)
        settingBtn.tintColor = UIColor.white
        settingBtn.backgroundColor = UIColor.clear
        settingBtn.contentMode = .center
        //settingBtn.contentEdgeInsets = UIEdgeInsetsMake(10, 15, 10, 15)
        settingBtn.addTarget(self, action: #selector(ViewController.showSetting), for: UIControlEvents.touchUpInside)
        navigationItem.rightBarButtonItem = UIBarButtonItem.init(customView: settingBtn)
  
    }
    
    func rerenderDatePickButton() {
        let origImage = UIImage(named: "ic_update_48pt");
        let tintedImage = origImage?.withRenderingMode(UIImageRenderingMode.alwaysTemplate)
        datePickBtn.setImage(tintedImage, for: UIControlState())
        datePickBtn.setImage(tintedImage, for: .highlighted)
        datePickBtn.tintColor = UIColor.white
        datePickBtn.backgroundColor = UIColor.init(red: 47.0/255.0, green: 198.0/255.0, blue: 107.0/255.0, alpha: 1)
        datePickBtn.layer.cornerRadius = datePickBtn.frame.size.width/2
        datePickBtn.clipsToBounds = true
    }
    
    func addSwipeGesture() {
        
        let swipeRight = UISwipeGestureRecognizer(target: self, action: #selector(ViewController.respondToSwipeGesture(_:)))
        swipeRight.direction = UISwipeGestureRecognizerDirection.right
        photoCollectionView.addGestureRecognizer(swipeRight)
        
        let swipeLeft = UISwipeGestureRecognizer(target: self, action: #selector(ViewController.respondToSwipeGesture(_:)))
        swipeLeft.direction = UISwipeGestureRecognizerDirection.left
        photoCollectionView.addGestureRecognizer(swipeLeft)
    }
    
    
    func respondToSwipeGesture(_ gesture: UIGestureRecognizer) {
        
        if let swipeGesture = gesture as? UISwipeGestureRecognizer {

            switch swipeGesture.direction {
            case UISwipeGestureRecognizerDirection.right:
                previousDay()
            case UISwipeGestureRecognizerDirection.left:
                nextDay()
            default:
                break
            }
        }
    }
    
    func showSetting() {
        let ctStoryBoard: UIStoryboard = UIStoryboard(name: "Main", bundle: nil)
        let settingViewController = ctStoryBoard.instantiateViewController(withIdentifier: "setting") as! SettingViewController
        let nav = UINavigationController.init(rootViewController: settingViewController)
        nav.navigationBar.barTintColor = UIColor.init(red: 47.0/255.0, green: 198.0/255.0, blue: 107.0/255.0, alpha: 1)
        nav.navigationBar.tintColor = UIColor.white
        let appearance = UINavigationBar.appearance()
        appearance.titleTextAttributes = [NSFontAttributeName: UIFont.systemFont(ofSize: 17), NSForegroundColorAttributeName: UIColor.white]
        self.present(nav, animated: true, completion: nil)
    }
    
    func fetchPhoto(_ day: Int, month: Int){
        assetArray.removeAll()
        assetDict.removeAll()
        assetSequence.removeAll()
        let options = PHFetchOptions.init()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        options.predicate = NSPredicate(format: "mediaType = %d", PHAssetMediaType.image.rawValue)
        let assetsFetchResults = PHAsset.fetchAssets(with: options)
        assetsFetchResults.enumerateObjects({ (object: AnyObject, count: Int, stop: UnsafeMutablePointer<ObjCBool>) in
            if let asset = object as? PHAsset {
                
                let assetDay = (Calendar.current as NSCalendar).component(NSCalendar.Unit.day, from: asset.creationDate!)
                let assetMonth = (Calendar.current as NSCalendar).component(NSCalendar.Unit.month, from: asset.creationDate!)
                let assetYear = (Calendar.current as NSCalendar).component(NSCalendar.Unit.year, from: asset.creationDate!)
                if assetDay == day && assetMonth == month {
                    if var assetArray = self.assetDict[String(assetYear)] {
                        assetArray.append(asset)
                        self.assetDict.updateValue(assetArray, forKey: String(assetYear))
                    }else {
                        self.assetDict.updateValue([asset], forKey: String(assetYear))
                    }
                    
                    
                }
            }
        })
        
        assetArray = self.assetDict.sorted { $0.0 < $1.0 }
        if assetArray.count > 0 {
            noPhotoLabel.isHidden = true
        } else {
            noPhotoLabel.isHidden = false
        }
        
        for (_, assets) in assetArray {
            
            for asset in assets {
                assetSequence.append(asset)
            }
            
        }
        
        self.photoCollectionView.contentOffset = CGPoint(x: 0, y: -64)
        self.photoCollectionView.reloadData()

    }

    @IBAction func dateButtonTapped(_ sender: AnyObject) {
        titleTextField.becomeFirstResponder()

    }
    
    func stringFromDate(_ date: Date, format: String) -> String {
        let dateFormatter: DateFormatter = DateFormatter()
        dateFormatter.dateFormat = format
        dateFormatter.timeZone = TimeZone.autoupdatingCurrent
        return dateFormatter.string(from: date);
    }
    
    func datePicked () {
        let dayString = String(day)
        titleTextField?.text = String(monthArray[month - 1] + " " + dayString)
        titleTextField?.resignFirstResponder()

        fetchPhoto(day, month: month)
    }
    
    func nextDay() {

        if day < maxday() {
            day = day + 1
        }else {
            if month < 12 {
                month = month + 1
                day = 1
            }else {
                month = 1
                day = 1
            }
        }
        
        let dayString = String(day)
        titleTextField?.text = String(monthArray[month - 1] + " " + dayString)
        titleTextField?.resignFirstResponder()
        
        fetchPhoto(day, month: month)
        
    }
    
    func previousDay() {
        if day == 1 {
            if month == 1 {
                month = 12
                day = maxday()
            }else {
                month = month - 1
                day = maxday()
            }
        }else {
        day = day - 1
        }
        let dayString = String(day)
        titleTextField?.text = String(monthArray[month - 1] + " " + dayString)
        titleTextField?.resignFirstResponder()
        
        fetchPhoto(day, month: month)
        
    }
    
    func maxday() -> Int{
        if month == 1 || month == 3 || month == 5 || month == 7 || month == 8 || month == 10 || month == 12 {
            return 31
        }else if month == 4 || month == 6 || month == 9 || month == 11 {
            return 30
        }else if month == 2 {
            return 29
        }else {
            return 30
        }
    }
    
    func dateCancelled () {
        titleTextField?.resignFirstResponder()
    }
}

extension ViewController: UICollectionViewDataSource, UICollectionViewDelegate {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {

        return assetArray[section].1.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        
        let collectionCell = collectionView.dequeueReusableCell(withReuseIdentifier: "photoCell", for: indexPath) as? PhotoCollectionViewCell
        
        
        let asset =  assetArray[indexPath.section].1[indexPath.row]
        
        let targetSize = CGSize(width: 200, height: 200)
        assetManager.requestImage(for: asset,
                                     targetSize: targetSize,
                                     contentMode: .aspectFill,
                                     options: nil,
                                     resultHandler: { image, info in
                                        
          collectionCell?.itemImageView.contentMode = .scaleAspectFill
          collectionCell?.itemImageView.image = image
//                                        if self.fullFeatureUnlocked == false && self.month != NSCalendar.currentCalendar().component(.Month, fromDate: NSDate()){
//                                           collectionCell?.blurEffectView.hidden = false
//                                        }else {
//                                            collectionCell?.blurEffectView.hidden = true
//                                        }
                                        
                                        
        })
        
        return collectionCell!
    }
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return assetDict.count
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
//        if self.fullFeatureUnlocked == false && self.month != NSCalendar.currentCalendar().component(.Month, fromDate: NSDate()) {
//            let alertController = UIAlertController(title: "Hi there", message: "You can only view photos from the currently month, would you like to unlock all rest of the photos?", preferredStyle: .Alert)
//            let ok = UIAlertAction(title: "OK", style: .Default, handler: { (action) -> Void in
//                print("Ok Button Pressed")
//                RewindProducts.store.requestProducts{success, products in
//                    if success {
//                        
//                        //  print(products)
//                        for product in products! {
//                            if product.productIdentifier == RewindProducts.Unlock {
//                                RewindProducts.store.buyProduct(product)        
//                            }
//                        }
//                        
//                    }
//                    
//                }
//            })
//            let cancel = UIAlertAction(title: "Cancel", style: .Cancel) { (action) -> Void in
//                print("Cancel Button Pressed")
//            }
//            alertController.addAction(ok)
//            alertController.addAction(cancel)
//                        presentViewController(alertController, animated: true, completion: nil)
//        }else {
            canOpenImageViewer = true
            let cell = collectionView.cellForItem(at: indexPath) as? PhotoCollectionViewCell
            cell?.spinner.isHidden = false
            cell?.spinner.startAnimating()
            let asset = assetArray[indexPath.section].1[indexPath.row]
            let options = PHImageRequestOptions()
            options.resizeMode = PHImageRequestOptionsResizeMode.fast
            options.deliveryMode = PHImageRequestOptionsDeliveryMode.opportunistic
            options.isNetworkAccessAllowed = true
            let targetSize = CGSize(width: 1000, height: asset.pixelHeight*1000/asset.pixelWidth)
            assetManager.requestImage(for: asset,
                                              targetSize: targetSize,
                                              contentMode: .aspectFill,
                                              options: options,
                                              resultHandler: { image, info in
                                                
                                                DispatchQueue.main.async(execute: {
                                                    cell?.spinner.isHidden = true
                                                    cell?.spinner.stopAnimating()
                                                    if let image = image, self.presentedViewController == nil {
                                                        if self.canOpenImageViewer == true {
                                                            self.canOpenImageViewer = false
                                                        } else {
                                                            return
                                                        }
                                                        var imageInfo      = GSImageInfo(image: image, imageMode: .aspectFit, imageHD: nil)
                                                        imageInfo.assetSequence = self.assetSequence
                                                        imageInfo.currentIndex = self.assetSequence.index(of: asset)!
                                                        let transitionInfo = GSTransitionInfo(fromView: cell!)
                                                        let imageViewer    = GSImageViewerController(imageInfo: imageInfo, transitionInfo: transitionInfo)
                                                        imageViewer.loadImage()
                                                        self.present(imageViewer, animated: true, completion: nil)
                                                    }
                                                })
                                                
            })
            
   //     }
        
    }
    
    func collectionView(_ collectionView: UICollectionView,
                          layout collectionViewLayout: UICollectionViewLayout,
                                 sizeForItemAtIndexPath indexPath: IndexPath) -> CGSize {
        
        let width = (UIScreen.main.bounds.width - 8)/4
        
        return CGSize(width: width, height: width)  
    }
    

    
    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        
        let view = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "Header", for: indexPath)
        
        view.backgroundColor = UIColor.white
        for subView in view.subviews {
            
            subView.removeFromSuperview()
        }
       
        let key = self.assetArray[indexPath.section].0
        let label = UILabel.init(frame: CGRect(x: 10, y: 10, width: view.frame.size.width - 10, height: view.frame.size.height-10))
        label.text = key
        label.font = UIFont(name: "AppleSDGothicNeo-Bold", size: 20)
        label.textColor = UIColor.init(red: 53.0/255.0, green: 53.0/255.0, blue: 53.0/255.0, alpha: 1)
        label.textAlignment = .left;
        view.addSubview(label)
        view.tag = indexPath.section
        findLocation(view, assetArray: assetArray[indexPath.section].1, currentIndex: 0)
      
        return view
        
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, referenceSizeForHeaderInSection section: Int) -> CGSize {
        
        return CGSize(width: collectionView.bounds.width, height: 50)
    }
    
    func rotated()
    {
        photoCollectionView.reloadData()
    }
    
    func findLocation(_ view : UIView, assetArray: [PHAsset], currentIndex : Int) {
        
        let geocoder = CLGeocoder()
        if currentIndex < assetArray.count - 1 {
            let asset = assetArray[currentIndex]
            if let location = asset.location {
                geocoder.reverseGeocodeLocation(location, completionHandler: { (placemarks, error) -> Void in
                    // Place details
                    DispatchQueue.main.async(execute: {
                        var placeMark: CLPlacemark!
                        placeMark = placemarks?[0]
                        
                        var array : [String] = []
                        if let placeMark = placeMark {
                        if let addressDict = placeMark.addressDictionary {
                            if let city = addressDict["City"] as? String {
                                array.append(city)
                            }
                            
                            if let state = addressDict["State"] as? String {
                                array.append(state)
                            }
                            
                            if let country = addressDict["Country"] as? String {
                                array.append(country)
                            }
                            
                            if array.count > 0 {
                                
                                let location = array.joined(separator: ", ")
                                
                                let label2 = UILabel.init(frame: CGRect(x: 0, y: 10, width: view.frame.size.width - 20, height: view.frame.size.height-10))
                                label2.text = location
                                label2.font = UIFont(name: "AppleSDGothicNeo-Regular", size: 14)
                                label2.textColor = UIColor.init(red: 133.0/255.0, green: 133.0/255.0, blue: 133.0/255.0, alpha: 1)
                                label2.textAlignment = .right
                                view.addSubview(label2)
                                
                            }else {
                                self.findLocation(view, assetArray: assetArray, currentIndex: currentIndex + 1)
                            }
                            
                        }else {
                            self.findLocation(view, assetArray: assetArray, currentIndex: currentIndex + 1)
                        }
                        }else {
                            self.findLocation(view, assetArray: assetArray, currentIndex: currentIndex + 1)
                        }
                    })
                })
            }else {
                findLocation(view, assetArray: assetArray, currentIndex: currentIndex + 1)
            }
        }
    }
    
}

extension ViewController: UITextFieldDelegate {
     func textFieldShouldBeginEditing(_ textField: UITextField) -> Bool {
 
        picker.reloadAllComponents()
        textField.inputView = picker
        let keyboardDoneButtonView = UIToolbar()
        keyboardDoneButtonView.sizeToFit()
        keyboardDoneButtonView.backgroundColor = UIColor.init(red: 47.0/255.0, green: 198.0/255.0, blue: 107.0/255.0, alpha: 1)
        keyboardDoneButtonView.barTintColor = UIColor.init(red: 47.0/255.0, green: 198.0/255.0, blue: 107.0/255.0, alpha: 1)
        keyboardDoneButtonView.tintColor = UIColor.white
        let item = UIBarButtonItem(title: "Select", style: UIBarButtonItemStyle.plain, target: self, action: #selector(ViewController.datePicked) )
        let item2 = UIBarButtonItem(title: "Cancel", style: UIBarButtonItemStyle.plain, target: self, action: #selector(ViewController.dateCancelled) )
        if let font = UIFont(name: "AppleSDGothicNeo-Regular", size: 20) {
            item.setTitleTextAttributes([NSFontAttributeName: font], for: UIControlState())
            item2.setTitleTextAttributes([NSFontAttributeName: font], for: UIControlState())
        }
        let title = UILabel.init(frame: CGRect(x: 0, y: 0, width: 120, height: 30))
        title.text = "Memory Lane"
        title.textAlignment = .center
        title.textColor = UIColor.white
        title.font = UIFont(name: "AppleSDGothicNeo-Regular", size: 20)
        let item3 = UIBarButtonItem.init(customView: title)
        
        let flexSpace = UIBarButtonItem(barButtonSystemItem: UIBarButtonSystemItem.flexibleSpace, target: nil, action: nil)
        
        let toolbarButtons = [item2,flexSpace,item3,flexSpace,item]
        
        keyboardDoneButtonView.setItems(toolbarButtons, animated: false)
        textField.inputAccessoryView = keyboardDoneButtonView
    return true
    }
    
   
}

extension ViewController: UIPickerViewDelegate, UIPickerViewDataSource {
    
    func pickerView(_ pickerView: UIPickerView, viewForRow row: Int, forComponent component: Int, reusing view: UIView?) -> UIView
    {
        let pickerLabel = UILabel()
        pickerLabel.textColor = UIColor.white
        switch component {
                    case 0:
                   pickerLabel.text = monthArray[row]
            

                        //return monthArray[row]
                    case 1:
                        pickerLabel.text = String(row + 1)
                        //return String(row + 1)
                    default:
                        pickerLabel.text = ""
        }
        pickerLabel.font = UIFont(name: "AppleSDGothicNeo-Regular", size: 20) // In this use your custom font
        pickerLabel.textAlignment = NSTextAlignment.center
        return pickerLabel
    }
    
    
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        switch component {
        case 0:
            return 12
        case 1:
            return 31
        default :
            return 0
        }
        
        
    }
    
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 2
    }
    
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        switch component {
        case 0:
            month = row + 1
        case 1:
            day = row + 1
        default:
        break
        }
        if month == 2 {
            if day == 30 || day == 31 {
                day = 29
                pickerView.selectRow(28, inComponent: 1, animated: true)
                
                
            }
        } else if month == 6 || month == 9 || month == 4 || month == 11 {
            if day == 31 {
                day = 30
                pickerView.selectRow(29, inComponent: 1, animated: true)
            }
        }

        
    }
}

extension ViewController: UIGestureRecognizerDelegate {
    
     func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        if let _ = gestureRecognizer as? UIPanGestureRecognizer {
          return true
        }
        return false
    }
    
}

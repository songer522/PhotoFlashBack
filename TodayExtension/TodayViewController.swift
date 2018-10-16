//
//  TodayViewController.swift
//  TodayExtension
//
//  Created by Song, Yang on 7/19/16.
//  Copyright © 2016 Yang Song. All rights reserved.
//

import UIKit
import NotificationCenter
import Photos
class TodayViewController: UIViewController, NCWidgetProviding {
    let assetManager = PHImageManager.default()
    var assetArray : [(Int, PHAsset)] = []
    var selectedIndex : Int = 0
    @IBOutlet weak var photoView : UIImageView!
    @IBOutlet weak var yearLabel : UILabel!
    @IBOutlet weak var indexLabel : UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.preferredContentSize = CGSize(width: 0, height: 200)
       let day = (Calendar.current as NSCalendar).component(.day, from: Date())
        let month = (Calendar.current as NSCalendar).component(.month, from: Date())
        if #available(iOSApplicationExtension 10.0, *) {
            self.extensionContext?.widgetLargestAvailableDisplayMode = NCWidgetDisplayMode.expanded
        } else {
            // Fallback on earlier versions
        }
        fetchPhoto(day, month: month)
        // Do any additional setup after loading the view from its nib.
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func widgetMarginInsets
        (forProposedMarginInsets defaultMarginInsets: UIEdgeInsets) -> (UIEdgeInsets) {
        return UIEdgeInsets.zero
    }
    
    func widgetPerformUpdate(completionHandler: (@escaping (NCUpdateResult) -> Void)) {
        // Perform any setup necessary in order to update the view.

        // If an error is encountered, use NCUpdateResult.Failed
        // If there's no update required, use NCUpdateResult.NoData
        // If there's an update, use NCUpdateResult.NewData

        completionHandler(NCUpdateResult.newData)
    }
    
    func fetchPhoto(_ day: Int, month: Int){
        //self.assetArray.removeAll()
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
                    self.assetArray.append((assetYear, asset))
                    
                }
            }
        })
        selectedIndex = Int(arc4random_uniform(UInt32(assetArray.count)))
        
        showPhoto()
        
    }
    
    @IBAction func nextClicked() {
        if selectedIndex == assetArray.count - 1 {
           selectedIndex = 0
        } else {
          selectedIndex += 1
        }
        showPhoto()
        
        
    }
    
    @IBAction func previousClicked() {
        if selectedIndex == 0 {
            selectedIndex = assetArray.count - 1
        } else {
            selectedIndex -= 1
        }
        showPhoto()
    }
    
    @IBAction func openApp() {
      extensionContext?.open(URL(string: "OnThisDay://")!, completionHandler: nil)  
    }
    
    func showPhoto(){
        if let item = assetArray[selectedIndex] as? (Int, PHAsset) {
            yearLabel.text = String(item.0)
        }
        
        
        if let asset =  assetArray[selectedIndex].1 as? PHAsset {
            
            let targetSize = CGSize(width: 200, height: 200)
            assetManager.requestImage(for: asset,
                                              targetSize: targetSize,
                                              contentMode: .aspectFill,
                                              options: nil,
                                              resultHandler: { image, info in
                                                
                                                DispatchQueue.main.async(execute: {
                                                self.photoView.image = image
                                                })
            })
        }
        
        let currentIndex = String(selectedIndex + 1)
        let totalIndex = String(assetArray.count)
        
        indexLabel.text = String(currentIndex + "/" + totalIndex)

    }
    
    @available(iOSApplicationExtension 10.0, *)
    func widgetActiveDisplayModeDidChange(_ activeDisplayMode: NCWidgetDisplayMode, withMaximumSize maxSize: CGSize) {
        if (activeDisplayMode == NCWidgetDisplayMode.compact) {
            self.preferredContentSize = maxSize
        }
        else {
            //expanded
            self.preferredContentSize = CGSize(width: maxSize.width, height: 200)
        }
    }
}

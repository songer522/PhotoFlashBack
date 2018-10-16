//
//  InterfaceController.swift
//  watch Extension
//
//  Created by Song, Yang on 7/19/16.
//  Copyright © 2016 Yang Song. All rights reserved.
//

import WatchKit
import Foundation
import WatchConnectivity
import UIKit

class InterfaceController: WKInterfaceController {
    @IBOutlet weak var photoView : WKInterfaceImage!
    @IBOutlet var myTableView: WKInterfaceTable!
    var imageData : [NSData] = []
    override func awakeWithContext(context: AnyObject?) {
        super.awakeWithContext(context)
        
        // Configure interface objects here.
    }
    
    

    override func willActivate() {
        // This method is called when watch view controller is about to be visible to user
        super.willActivate()
    }

    override func didDeactivate() {
        // This method is called when watch view controller is no longer visible
        super.didDeactivate()
    }
    
    override func didAppear() {
        super.didAppear()
        session = WCSession.defaultSession()
        
        session!.sendMessage(["reference": ""], replyHandler: { (response) -> Void in
         
            if let photos = response["photos"] as? [NSData] {

                dispatch_async(dispatch_get_main_queue(), { () -> Void in
                    //print(photos)
                    if photos.count > 0 {
                        
                      self.imageData = photos
                      self.loadTable()
                    }

                })
            }
            }, errorHandler: { (error) -> Void in
               
                print(error)
        })
    }

    var session: WCSession? {
        didSet {
            if let session = session {
                session.delegate = self
                session.activateSession()
            }
        }
    }
    
    
    func loadTable() {
        
        myTableView.setNumberOfRows(imageData.count,
                                withRowType: "MyRowController")
        
        for i in 0...(imageData.count - 1) {
            
            let row = myTableView.rowControllerAtIndex(i) as! MyRowController
            row.myImage.setImage(UIImage(data:imageData[i],scale:1.0))
            
        }

    }
}

extension InterfaceController: WCSessionDelegate {
    
}


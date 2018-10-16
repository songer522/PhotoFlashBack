//
//  AppDelegate.swift
//  PhotoFlashBack
//
//  Created by Song, Yang on 4/22/16.
//  Copyright © 2016 Yang Song. All rights reserved.
//

import UIKit
import CoreData
import Photos
import WatchConnectivity
@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

//    var session: WCSession? {
//        didSet {
//            if let session = session {
//                session.delegate = self
//                session.activateSession()
//            }
//        }
//    }
    
    let assetManager = PHImageManager.default()
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        UIApplication.shared.statusBarStyle = .lightContent
//        if WCSession.isSupported() {
//            session = WCSession.defaultSession()
//        }
        Thread.sleep(forTimeInterval: 2)
        return true
    }

    func applicationWillResignActive(_ application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
        // Saves changes in the application's managed object context before the application terminates.
        self.saveContext()
    }

    // MARK: - Core Data stack

    lazy var applicationDocumentsDirectory: URL = {
        // The directory the application uses to store the Core Data store file. This code uses a directory named "com.YangSong.PhotoFlashBack" in the application's documents Application Support directory.
        let urls = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return urls[urls.count-1]
    }()

    lazy var managedObjectModel: NSManagedObjectModel = {
        // The managed object model for the application. This property is not optional. It is a fatal error for the application not to be able to find and load its model.
        let modelURL = Bundle.main.url(forResource: "PhotoFlashBack", withExtension: "momd")!
        return NSManagedObjectModel(contentsOf: modelURL)!
    }()

    lazy var persistentStoreCoordinator: NSPersistentStoreCoordinator = {
        // The persistent store coordinator for the application. This implementation creates and returns a coordinator, having added the store for the application to it. This property is optional since there are legitimate error conditions that could cause the creation of the store to fail.
        // Create the coordinator and store
        let coordinator = NSPersistentStoreCoordinator(managedObjectModel: self.managedObjectModel)
        let url = self.applicationDocumentsDirectory.appendingPathComponent("SingleViewCoreData.sqlite")
        var failureReason = "There was an error creating or loading the application's saved data."
        do {
            try coordinator.addPersistentStore(ofType: NSSQLiteStoreType, configurationName: nil, at: url, options: nil)
        } catch {
            // Report any error we got.
            var dict = [String: AnyObject]()
            dict[NSLocalizedDescriptionKey] = "Failed to initialize the application's saved data" as AnyObject
            dict[NSLocalizedFailureReasonErrorKey] = failureReason as AnyObject

            dict[NSUnderlyingErrorKey] = error as NSError
            let wrappedError = NSError(domain: "YOUR_ERROR_DOMAIN", code: 9999, userInfo: dict)
            // Replace this with code to handle the error appropriately.
            // abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
            NSLog("Unresolved error \(wrappedError), \(wrappedError.userInfo)")
            abort()
        }
        
        return coordinator
    }()

    lazy var managedObjectContext: NSManagedObjectContext = {
        // Returns the managed object context for the application (which is already bound to the persistent store coordinator for the application.) This property is optional since there are legitimate error conditions that could cause the creation of the context to fail.
        let coordinator = self.persistentStoreCoordinator
        var managedObjectContext = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
        managedObjectContext.persistentStoreCoordinator = coordinator
        return managedObjectContext
    }()

    // MARK: - Core Data Saving support

    func saveContext () {
        if managedObjectContext.hasChanges {
            do {
                try managedObjectContext.save()
            } catch {
                // Replace this implementation with code to handle the error appropriately.
                // abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
                let nserror = error as NSError
                NSLog("Unresolved error \(nserror), \(nserror.userInfo)")
                abort()
            }
        }
    }

}

//extension AppDelegate: WCSessionDelegate {
//    
//    func session(session: WCSession, didReceiveMessage message: [String : AnyObject], replyHandler: ([String : AnyObject]) -> Void) {
//       
//        let day = NSCalendar.currentCalendar().component(.Day, fromDate: NSDate())
//        let month = NSCalendar.currentCalendar().component(.Month, fromDate: NSDate())
//        var assetArray : [NSData] = []
//        let options = PHFetchOptions.init()
//        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
//        options.predicate = NSPredicate(format: "mediaType = %d", PHAssetMediaType.Image.rawValue)
//        let assetsFetchResults = PHAsset.fetchAssetsWithOptions(options)
//        
//        assetsFetchResults.enumerateObjectsUsingBlock { (object: AnyObject, count: Int, stop: UnsafeMutablePointer<ObjCBool>) in
//            if let asset = object as? PHAsset {
//                
//                let assetDay = NSCalendar.currentCalendar().component(NSCalendarUnit.Day, fromDate: asset.creationDate!)
//                let assetMonth = NSCalendar.currentCalendar().component(NSCalendarUnit.Month, fromDate: asset.creationDate!)
//                if assetDay == day && assetMonth == month {
//                    
//                    let targetSize = CGSize(width: 500  , height: 500)
//                    var options = PHImageRequestOptions()
//                    //options.resizeMode = PHImageRequestOptionsResizeMode.Exact
//                    options.deliveryMode = PHImageRequestOptionsDeliveryMode.Opportunistic
//                    options.synchronous = true
//                    options.networkAccessAllowed = true
//                    self.assetManager.requestImageForAsset(asset,
//                        targetSize: targetSize,
//                        contentMode: .AspectFill,
//                        options: options,
//                        resultHandler: { image, info in
//                            if let image = image {
//                                if let data = UIImagePNGRepresentation(image) {
//                            
//                                    assetArray.append(data)
//                                    
//                                }
//                            }
//                            
//                    })
//                }
//            }
//        }
//        
//        if assetArray.count > 0 {
//            replyHandler(["photos" : assetArray])
//        }
//        
//    }
//
//}

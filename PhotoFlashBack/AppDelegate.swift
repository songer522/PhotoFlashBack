//
//  AppDelegate.swift
//  PhotoFlashBack
//
//  Created by Yang Song on 9/19/22.
//

import UIKit
import AVFAudio
import BackgroundTasks
import Photos
import WidgetKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    
    // Background task identifier - must match Info.plist
    static let backgroundTaskIdentifier = "com.YangSong.PhotoFlashBack.fetch"

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        do{
            try AVAudioSession.sharedInstance().setCategory(AVAudioSession.Category.playback, options: [.mixWithOthers])
          try AVAudioSession.sharedInstance().setActive(true)
        }catch{//some meaningful exception handling
            
        }
        
        // Register the background task
        BGTaskScheduler.shared.register(forTaskWithIdentifier: AppDelegate.backgroundTaskIdentifier, using: nil) { [weak self] task in
            guard let self = self else { return }
            guard let refreshTask = task as? BGAppRefreshTask else {
                print("Error: Background task is not a BGAppRefreshTask")
                return
            }
            self.handleBackgroundFetch(task: refreshTask)
        }
        // Override point for customization after application launch.
        return true
    }
    
    func scheduleBackgroundFetch() {
        let fetchTask = BGAppRefreshTaskRequest(identifier: AppDelegate.backgroundTaskIdentifier)
        fetchTask.earliestBeginDate = Date(timeIntervalSinceNow: 60 * 60 * 24) // 24 hours from now

        do {
            try BGTaskScheduler.shared.submit(fetchTask)
        } catch {
            print("Could not schedule background fetch: \(error.localizedDescription)")
        }
    }
    
    func handleBackgroundFetch(task: BGAppRefreshTask) {
        // Set expiration handler to cancel operations if task expires
        task.expirationHandler = {
            task.setTaskCompleted(success: false)
        }

        // Perform your background fetch here
        PhotoManager.shared.fetchAndStoreRandomAsset { (success) in
            if success {
                // Asset fetched and stored successfully
                WidgetCenter.shared.reloadAllTimelines()
                task.setTaskCompleted(success: true)
            } else {
                // Failed to fetch or store the asset
                print("Background fetch failed: Unable to fetch or store random asset")
                task.setTaskCompleted(success: false)
            }
            
            // Schedule the next background fetch
            self.scheduleBackgroundFetch()
        }
    }



    // MARK: UISceneSession Lifecycle

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        // Called when a new scene session is being created.
        // Use this method to select a configuration to create the new scene with.
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
        // Called when the user discards a scene session.
        // If any sessions were discarded while the application was not running, this will be called shortly after application:didFinishLaunchingWithOptions.
        // Use this method to release any resources that were specific to the discarded scenes, as they will not return.
    }
}


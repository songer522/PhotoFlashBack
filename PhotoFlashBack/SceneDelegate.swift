//
//  SceneDelegate.swift
//  PhotoFlashBack
//
//  Created by Yang Song on 9/19/22.
//

import UIKit

import WidgetKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?


    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        // Use this method to optionally configure and attach the UIWindow `window` to the provided UIWindowScene `scene`.
        // If using a storyboard, the `window` property will automatically be initialized and attached to the scene.
        // This delegate does not imply the connecting scene or session are new (see `application:configurationForConnectingSceneSession` instead).
        guard let windowScene = (scene as? UIWindowScene) else { return }
        
        self.window = UIWindow(windowScene: windowScene)
        
        // Instantiate the initial view controller from the storyboard
        let storyboard = UIStoryboard(name: "Main", bundle: nil) // Replace "Main" with the name of your storyboard
        let initialViewController = storyboard.instantiateInitialViewController()
        
        // Set the initial view controller as the root view controller of the window
        self.window?.rootViewController = initialViewController
        self.window?.makeKeyAndVisible()
    }

    func sceneDidDisconnect(_ scene: UIScene) {
        // Called as the scene is being released by the system.
        // This occurs shortly after the scene enters the background, or when its session is discarded.
        // Release any resources associated with this scene that can be re-created the next time the scene connects.
        // The scene may re-connect later, as its session was not necessarily discarded (see `application:didDiscardSceneSessions` instead).
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        // Called when the scene has moved from an inactive state to an active state.
        // Use this method to restart any tasks that were paused (or not yet started) when the scene was inactive.
        guard let topVC = topMostViewController() as? PhotosViewController else { return }
        if UserDefaults.standard.bool(forKey: "ShouldRefresh") {
            topVC.refreshIfNotToday()
            UserDefaults.standard.set(false, forKey: "ShouldRefresh")
            
        }
        requestAppRating()
        DispatchQueue.global(qos: .background).async {
            PhotoManager.shared.fetchAndStoreRandomAsset { (success) in
                if success {
                    // Asset fetched and stored successfully
                } else {
                    // Failed to fetch or store the asset
                }
            }
        }
    }

    func sceneWillResignActive(_ scene: UIScene) {
        // Called when the scene will move from an active state to an inactive state.
        // This may occur due to temporary interruptions (ex. an incoming phone call).
    }

    func sceneWillEnterForeground(_ scene: UIScene) {
        // Called as the scene transitions from the background to the foreground.
        // Use this method to undo the changes made on entering the background.
        
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        // Called as the scene transitions from the foreground to the background.
        // Use this method to save data, release shared resources, and store enough scene-specific state information
        // to restore the scene back to its current state.
        WidgetCenter.shared.reloadAllTimelines()
    }
    
    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        if let url = URLContexts.first?.url, url.scheme == "openToday" {
            // Handle the URL and perform the required action.
            UserDefaults.standard.setValue(true, forKey: "ShouldRefresh")
            if let metaData =  UserDefaults(suiteName: "group.com.YangSong.PhotoFlashBack.Today")?.value(forKey: "randomAssetMetadata") as? [String: Any] {
                UserDefaults.standard.set(metaData, forKey: "ItemToGo")
            }
        }
    }

    func requestAppRating() {
        let minimumLaunchCount = 25
        let userDefaults = UserDefaults.standard
        let launchCountKey = "launchCount"
        
        let currentLaunchCount = userDefaults.integer(forKey: launchCountKey)
        userDefaults.set(currentLaunchCount + 1, forKey: launchCountKey)
        if currentLaunchCount >= minimumLaunchCount {
           
            guard let topVC = topMostViewController() else { return }
            IAPHelper.shared.setupTipJar(presentingVC: topVC)
            userDefaults.set(0, forKey: launchCountKey)
        }
    }
    
    func topMostViewController() -> UIViewController? {
        guard let rootViewController = UIApplication.shared.connectedScenes
                .filter({$0.activationState == .foregroundActive})
                .map({$0 as? UIWindowScene})
                .compactMap({$0})
                .first?.windows
                .filter({$0.isKeyWindow}).first?.rootViewController else {
            return nil
        }

        return topMostViewController(of: rootViewController)
    }

    private func topMostViewController(of viewController: UIViewController) -> UIViewController {
        if let presentedViewController = viewController.presentedViewController {
            return topMostViewController(of: presentedViewController)
        } else if let navigationController = viewController as? UINavigationController,
                  let visibleViewController = navigationController.visibleViewController {
            return topMostViewController(of: visibleViewController)
        } else if let tabBarController = viewController as? UITabBarController,
                  let selectedViewController = tabBarController.selectedViewController {
            return topMostViewController(of: selectedViewController)
        } else {
            return viewController
        }
    }

}


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

        // Cold start from a widget tap: connectionOptions carries the URL when the
        // app wasn't running. Stash it now; the grid opens it once its fetch completes.
        for context in connectionOptions.urlContexts {
            handleWidgetURL(context.url)
        }
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
        requestAppRating()
        
        Task.detached(priority: .background) {
            // Fetch multiple assets for widget (supports large widgets)
            _ = await PhotoManager.shared.fetchAndStoreMultipleAssets(count: 6)
        }

        routePendingWidgetPhoto()
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

        // Submit the first (and any subsequent) BGAppRefreshTask request here. BGTaskScheduler
        // replaces any already-pending request with the same identifier, so it's safe to call
        // this every time the app enters the background.
        (UIApplication.shared.delegate as? AppDelegate)?.scheduleBackgroundFetch()
    }
    
    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        if let url = URLContexts.first?.url {
            handleWidgetURL(url)
            // If the scene is already active, openURLContexts fires without a
            // subsequent sceneDidBecomeActive, so route immediately.
            if scene.activationState == .foregroundActive {
                routePendingWidgetPhoto()
            }
        }
    }

    // MARK: - Widget deep link

    private func handleWidgetURL(_ url: URL) {
        guard url.scheme == WidgetDeepLink.scheme else { return }
        UserDefaults.standard.setValue(true, forKey: "ShouldRefresh")
        let target = WidgetDeepLink.parse(url)
        if let metaData = WidgetDeepLink.resolveMetadata(index: target.index, localIdentifier: target.localIdentifier) {
            UserDefaults.standard.set(metaData, forKey: "ItemToGo")
        }
    }

    /// Routes a pending widget tap to the grid, even when a full-screen viewer
    /// is already presented. A stale viewer is dismissed BEFORE refreshing /
    /// opening — the open path presents a new viewer, so dismissing after
    /// would kill the viewer we just opened. ItemToGo is left in place until
    /// PhotosViewController successfully opens it (or the fetch proving it
    /// missing completes), so taps arriving mid-fetch aren't lost.
    private func routePendingWidgetPhoto() {
        guard let photosVC = photosViewController() else {
            // No grid yet (e.g. cold start before willConnect resolves) — keep
            // ItemToGo; the grid's fetch completion will pick it up.
            return
        }

        dismissViewerIfNeeded(presenting: photosVC) { [weak photosVC] in
            guard let photosVC = photosVC else { return }
            if UserDefaults.standard.bool(forKey: "ShouldRefresh") {
                UserDefaults.standard.set(false, forKey: "ShouldRefresh")
                // Either opens the pending photo immediately (already today)
                // or starts a fetch whose completion opens it.
                photosVC.refreshIfNotToday()
            } else {
                photosVC.openPendingWidgetPhoto()
            }
        }
    }

    private func dismissViewerIfNeeded(presenting photosVC: PhotosViewController, then completion: @escaping () -> Void) {
        if photosVC.presentedViewController is PhotoViewController {
            photosVC.dismiss(animated: false) {
                completion()
            }
        } else {
            completion()
        }
    }

    /// Finds the underlying grid even when a viewer (or settings) is presented
    /// on top. Unlike topMostViewController(), this never returns the viewer
    /// itself, so widget taps aren't dropped while a photo is open.
    private func photosViewController() -> PhotosViewController? {
        guard let rootViewController = UIApplication.shared.connectedScenes
            .filter({ $0.activationState == .foregroundActive || $0.activationState == .foregroundInactive })
            .map({ $0 as? UIWindowScene })
            .compactMap({ $0 })
            .first?.windows
            .filter({ $0.isKeyWindow }).first?.rootViewController else {
            return nil
        }

        var queue: [UIViewController] = [rootViewController]
        while !queue.isEmpty {
            let current = queue.removeFirst()
            if let photosVC = current as? PhotosViewController {
                return photosVC
            }
            if let nav = current as? UINavigationController {
                queue.append(contentsOf: nav.viewControllers)
                if let visible = nav.visibleViewController, !(visible is UINavigationController) {
                    queue.append(visible)
                }
            } else if let tab = current as? UITabBarController {
                if let vcs = tab.viewControllers { queue.append(contentsOf: vcs) }
                if let selected = tab.selectedViewController { queue.append(selected) }
            }
            if let presented = current.presentedViewController {
                queue.append(presented)
            }
        }
        return nil
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


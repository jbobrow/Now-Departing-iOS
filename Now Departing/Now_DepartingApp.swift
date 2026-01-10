//
//  Now_DepartingApp.swift
//  Now Departing
//
//  Created by Jonathan Bobrow on 6/8/25.
//

import SwiftUI

// AppDelegate to handle quick actions
class AppDelegate: NSObject, UIApplicationDelegate {
    static var shared: AppDelegate?
    var shortcutItemToProcess: UIApplicationShortcutItem?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        AppDelegate.shared = self

        // Set up quick action for sharing the app
        let shareIcon = UIApplicationShortcutIcon(systemImageName: "square.and.arrow.up")
        let shareShortcut = UIApplicationShortcutItem(
            type: "com.move38.Now-Departing.share",
            localizedTitle: "Share App",
            localizedSubtitle: nil,
            icon: shareIcon,
            userInfo: nil
        )
        application.shortcutItems = [shareShortcut]

        return true
    }

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        if let shortcutItem = options.shortcutItem {
            shortcutItemToProcess = shortcutItem
        }

        let sceneConfiguration = UISceneConfiguration(name: "Custom Configuration", sessionRole: connectingSceneSession.role)
        sceneConfiguration.delegateClass = SceneDelegate.self
        return sceneConfiguration
    }
}

// SceneDelegate to handle quick actions
class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func windowScene(_ windowScene: UIWindowScene, performActionFor shortcutItem: UIApplicationShortcutItem, completionHandler: @escaping (Bool) -> Void) {
        if shortcutItem.type == "com.move38.Now-Departing.share" {
            // Present share sheet immediately without fully launching the app
            DispatchQueue.main.async {
                self.presentShareSheet(in: windowScene)
            }
            completionHandler(true)
        } else {
            completionHandler(false)
        }
    }

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        // Handle quick action if app was launched from it
        if let shortcutItem = connectionOptions.shortcutItem {
            if shortcutItem.type == "com.move38.Now-Departing.share" {
                // Delay briefly to ensure window is ready
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    self.presentShareSheet(in: scene as! UIWindowScene)
                }
            }
        }
    }

    private func presentShareSheet(in windowScene: UIWindowScene) {
        guard let window = windowScene.windows.first,
              let rootViewController = window.rootViewController else {
            return
        }

        // Find the topmost view controller
        var topController = rootViewController
        while let presented = topController.presentedViewController {
            topController = presented
        }

        // Present the share sheet
        let url = URL(string: "https://apps.apple.com/us/app/now-departing/id6740440448")!
        let activityViewController = UIActivityViewController(
            activityItems: [url],
            applicationActivities: nil
        )

        // For iPad support
        if let popoverController = activityViewController.popoverPresentationController {
            popoverController.sourceView = topController.view
            popoverController.sourceRect = CGRect(x: topController.view.bounds.midX, y: topController.view.bounds.midY, width: 0, height: 0)
            popoverController.permittedArrowDirections = []
        }

        topController.present(activityViewController, animated: true)
    }
}

@main
struct Now_DepartingApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var favoritesManager = FavoritesManager()
    @StateObject private var stationDataManager = StationDataManager()
    @StateObject private var locationManager = LocationManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(favoritesManager)
                .environmentObject(stationDataManager)
                .environmentObject(locationManager)
                .preferredColorScheme(.dark) // Your dark mode preference
        }
    }
}

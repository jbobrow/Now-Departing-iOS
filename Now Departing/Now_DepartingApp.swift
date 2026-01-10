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
    func windowScene(_ windowScene: UIWindowScene, performActionFor shortcutItem: UIApplicationShortcutItem, completionHandler: @escaping (Bool) -> Void) {
        AppDelegate.shared?.shortcutItemToProcess = shortcutItem
        NotificationCenter.default.post(name: NSNotification.Name("QuickActionTriggered"), object: shortcutItem)
        completionHandler(true)
    }
}

@main
struct Now_DepartingApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var favoritesManager = FavoritesManager()
    @StateObject private var stationDataManager = StationDataManager()
    @StateObject private var locationManager = LocationManager()
    @State private var showShareSheet = false

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(favoritesManager)
                .environmentObject(stationDataManager)
                .environmentObject(locationManager)
                .preferredColorScheme(.dark) // Your dark mode preference
                .sheet(isPresented: $showShareSheet) {
                    ShareSheet(activityItems: [URL(string: "https://apps.apple.com/us/app/now-departing/id6740440448")!])
                }
                .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("QuickActionTriggered"))) { notification in
                    if let shortcutItem = notification.object as? UIApplicationShortcutItem {
                        handleShortcutItem(shortcutItem)
                    }
                }
                .onAppear {
                    // Handle quick action if app was launched from it
                    if let shortcutItem = appDelegate.shortcutItemToProcess {
                        handleShortcutItem(shortcutItem)
                        appDelegate.shortcutItemToProcess = nil
                    }
                }
        }
    }

    private func handleShortcutItem(_ shortcutItem: UIApplicationShortcutItem) {
        if shortcutItem.type == "com.move38.Now-Departing.share" {
            showShareSheet = true
        }
    }
}

// Share Sheet wrapper for UIActivityViewController
struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: nil
        )
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {
        // No update needed
    }
}

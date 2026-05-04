//
//  Now_DepartingApp.swift
//  Now Departing
//
//  Created by Jonathan Bobrow on 6/8/25.
//

import SwiftUI
import WidgetKit
import WatchConnectivity

@main
struct Now_DepartingApp: App {
    @StateObject private var favoritesManager = FavoritesManager()
    private let watchSync = WatchSyncManager.shared
    @StateObject private var stationDataManager = StationDataManager()
    @StateObject private var locationManager = LocationManager()
    @StateObject private var serviceAlertsManager = ServiceAlertsManager()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear { watchSync.activate() }
                .environmentObject(favoritesManager)
                .environmentObject(stationDataManager)
                .environmentObject(locationManager)
                .environmentObject(serviceAlertsManager)
                .preferredColorScheme(.dark) // Your dark mode preference
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            if newPhase == .active {
                // Reload widgets when app becomes active to ensure fresh data
                WidgetCenter.shared.reloadAllTimelines()
                // Refresh service alerts
                serviceAlertsManager.fetchAlerts()
            }
        }
    }
}

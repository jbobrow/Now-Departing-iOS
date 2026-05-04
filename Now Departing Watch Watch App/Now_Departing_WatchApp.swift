//
//  Now_Departing_WatchApp.swift
//  Now Departing WatchOS App
//
//  Created by Jonathan Bobrow on 12/29/24.
//

import SwiftUI
import WatchConnectivity

@main
struct NowDepartingWatchApp: App {
    @StateObject private var stationDataManager = StationDataManager()
    @StateObject private var favoritesManager = FavoritesManager()
    private let watchSync = WatchSyncManager.shared
    @StateObject private var settingsManager = SettingsManager()
    @StateObject private var locationManager = LocationManager()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear { watchSync.activate() }
                .environmentObject(stationDataManager)
                .environmentObject(favoritesManager)
                .environmentObject(settingsManager)
                .environmentObject(locationManager)
        }
    }
}

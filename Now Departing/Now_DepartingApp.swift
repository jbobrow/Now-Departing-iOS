//
//  Now_DepartingApp.swift
//  Now Departing
//
//  Created by Jonathan Bobrow on 6/8/25.
//

import SwiftUI

@main
struct Now_DepartingApp: App {
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

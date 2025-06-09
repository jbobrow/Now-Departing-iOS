//
//  Now_DepartingApp.swift
//  Now Departing
//
//  Created by Jonathan Bobrow on 6/8/25.
//

import SwiftUI

@main
struct NowDepartingApp: App {
    @StateObject private var stationDataManager = StationDataManager()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(stationDataManager)
        }
    }
}


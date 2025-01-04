//
//  Now_DepartingApp.swift
//  Now Departing Watch App
//
//  Created by Jonathan Bobrow on 12/29/24.
//

import SwiftUI

@main
struct Now_Departing_Watch_AppApp: App {
    @StateObject private var dataManager = StationDataManager()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(dataManager) // Pass the data manager to the view hierarchy
        }
        .windowToolbarLabelStyle(fixed: .automatic)
    }
}

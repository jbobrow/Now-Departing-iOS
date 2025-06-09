//
//  ContentView.swift
//  Now Departing
//
//  Created by Jonathan Bobrow on 6/8/25.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var locationManager = LocationManager()
    @EnvironmentObject var stationDataManager: StationDataManager
    @State private var isReady = false
    
    var body: some View {
        NavigationStack {
            if isReady {
                NearbyView()
                    .environmentObject(locationManager)
                    .toolbar {
                        ToolbarItem(placement: .principal) {
                            Image(systemName: "tram.fill")
                                .font(.title)
                                .foregroundColor(.secondary)
                        }
                    }
            } else {
                ProgressView("Initializing...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .onAppear {
            // Small delay to ensure everything is initialized
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                print("DEBUG: Starting location updates from ContentView")
                locationManager.requestLocationPermission()
                locationManager.startLocationUpdates()
                isReady = true
            }
        }
    }
}

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
                NearbyView(
                    onLocationRequested: {
                        print("DEBUG: User requested location access")
                        locationManager.requestLocationPermission()
                        locationManager.startLocationUpdates()
                        // NEW: Remember user's choice for future launches
                        locationManager.hasUserEnabledLocation = true
                    }
                )
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
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                // NEW: Smart loading - if user previously enabled location, start immediately
                if locationManager.hasUserEnabledLocation && locationManager.isLocationEnabled {
                    print("DEBUG: User previously enabled location, starting immediately for instant results")
                    locationManager.startLocationUpdates()
                } else {
                    print("DEBUG: App ready - location will be requested when needed")
                }
                isReady = true
            }
        }
    }
}

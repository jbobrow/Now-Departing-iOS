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
                        // Only request location when user actively wants it
                        print("DEBUG: User requested location access")
                        locationManager.requestLocationPermission()
                        locationManager.startLocationUpdates()
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
            // Just initialize without requesting location
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                print("DEBUG: App ready - location will be requested when needed")
                isReady = true
            }
        }
    }
}

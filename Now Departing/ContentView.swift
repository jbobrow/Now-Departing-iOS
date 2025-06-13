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
        if isReady {
            TabView {
                // Nearby Tab
                NavigationStack {
                    NearbyView(
                        onLocationRequested: {
                            print("DEBUG: User requested location access")
                            locationManager.requestLocationPermission()
                            locationManager.startLocationUpdates()
                            // Remember user's choice for future launches
                            locationManager.hasUserEnabledLocation = true
                        }
                    )
                    .environmentObject(locationManager)
//                    .navigationTitle("Nearby")
//                    .navigationBarTitleDisplayMode(.large)
                }
                .tabItem {
                    Image(systemName: "location.circle.fill")
                    Text("Nearby")
                }
                
                // Lines Tab
                NavigationStack {
                    LinesView()
//                        .navigationTitle("Lines")
//                        .navigationBarTitleDisplayMode(.large)
                }
                .tabItem {
                    Image(systemName: "tram.fill")
                    Text("Lines")
                }
                
                // Favorites Tab
                NavigationStack {
                    FavoritesView()
//                        .navigationTitle("Favorites")
//                        .navigationBarTitleDisplayMode(.large)
                }
                .tabItem {
                    Image(systemName: "heart.fill")
                    Text("Favorites")
                }
            }
            .accentColor(.blue)
        } else {
            ProgressView("Initializing...")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        // Smart loading - if user previously enabled location, start immediately
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
}

// MARK: - Placeholder Views

struct LinesView: View {
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            // Icon
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.1))
                    .frame(width: 120, height: 120)
                
                Image(systemName: "tram.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.blue)
                    .symbolRenderingMode(.hierarchical)
            }
            
            VStack(spacing: 16) {
                Text("Browse by Line")
                    .font(.custom("HelveticaNeue-Bold", size: 32))
                    .multilineTextAlignment(.center)
                
                Text("Select a subway line to see all stations and real-time departures")
                    .font(.custom("HelveticaNeue", size: 18))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, 8)
            }
            
            Spacer()
            
            Text("Coming Soon")
                .font(.custom("HelveticaNeue", size: 16))
                .foregroundColor(.secondary)
                .padding(.horizontal, 24)
            
            Spacer()
                .frame(height: 40)
        }
        .padding()
    }
}

struct FavoritesView: View {
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            // Icon
            ZStack {
                Circle()
                    .fill(Color.red.opacity(0.1))
                    .frame(width: 120, height: 120)
                
                Image(systemName: "heart.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.red)
                    .symbolRenderingMode(.hierarchical)
            }
            
            VStack(spacing: 16) {
                Text("Your Favorites")
                    .font(.custom("HelveticaNeue-Bold", size: 32))
                    .multilineTextAlignment(.center)
                
                Text("Save frequently used stations and directions for quick access to real-time departure information")
                    .font(.custom("HelveticaNeue", size: 18))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, 8)
            }
            
            Spacer()
            
            Text("Coming Soon")
                .font(.custom("HelveticaNeue", size: 16))
                .foregroundColor(.secondary)
                .padding(.horizontal, 24)
            
            Spacer()
                .frame(height: 40)
        }
        .padding()
    }
}

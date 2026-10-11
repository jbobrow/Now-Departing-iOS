//
//  ContentView.swift
//  Now Departing
//
//  Created by Jonathan Bobrow on 6/8/25.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var locationManager = LocationManager()
    @StateObject private var deepLinkManager = DeepLinkManager()
    @EnvironmentObject var stationDataManager: StationDataManager
    @EnvironmentObject var favoritesManager: FavoritesManager
    @State private var isReady = false
    @State private var selectedTab = 0

    private static let tabs = [
        PagedTab(id: 0, title: "Nearby", systemImage: "location.circle.fill"),
        PagedTab(id: 1, title: "Lines", systemImage: "tram.fill"),
        PagedTab(id: 2, title: "Favorites", systemImage: "heart.fill")
    ]

    var body: some View {
        if isReady {
            PagedTabView(selection: $selectedTab, tabs: Self.tabs) { tab in
                switch tab.id {
                case 0:
                    PagedTabNavigationStack {
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
                    }

                case 1:
                    LinesBrowseView()
                        .environmentObject(stationDataManager)
                        .environmentObject(favoritesManager)
                        .environmentObject(locationManager)

                default:
                    PagedTabNavigationStack {
                        FavoritesView(deepLinkManager: deepLinkManager)
                    }
                }
            }
            .tint(.blue)
            .onOpenURL { url in
                deepLinkManager.handleURL(url)
                // Switch to favorites tab when widget is tapped
                selectedTab = 2
            }
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

// MARK: - Page Navigation

/// Navigation for Nearby and Favorites. Rows push NavigationRoute values, so the stack
/// owns its path and tapping the page's tab again can pop it back to the root.
struct PagedTabNavigationStack<Root: View>: View {
    let root: Root
    @State private var path = NavigationPath()
    @Environment(\.pagedTabReselectCount) private var reselectCount

    init(@ViewBuilder root: () -> Root) {
        self.root = root()
    }

    var body: some View {
        NavigationStack(path: $path) {
            root
                .pagedTabRoot()
                .navigationDestination(for: NavigationRoute.self) { route in
                    // Outside Lines, rows only push departures
                    if case let .times(line, station, direction) = route {
                        TimesView(line: line, station: station, direction: direction)
                    }
                }
        }
        .onChange(of: reselectCount) {
            path = NavigationPath()
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

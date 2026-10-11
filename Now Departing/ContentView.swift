//
//  ContentView.swift
//  Now Departing
//
//  Created by Jonathan Bobrow on 6/8/25.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var locationManager: LocationManager
    @StateObject private var deepLinkManager = DeepLinkManager()
    @EnvironmentObject var stationDataManager: StationDataManager
    @EnvironmentObject var favoritesManager: FavoritesManager
    @State private var isReady = false
    @State private var selectedTab = 0
    @AppStorage(Onboarding.completedKey) private var hasCompletedOnboarding = false
    @State private var showOnboarding = false
    /// The last version whose What's New was shown, or skipped because
    /// onboarding came first.
    @AppStorage("lastWhatsNewVersion") private var lastWhatsNewVersion = ""
    @State private var whatsNew: WhatsNew?

    private static let tabs = [
        PagedTab(id: 0, title: "Nearby", systemImage: "location.circle.fill"),
        PagedTab(id: 1, title: "Lines", systemImage: "tram.fill"),
        PagedTab(id: 2, title: "Favorites", systemImage: "heart.fill")
    ]

    var body: some View {
        Group {
            if isReady {
                PagedTabView(selection: $selectedTab, tabs: Self.tabs) { tab in
                    switch tab.id {
                    case 0:
                        PagedTabNavigationStack {
                            NearbyView(
                                onLocationRequested: {
                                    locationManager.enableForNearby()
                                }
                            )
                        }

                    case 1:
                        LinesBrowseView()

                    default:
                        PagedTabNavigationStack {
                            FavoritesView(deepLinkManager: deepLinkManager)
                        }
                    }
                }
                .tint(.blue)
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
                            if hasCompletedOnboarding {
                                showWhatsNewIfNeeded()
                            } else {
                                showOnboarding = true
                            }
                        }
                    }
            }
        }
        // Outside the isReady check: a widget tap that launches the app can deliver
        // its URL while the spinner is still up
        .onOpenURL { url in
            deepLinkManager.handleURL(url)
            // Switch to favorites tab when widget is tapped
            selectedTab = 2
        }
        .fullScreenCover(isPresented: $showOnboarding) {
            OnboardingView {
                hasCompletedOnboarding = true
                // A new install learns it all from onboarding
                lastWhatsNewVersion = WhatsNew.current?.version ?? ""
                showOnboarding = false
            }
        }
        .fullScreenCover(item: $whatsNew) { whatsNew in
            WhatsNewView(whatsNew: whatsNew) { self.whatsNew = nil }
        }
    }

    /// Shows what's new, once, to someone who updated to a version that has
    /// something to show. Marked as seen as soon as it's up, so it never
    /// comes back, however it's closed.
    private func showWhatsNewIfNeeded() {
        guard let current = WhatsNew.current, current.version != lastWhatsNewVersion else { return }
        lastWhatsNewVersion = current.version
        whatsNew = current
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

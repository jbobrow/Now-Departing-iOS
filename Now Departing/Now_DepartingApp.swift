//
//  Now_DepartingApp.swift
//  Now Departing
//
//  Created by Jonathan Bobrow on 6/8/25.
//

import SwiftUI
import WidgetKit
import WatchConnectivity

@main
struct Now_DepartingApp: App {
    @StateObject private var favoritesManager = FavoritesManager()
    private let watchSync = WatchSyncManager.shared
    @StateObject private var stationDataManager = StationDataManager()
    @StateObject private var locationManager = LocationManager()
    @StateObject private var serviceAlertsManager = ServiceAlertsManager()
    @Environment(\.scenePhase) private var scenePhase

    init() {
        // Before anything this launch saves, which would look like earlier use
        Onboarding.skipForEarlierInstalls()

        // Checked many times a day, often on the way to a train: only ask
        // people who've relied on it for a week or so, and only right after
        // they save a trip, when they've slowed down long enough to set it up
        ReviewPrompter.shared.policy.minActiveDays = 7
        ReviewPrompter.shared.policy.minDaysSinceFirstUse = 10
        ReviewPrompter.shared.policy.minSignificantEvents = 10
        ReviewPrompter.shared.policy.presentationDelay = 2
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .tracksReviewEligibility()
                .onAppear { watchSync.activate() }
                .environmentObject(favoritesManager)
                .environmentObject(stationDataManager)
                .environmentObject(locationManager)
                .environmentObject(serviceAlertsManager)
                .preferredColorScheme(.dark) // Your dark mode preference
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            if newPhase == .active {
                // Reload widgets when app becomes active to ensure fresh data
                WidgetCenter.shared.reloadAllTimelines()
                // Refresh service alerts
                serviceAlertsManager.fetchAlerts()
            }
        }
    }
}

extension AboutApp {
    static let nowDeparting = AboutApp(
        name: "Now Departing",
        icon: Image("AppIconImage"),
        description: "Real-time New York City subway departures for the stations around you "
            + "and your favorite trips, on iPhone, Apple Watch, widgets and the Lock Screen.",
        website: URL(string: "https://nowdeparting.jonbobrow.com"),
        credits: "Arrival times from the MTA's real-time data feeds.",
        appStoreID: "6740440448")
}

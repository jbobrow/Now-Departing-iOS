//
//  NearbyView.swift
//  Now Departing
//
//  Created by Jonathan Bobrow on 6/8/25.
//

import SwiftUI
import CoreLocation

struct NearbyView: View {
    @EnvironmentObject var locationManager: LocationManager
    @EnvironmentObject var stationDataManager: StationDataManager
    @EnvironmentObject var favoritesManager: FavoritesManager
    @StateObject private var nearbyTrainsManager = NearbyTrainsManager(stationDataManager: StationDataManager())
    @State private var hasAppeared = false
    
    // Callback for when location is requested
    let onLocationRequested: () -> Void
    
    @State private var hasRequestedLocation = false
    
    // Auto-refresh state - Updated to track actual data updates
    @State private var lastDataUpdated: Date?   // Changed from lastUpdated
    @State private var autoRefreshTimer: Timer?
    @State private var currentTime = Date()     // For updating the "time since" display
    @State private var liveTimeTimer: Timer?    // Timer for live time updates

    // Location update tracking
    @State private var lastLocationUpdate: Date?
    @State private var locationUpdateCount = 0
    
    private func getLine(for id: String) -> SubwayLine? {
        return SubwayLinesData.allLines.first(where: { $0.id == id })
    }
    
    private func handleLocationChange(_ newLocation: CLLocation?) {
        guard let location = newLocation else { return }
        
        lastLocationUpdate = Date()
        locationUpdateCount += 1
        print("DEBUG: Location updated (#\(locationUpdateCount)): \(location.coordinate.latitude), \(location.coordinate.longitude)")
        startFetchingWithLocation(location)
    }
    
    var body: some View {
        Group {
            switch locationManager.authorizationStatus {
            case .notDetermined:
                LocationPromptView(onLocationRequested: {
                    hasRequestedLocation = true
                    onLocationRequested()
                })
                
            case .denied, .restricted:
                LocationDeniedView()
                
            case .authorizedWhenInUse, .authorizedAlways:
                AuthorizedView()
                
            @unknown default:
                EmptyView()
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            print("DEBUG: NearbyView onAppear - hasAppeared: \(hasAppeared)")
            
            if !hasAppeared {
                hasAppeared = true
                setupInitialState()
                startTimeUpdateTimer()
                startLiveTimeTimer()
            }
            
            // ALWAYS start auto-refresh when the nearby tab is opened
            startAutoRefresh()
            
            // ALWAYS trigger a data update when the nearby tab is opened
            triggerDataUpdateOnTabOpen()
        }
        .onDisappear {
            print("DEBUG: NearbyView onDisappear")
            stopAutoRefresh()
            stopLiveTimeTimer()
        }
        .onChange(of: locationManager.authorizationStatus) { oldStatus, newStatus in
            print("DEBUG: Authorization status changed from \(oldStatus.rawValue) to \(newStatus.rawValue)")
            if newStatus == .authorizedWhenInUse || newStatus == .authorizedAlways {
                // Request location immediately after permission is granted
                locationManager.requestOneTimeUpdate()
            }
        }
        .onChange(of: locationManager.location) { _, newLocation in
            handleLocationChange(newLocation)
        }
        // NEW: Watch for when data actually gets updated and mark the timestamp
        .onChange(of: nearbyTrainsManager.nearbyTrains) { oldTrains, newTrains in
            if !newTrains.isEmpty && !nearbyTrainsManager.isLoading {
                print("DEBUG: Data actually updated with \(newTrains.count) trains")
                lastDataUpdated = Date()
            }
        }
    }
    
    // NEW: Function to trigger data update when tab is opened
    private func triggerDataUpdateOnTabOpen() {
        print("DEBUG: Triggering data update on tab open")
        
        // Check if we have permission and location
        guard locationManager.authorizationStatus == .authorizedWhenInUse ||
              locationManager.authorizationStatus == .authorizedAlways else {
            print("DEBUG: No location permission for tab open update")
            return
        }
        
        if let location = locationManager.location {
            print("DEBUG: Starting fetch with existing location on tab open")
            startFetchingWithLocation(location)
        } else {
            print("DEBUG: Requesting location update on tab open")
            locationManager.requestOneTimeUpdate()
        }
    }
    
    private func setupInitialState() {
        // Small delay to avoid initialization issues
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            nearbyTrainsManager.updateStationDataManager(stationDataManager)
            
            print("DEBUG: Location enabled: \(locationManager.isLocationEnabled)")
            print("DEBUG: Authorization status: \(locationManager.authorizationStatus.rawValue)")
            print("DEBUG: Current location: \(locationManager.location?.description ?? "nil")")
            print("DEBUG: Has user enabled location: \(locationManager.hasUserEnabledLocation)")
            
            // Handle different authorization states
            switch locationManager.authorizationStatus {
            case .notDetermined:
                // Check if user previously enabled location
                if locationManager.hasUserEnabledLocation {
                    print("DEBUG: User previously enabled location but permission needs refresh")
                    // Could show different prompt here if needed
                } else {
                    print("DEBUG: Location permission not determined - waiting for user action")
                }
                
            case .authorizedWhenInUse, .authorizedAlways:
                if let location = locationManager.location {
                    print("DEBUG: Starting initial fetch with existing location (possibly cached)")
                    startFetchingWithLocation(location)
                } else {
                    print("DEBUG: Permission granted but no location, requesting update")
                    locationManager.requestOneTimeUpdate()
                }
                
            default:
                print("DEBUG: Location access denied or restricted")
                break
            }
        }
    }
    
    private func startFetchingWithLocation(_ location: CLLocation) {
        print("DEBUG: Starting fetch with location: \(location)")
        nearbyTrainsManager.startFetching(location: location)
        // Note: We don't set lastDataUpdated here anymore - we wait for actual data
    }
    
    // MARK: - Auto-refresh methods
    
    private func startAutoRefresh() {
        // Stop any existing timer first
        stopAutoRefresh()
        
        print("DEBUG: Starting auto-refresh timer (30 second interval for iOS)")
        autoRefreshTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { _ in
            performAutoRefresh()
        }
    }
    
    private func stopAutoRefresh() {
        if autoRefreshTimer != nil {
            print("DEBUG: Stopping auto-refresh timer")
            autoRefreshTimer?.invalidate()
            autoRefreshTimer = nil
        }
    }
    
    private func startTimeUpdateTimer() {
        let timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            currentTime = Date()
        }
        // This ensures the timer continues running during UI interactions like scrolling/dragging
        RunLoop.main.add(timer, forMode: .common)
    }
    
    // Start live time timer for real-time updates
    private func startLiveTimeTimer() {
        print("DEBUG: Starting live time timer")
        liveTimeTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            currentTime = Date()
        }
    }

    // Stop live time timer
    private func stopLiveTimeTimer() {
        print("DEBUG: Stopping live time timer")
        liveTimeTimer?.invalidate()
        liveTimeTimer = nil
    }
    
    private func performAutoRefresh() {
        // Only auto-refresh if we have permission
        guard locationManager.authorizationStatus == .authorizedWhenInUse ||
              locationManager.authorizationStatus == .authorizedAlways else {
            print("DEBUG: Skipping auto-refresh - no location permission")
            return
        }
        
        print("DEBUG: Performing auto-refresh (15s timer) - requesting fresh location")
        
        // UPDATED: For iOS, also refresh location more frequently since users might be moving
        locationManager.requestOneTimeUpdate()
        
        // Also refresh train data with current location if available
        if let location = locationManager.location {
            startFetchingWithLocation(location)
        }
    }
    
    private func getTimeSinceLastUpdated() -> String {
        guard let lastDataUpdated = lastDataUpdated else { return "" }
        
        let interval = currentTime.timeIntervalSince(lastDataUpdated)
        let minutes = Int(interval / 60)
        let seconds = Int(interval.truncatingRemainder(dividingBy: 60))
        
        if minutes > 0 {
            return "Updated \(minutes)m ago"
        } else {
            return "Updated \(seconds)s ago"
        }
    }
    
    @ViewBuilder
    func AuthorizedView() -> some View {
        if nearbyTrainsManager.nearbyTrains.isEmpty && nearbyTrainsManager.isLoading {
            // Show loading, but with different message if we're getting fresh location vs using cached
            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.2)
                
                Text(locationManager.isSearchingForLocation ?
                     "Finding your location..." :
                     "Loading nearby trains...")
                    .font(.headline)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if nearbyTrainsManager.nearbyTrains.isEmpty && !nearbyTrainsManager.isLoading && !locationManager.isSearchingForLocation {
            // Empty state - but this should be rare with cached data
            VStack {
                // Time since updated indicator for empty state
                if lastDataUpdated != nil {
                    TimeIndicatorView(
                        timeSinceUpdated: getTimeSinceLastUpdated(),
                        lastLocationUpdate: lastLocationUpdate,
                        locationUpdateCount: locationUpdateCount
                    )
                }
                
                List {
                    Section {
                        EmptyStateContent()
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                    }
                }
                .listStyle(.plain)
                .refreshable {
                    await performRefreshWithText()
                }
                .safeAreaInset(edge: .bottom) {
                    Color.clear.frame(height: 20)
                }
            }
        } else if let error = locationManager.locationError {
            ErrorView(message: error) {
                print("DEBUG: Retrying location from error view")
                locationManager.retryLocation()
            }
        } else if !nearbyTrainsManager.errorMessage.isEmpty {
            ErrorView(message: nearbyTrainsManager.errorMessage) {
                print("DEBUG: Retrying fetch from error view")
                retryFetch()
            }
        } else {
            TrainsList()
        }
    }
    
    private func retryFetch() {
        if let location = locationManager.location {
            startFetchingWithLocation(location)
        } else {
            print("DEBUG: No location available for retry, requesting location update")
            locationManager.requestOneTimeUpdate()
        }
    }
    
    @ViewBuilder
    func TrainsList() -> some View {
        if nearbyTrainsManager.nearbyTrains.isEmpty && !nearbyTrainsManager.isLoading {
            EmptyStateView()
        } else {
            PopulatedTrainsView()
        }
    }

    @ViewBuilder
    private func EmptyStateView() -> some View {
        VStack {
            // Time since updated indicator for empty state
            if lastDataUpdated != nil {
                TimeIndicatorView(
                    timeSinceUpdated: getTimeSinceLastUpdated(),
                    lastLocationUpdate: lastLocationUpdate,
                    locationUpdateCount: locationUpdateCount
                )
            }
            
            List {
                Section {
                    EmptyStateContent()
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                }
            }
            .listStyle(.plain)
            .refreshable {
                await performRefreshWithText()
            }
            .safeAreaInset(edge: .bottom) {
                Color.clear.frame(height: 20)
            }
        }
    }

    @ViewBuilder
    private func PopulatedTrainsView() -> some View {
        ZStack(alignment: .top) {
            TrainsListContent()
            LoadingOverlay()
            
            // Debug borough display
//            VStack {
//                if let location = locationManager.location {
//                    let borough = LocationBasedDirectionHelper.getBoroughForLocation(location)
//                    let boroughName = switch borough {
//                    case .manhattan: "Manhattan"
//                    case .brooklyn: "Brooklyn"
//                    case .queens: "Queens"
//                    case .bronx: "Bronx"
//                    case .statenIsland: "Staten Island"
//                    case .unknown: "Unknown"
//                    }
//                    
//                    Text("\(boroughName)")
//                        .font(.caption)
//                        .fontWeight(.bold)
//                        .foregroundColor(.black)
//                        .padding(.horizontal, 12)
//                        .padding(.vertical, 4)
//                        .background(Color.white)
//                        .cornerRadius(12)
//                        .padding(.top, 8)
//                }
//                Spacer()
//            }
        }
    }

    @ViewBuilder
    private func TrainsListContent() -> some View {
        VStack(spacing: 0) {
            // Time since updated indicator
            if lastDataUpdated != nil {
                TimeIndicatorView(
                    timeSinceUpdated: getTimeSinceLastUpdated(),
                    lastLocationUpdate: lastLocationUpdate,
                    locationUpdateCount: locationUpdateCount
                )
            }
            
            TrainsListView()
        }
    }

    @ViewBuilder
    private func TrainsListView() -> some View {
        List {
            // Train data sections
            ForEach(groupTrainsByStation(), id: \.stationId) { group in
                TrainGroupSection(group: group)
            }
        }
        .listStyle(.plain)
        .refreshable {
            await performRefreshWithText()
        }
        .safeAreaInset(edge: .bottom) {
            Color.clear.frame(height: 20)
        }
    }

    @ViewBuilder
    private func TrainGroupSection(group: (stationId: String, stationDisplay: String, distanceText: String, trainsByLineAndDirection: [(line: SubwayLine, direction: String, trains: [NearbyTrain], lineDirectionId: String)])) -> some View {
        Section {
            ForEach(group.trainsByLineAndDirection, id: \.lineDirectionId) { item in
                ConsolidatedTrainRow(
                    primaryTrain: item.trains[0],
                    additionalTrains: Array(item.trains.dropFirst()),
                    line: item.line,
                    stationDataManager: stationDataManager,
                    favoritesManager: favoritesManager
                )
                .environmentObject(locationManager) // Add this line
            }
        } header: {
            StationHeader(
                stationDisplay: group.stationDisplay,
                distanceText: group.distanceText
            )
        }
    }

    @ViewBuilder
    private func LoadingOverlay() -> some View {
        if nearbyTrainsManager.isLoading {
            VStack {
                HStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(0.8)
                    
                    Text("Updating...")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(UIColor.systemBackground).opacity(0.95))
                        .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 2)
                )
                .padding(.top, 8)
                .transition(.opacity.combined(with: .move(edge: .top)))
                
                Spacer()
            }
            .animation(.easeInOut(duration: 0.3), value: nearbyTrainsManager.isLoading)
        }
    }

    @MainActor
    private func performRefreshWithText() async {
        print("DEBUG: Manual refresh triggered")
        
        // Very small delay to let the native spinner appear first
        try? await Task.sleep(for: .milliseconds(100))
        
        if let location = locationManager.location {
            print("DEBUG: Refreshing with existing location: \(location)")
            startFetchingWithLocation(location)
            
            // Wait for the actual network request to complete
            // The native refreshable will keep the spinner visible until this function returns
            while nearbyTrainsManager.isLoading {
                try? await Task.sleep(for: .milliseconds(100))
            }
        } else {
            print("DEBUG: No location for refresh, requesting new location")
            locationManager.requestOneTimeUpdate()
            
            // Wait a bit for location to be updated
            try? await Task.sleep(for: .seconds(2))
            
            if let location = locationManager.location {
                print("DEBUG: Got location after waiting: \(location)")
                startFetchingWithLocation(location)
                
                // Wait for completion
                while nearbyTrainsManager.isLoading {
                    try? await Task.sleep(for: .milliseconds(100))
                }
            } else {
                print("DEBUG: Still no location after waiting")
            }
        }
        
        // Small delay to ensure smooth dismissal animation
        try? await Task.sleep(for: .milliseconds(200))
    }

    // MARK: - Time Indicator View
    
    struct TimeIndicatorView: View {
        let timeSinceUpdated: String
        let lastLocationUpdate: Date?
        let locationUpdateCount: Int
        @State private var currentTime = Date()
        
        private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
        
        private var locationUpdateText: String {
            guard let lastLocationUpdate = lastLocationUpdate else { return "No location updates" }
            
            let interval = currentTime.timeIntervalSince(lastLocationUpdate)
            let seconds = Int(interval)
            
            if seconds < 60 {
                return "Location updated \(seconds)s ago (#\(locationUpdateCount))"
            } else {
                let minutes = seconds / 60
                return "Location updated \(minutes)m ago (#\(locationUpdateCount))"
            }
        }
        
        var body: some View {
            VStack(alignment: .trailing, spacing: 2) {
                HStack {
                    Spacer()
                    Text(timeSinceUpdated)
                        .font(.custom("HelveticaNeue", size: 12))
                        .foregroundColor(.secondary.opacity(0.7))
                }
                
                HStack {
                    Spacer()
                    Text(locationUpdateText)
                        .font(.custom("HelveticaNeue", size: 10))
                        .foregroundColor(.secondary.opacity(0.5))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 4)
            .background(Color(UIColor.systemBackground))
            .onReceive(timer) { time in
                currentTime = time
            }
        }
    }

    // Add this helper view
    struct StationHeader: View {
        let stationDisplay: String
        let distanceText: String
        
        var body: some View {
            HStack(alignment: .top) {
                Text(stationDisplay)
                    .font(.custom("HelveticaNeue-Bold", size: 32))
                    .foregroundColor(.primary)
                    .textCase(.none)
                    .padding(EdgeInsets(top: 4, leading: 0, bottom: 0, trailing: 0))
                Spacer()
                Text(distanceText)
                    .font(.custom("HelveticaNeue", size: 14))
                    .foregroundColor(.secondary)
                    .padding(EdgeInsets(top: 8, leading: 0, bottom: 0, trailing: 0))
            }
            .overlay(
                Rectangle()
                    .frame(height: 2)
                    .foregroundColor(.primary),
                alignment: .top
            )
        }
    }
    
    struct ConsolidatedTrainRow: View {
        let primaryTrain: NearbyTrain
        let additionalTrains: [NearbyTrain]
        let line: SubwayLine
        let stationDataManager: StationDataManager
        let favoritesManager: FavoritesManager
        
        // Add location manager to get current location
        @EnvironmentObject var locationManager: LocationManager
        @State private var currentTime = Date()
        
        // Location update tracking
        @State private var lastLocationUpdate: Date?
        @State private var locationUpdateCount = 0
        
        private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
        
        // Check if this train/station/direction combination is already favorited
        private var isFavorited: Bool {
            favoritesManager.isFavorite(
                lineId: primaryTrain.lineId,
                stationName: primaryTrain.stationName,
                direction: primaryTrain.direction
            )
        }
        
        var body: some View {
            NavigationLink(destination: TimesView(
                line: line,
                station: Station(display: primaryTrain.stationDisplay, name: primaryTrain.stationName),
                direction: primaryTrain.direction
            )) {
                VStack(alignment: .leading, spacing: 8) {
                    // Main row
                    HStack(spacing: 12) {
                        // Line badge
                        Text(line.label)
                            .font(.custom("HelveticaNeue-Bold", size: 32))
                            .foregroundColor(line.fg_color)
                            .frame(width: 48, height: 48)
                            .background(Circle().fill(line.bg_color))

                        // Direction - Updated to use location-based helper
                        VStack(alignment: .leading, spacing: 2) {
                            Text(LocationBasedDirectionHelper.getContextualDestination(
                                for: primaryTrain.lineId,
                                direction: primaryTrain.direction,
                                currentLocation: locationManager.location
                            ))
                                .font(.custom("HelveticaNeue-Bold", size: 20))

                            // Use terminal station if available, fallback to destination
                            Text(DirectionHelper.getToTerminalStation(
                                for: primaryTrain.lineId,
                            direction: primaryTrain.direction,
                            stationDataManager: stationDataManager
                        ))
                            .font(.custom("HelveticaNeue", size: 14))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 2) {
                        // Primary time
                        Text(primaryTrain.getLiveTimeText(currentTime: currentTime, fullText: true))
                            .font(.custom("HelveticaNeue-Bold", size: 26))
                            .foregroundColor(.primary)
                        
                        // Additional times (if any)
                        if !additionalTrains.isEmpty {
                            HStack {
                                Text(additionalTrains.prefix(5).map { train in
                                    train.getLiveTimeText(currentTime: currentTime)
                                }.joined(separator: ", "))
                                .font(.custom("HelveticaNeue", size: 14))
                                .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
            .padding(.vertical, 4)
            }
            .buttonStyle(PlainButtonStyle())
            .onReceive(timer) { time in
                currentTime = time
            }
            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                if isFavorited {
                    // Remove from favorites button
                    Button {
                        removeFavorite()
                    } label: {
                        Label("Remove", systemImage: "heart.slash.fill")
                    }
                    .tint(.red)
                } else {
                    // Add to favorites button
                    Button {
                        addToFavorites()
                    } label: {
                        Label("Favorite", systemImage: "heart.fill")
                    }
                    .tint(.blue)
                }
            }
            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                if isFavorited {
                    // Remove from favorites button (left swipe)
                    Button {
                        removeFavorite()
                    } label: {
                        Label("Remove", systemImage: "heart.slash.fill")
                    }
                    .tint(.red)
                } else {
                    // Add to favorites button (left swipe)
                    Button {
                        addToFavorites()
                    } label: {
                        Label("Favorite", systemImage: "heart.fill")
                    }
                    .tint(.blue)
                }
            }
        }
        
        // MARK: - Favorite Actions
        
        private func addToFavorites() {
            // Add haptic feedback
            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
            impactFeedback.impactOccurred()
            
            favoritesManager.addFavorite(
                lineId: primaryTrain.lineId,
                stationName: primaryTrain.stationName,
                stationDisplay: primaryTrain.stationDisplay,
                direction: primaryTrain.direction
            )
        }
        
        private func removeFavorite() {
            // Add haptic feedback
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
            
            // Find the matching favorite and remove it
            if let favorite = favoritesManager.favorites.first(where: {
                $0.lineId == primaryTrain.lineId &&
                $0.stationName == primaryTrain.stationName &&
                $0.direction == primaryTrain.direction
            }) {
                favoritesManager.removeFavorite(favorite: favorite)
            }
        }
    }
    
    func groupTrainsByStation() -> [(stationId: String, stationDisplay: String, distanceText: String, trainsByLineAndDirection: [(line: SubwayLine, direction: String, trains: [NearbyTrain], lineDirectionId: String)])] {
        // Filter out stale trains (those that have departed more than 2 minutes ago)
        let currentTime = Date()
        let freshTrains = nearbyTrainsManager.nearbyTrains.filter { train in
            let timeInterval = train.arrivalTime.timeIntervalSince(currentTime)
            return timeInterval > -120 // Keep trains that departed less than 2 minutes ago
        }
        
        // If we filtered out trains, it means we have stale data - show loading indicator
        if freshTrains.count < nearbyTrainsManager.nearbyTrains.count {
            print("DEBUG: Filtered out \(nearbyTrainsManager.nearbyTrains.count - freshTrains.count) stale trains")
        }
        
        let grouped = Dictionary(grouping: freshTrains) { $0.stationId }
        
        return grouped.map { (stationId, trains) in
            let firstTrain = trains.first!
            let distanceText = formatDistance(firstTrain.distanceInMeters)
            
            // Group by line AND direction
            let lineDirectionGroups = Dictionary(grouping: trains) { train in
                "\(train.lineId)-\(train.direction)"
            }
            
            let trainsByLineAndDirection = lineDirectionGroups.compactMap { (key, trains) -> (line: SubwayLine, direction: String, trains: [NearbyTrain], lineDirectionId: String)? in
                guard let firstTrain = trains.first,
                      let line = getLine(for: firstTrain.lineId) else { return nil }
                
                let sortedTrains = trains.sorted { $0.arrivalTime < $1.arrivalTime }
                return (
                    line: line,
                    direction: firstTrain.direction,
                    trains: sortedTrains,
                    lineDirectionId: "\(line.id)-\(firstTrain.direction)"
                )
            }
            .sorted { (a, b) in
                // Sort by line ID first, then by direction (N before S)
                if a.line.id == b.line.id {
                    return a.direction < b.direction
                }
                return a.line.id < b.line.id
            }
            
            return (
                stationId: stationId,
                stationDisplay: firstTrain.stationDisplay,
                distanceText: distanceText,
                trainsByLineAndDirection: trainsByLineAndDirection
            )
        }.sorted {
            // Sort by distance (closest first), then by station ID alphabetically for consistent ordering
            let distance1 = $0.trainsByLineAndDirection.first?.trains.first?.distanceInMeters ?? Double.infinity
            let distance2 = $1.trainsByLineAndDirection.first?.trains.first?.distanceInMeters ?? Double.infinity
            
            // If distances are very close (within 10 meters), sort alphabetically by station ID
            if abs(distance1 - distance2) < 10 {
                return $0.stationId < $1.stationId
            }
            
            return distance1 < distance2
        }
    }
    
    func formatDistance(_ meters: Double) -> String {
        let feet = meters * 3.28084
        if feet < 1000 {
            return "\(Int(feet))ft"
        } else {
            let miles = feet / 5280
            return String(format: "%.1fmi", miles)
        }
    }
}

// MARK: - Location Permission Views

struct LocationPromptView: View {
    let onLocationRequested: () -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            // Icon with subtle animation
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.1))
                    .frame(width: 120, height: 120)
                
                Image(systemName: "location.circle.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.blue)
                    .symbolRenderingMode(.hierarchical)
            }
            
            VStack(spacing: 16) {
                Text("Find Nearby Trains")
                    .font(.custom("HelveticaNeue-Bold", size: 32))
                    .multilineTextAlignment(.center)
                
                Text("See real-time subway arrivals at stations near your current location")
                    .font(.custom("HelveticaNeue", size: 18))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, 8)
            }
            
            Spacer()
            
            VStack(spacing: 16) {
                Button(action: onLocationRequested) {
                    HStack(spacing: 8) {
                        Image(systemName: "location.fill")
                        Text("Enable Location")
                    }
                    .font(.custom("HelveticaNeue-Bold", size: 18))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.blue)
                    .cornerRadius(14)
                }
                
                Text("Location data is only used to find nearby stations and is not stored or shared")
                    .font(.custom("HelveticaNeue", size: 14))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)
            }
            .padding(.horizontal, 24)
            
            Spacer()
                .frame(height: 40)
        }
        .padding()
    }
}

struct LocationDeniedView: View {
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            // Icon
            ZStack {
                Circle()
                    .fill(Color.red.opacity(0.1))
                    .frame(width: 120, height: 120)
                
                Image(systemName: "location.slash.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.red)
                    .symbolRenderingMode(.hierarchical)
            }
            
            VStack(spacing: 16) {
                Text("Location Access Denied")
                    .font(.custom("HelveticaNeue-Bold", size: 28))
                    .multilineTextAlignment(.center)
                
                Text("To see nearby trains, please enable location access in your device settings")
                    .font(.custom("HelveticaNeue", size: 18))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, 8)
            }
            
            Spacer()
            
            Button(action: {
                if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(settingsURL)
                }
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "gear")
                    Text("Open Settings")
                }
                .font(.custom("HelveticaNeue-Bold", size: 18))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.gray)
                .cornerRadius(14)
            }
            .padding(.horizontal, 24)
            
            Spacer()
                .frame(height: 40)
        }
        .padding()
    }
}

struct ErrorView: View {
    let message: String
    let retry: () -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            // Icon
            ZStack {
                Circle()
                    .fill(Color.orange.opacity(0.1))
                    .frame(width: 120, height: 120)
                
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 70))
                    .foregroundColor(.orange)
                    .symbolRenderingMode(.hierarchical)
            }
            
            VStack(spacing: 12) {
                Text("Something Went Wrong")
                    .font(.custom("HelveticaNeue-Bold", size: 28))
                
                Text(message)
                    .font(.custom("HelveticaNeue", size: 17))
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                    .lineSpacing(4)
            }
            .padding(.horizontal, 24)
            
            Spacer()
            
            Button(action: retry) {
                HStack {
                    Image(systemName: "arrow.clockwise")
                    Text("Try Again")
                }
                .font(.custom("HelveticaNeue-Medium", size: 18))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.orange)
                .foregroundColor(.white)
                .cornerRadius(14)
            }
            .padding(.horizontal, 24)
            
            Spacer()
                .frame(height: 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(UIColor.systemBackground))
    }
}

struct EmptyStateContent: View {
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
                .frame(height: 60)
            
            // Icon
            ZStack {
                Circle()
                    .fill(Color.gray.opacity(0.1))
                    .frame(width: 120, height: 120)
                
                Image(systemName: "tram.circle")
                    .font(.system(size: 80))
                    .foregroundColor(.gray)
                    .symbolRenderingMode(.hierarchical)
            }
            
            VStack(spacing: 12) {
                Text("No Trains Nearby")
                    .font(.custom("HelveticaNeue-Bold", size: 28))
                
                Text("No trains arriving within the next\n30 minutes at nearby stations")
                    .font(.custom("HelveticaNeue", size: 17))
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                    .lineSpacing(4)
            }
            
            Spacer()
                .frame(height: 40)
            
            VStack(spacing: 16) {
                Image(systemName: "arrow.down")
                    .font(.system(size: 24))
                    .foregroundColor(.secondary)
                
                Text("Pull to refresh")
                    .font(.custom("HelveticaNeue", size: 16))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
                .frame(height: 60)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Subway Lines Data
// SubwayLinesData is now imported from Shared/SubwayLineFactory.swift

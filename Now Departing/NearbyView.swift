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
    @StateObject private var nearbyTrainsManager = NearbyTrainsManager(stationDataManager: StationDataManager())
    @State private var hasAppeared = false
    
    private func getLine(for id: String) -> SubwayLine? {
        return SubwayLinesData.allLines.first(where: { $0.id == id })
    }
    
    var body: some View {
        Group {
            switch locationManager.authorizationStatus {
            case .notDetermined:
                LocationPermissionView()
                
            case .denied, .restricted:
                LocationDeniedView()
                
            case .authorizedWhenInUse, .authorizedAlways:
                AuthorizedView()
                
            @unknown default:
                EmptyView()
            }
        }
        .onAppear {
            if !hasAppeared {
                hasAppeared = true
                setupInitialState()
            }
        }
        .onChange(of: locationManager.authorizationStatus) { oldStatus, newStatus in
            print("DEBUG: Authorization status changed from \(oldStatus.rawValue) to \(newStatus.rawValue)")
            if newStatus == .authorizedWhenInUse || newStatus == .authorizedAlways {
                // Request location immediately after permission is granted
                locationManager.requestOneTimeUpdate()
            }
        }
        .onChange(of: locationManager.location) { oldLocation, newLocation in
            print("DEBUG: Location changed from \(oldLocation?.description ?? "nil") to \(newLocation?.description ?? "nil")")
            if let location = newLocation {
                startFetchingWithLocation(location)
            }
        }
    }
    
    private func setupInitialState() {
        // Small delay to avoid initialization issues
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            nearbyTrainsManager.updateStationDataManager(stationDataManager)
            
            print("DEBUG: Location enabled: \(locationManager.isLocationEnabled)")
            print("DEBUG: Authorization status: \(locationManager.authorizationStatus.rawValue)")
            print("DEBUG: Current location: \(locationManager.location?.description ?? "nil")")
            
            // Handle different authorization states
            switch locationManager.authorizationStatus {
            case .notDetermined:
                print("DEBUG: Requesting location permission")
                locationManager.requestLocationPermission()
                
            case .authorizedWhenInUse, .authorizedAlways:
                if let location = locationManager.location {
                    print("DEBUG: Starting initial fetch with existing location")
                    startFetchingWithLocation(location)
                } else {
                    print("DEBUG: Permission granted but no location, requesting update")
                    locationManager.requestOneTimeUpdate()
                }
                
            default:
                break
            }
        }
    }
    
    private func startFetchingWithLocation(_ location: CLLocation) {
        print("DEBUG: Starting fetch with location: \(location)")
        nearbyTrainsManager.startFetching(location: location)
    }
    
    @ViewBuilder
    func AuthorizedView() -> some View {
        if locationManager.isSearchingForLocation {
            ProgressView("Finding your location...")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
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
            // Show empty state but wrapped in a List for pull-to-refresh
            List {
                Section {
                    EmptyStateContent()
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                }
            }
            .listStyle(.plain)
            .refreshable {
                print("DEBUG: Pull to refresh triggered on empty state")
                await performRefreshWithText()
            }
        } else {
            ZStack(alignment: .top) {
                List {
                    // Train data sections
                    ForEach(groupTrainsByStation(), id: \.stationId) { group in
                        Section {
                            ForEach(group.trainsByLineAndDirection, id: \.lineDirectionId) { item in
                                ConsolidatedTrainRow(
                                    primaryTrain: item.trains[0],
                                    additionalTrains: Array(item.trains.dropFirst()),
                                    line: item.line
                                )
                            }
                        } header: {
                            StationHeader(
                                stationDisplay: group.stationDisplay,
                                distanceText: group.distanceText
                            )
                        }
                    }
                }
                .listStyle(.plain)
                .refreshable {
                    print("DEBUG: Pull to refresh triggered on populated list")
                    await performRefreshWithText()
                }
                
                // Overlay text that appears during refresh, positioned right under the spinner
                if nearbyTrainsManager.isLoading {
                    VStack {
                        Text("Loading nearby trains...")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.secondary)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        
                        Spacer()
                    }
                    .animation(.easeInOut(duration: 0.3), value: nearbyTrainsManager.isLoading)
                }
            }
        }
    }

    @MainActor
    private func performRefreshWithText() async {
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
        @State private var currentTime = Date()
        
        private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
        
        var body: some View {
            VStack(alignment: .leading, spacing: 8) {
                // Main row
                HStack(spacing: 12) {
                    // Line badge
                    Text(line.label)
                        .font(.custom("HelveticaNeue-Bold", size: 32))
                        .foregroundColor(line.fg_color)
                        .frame(width: 48, height: 48)
                        .background(Circle().fill(line.bg_color))
                    
                    // Direction
                    VStack(alignment: .leading, spacing: 2) {
                        Text("to \(primaryTrain.destination)")
                            .font(.custom("HelveticaNeue-Bold", size: 20))
                        Text(primaryTrain.direction == "N" ? "Northbound" : "Southbound")
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
                                Text(additionalTrains.prefix(3).map { train in
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
            .onReceive(timer) { time in
                currentTime = time
            }
        }
    }
    
    func groupTrainsByStation() -> [(stationId: String, stationDisplay: String, distanceText: String, trainsByLineAndDirection: [(line: SubwayLine, direction: String, trains: [NearbyTrain], lineDirectionId: String)])] {
        let grouped = Dictionary(grouping: nearbyTrainsManager.nearbyTrains) { $0.stationId }
        
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
            // Sort by distance (closest first)
            let distance1 = $0.trainsByLineAndDirection.first?.trains.first?.distanceInMeters ?? Double.infinity
            let distance2 = $1.trainsByLineAndDirection.first?.trains.first?.distanceInMeters ?? Double.infinity
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

// MARK: - Supporting Views

struct LocationPermissionView: View {
    @EnvironmentObject var locationManager: LocationManager
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "location.fill")
                .font(.system(size: 60))
                .foregroundColor(.blue)
            
            Text("Location Access Required")
                .font(.title2.bold())
            
            Text("We need your location to show nearby trains")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
            
            Button("Allow Location Access") {
                locationManager.requestLocationPermission()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding()
    }
}

struct LocationDeniedView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "location.slash")
                .font(.system(size: 60))
                .foregroundColor(.red)
            
            Text("Location Access Denied")
                .font(.title2.bold())
            
            Text("Please enable location services in Settings")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
            
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
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

struct SubwayLinesData {
    static let allLines = [
        SubwayLine(id: "1", label: "1", bg_color: Color(red: 0.92, green: 0.22, blue: 0.21), fg_color: .white),
        SubwayLine(id: "2", label: "2", bg_color: Color(red: 0.92, green: 0.22, blue: 0.21), fg_color: .white),
        SubwayLine(id: "3", label: "3", bg_color: Color(red: 0.92, green: 0.22, blue: 0.21), fg_color: .white),
        SubwayLine(id: "4", label: "4", bg_color: Color(red: 0.07, green: 0.57, blue: 0.25), fg_color: .white),
        SubwayLine(id: "5", label: "5", bg_color: Color(red: 0.07, green: 0.57, blue: 0.25), fg_color: .white),
        SubwayLine(id: "6", label: "6", bg_color: Color(red: 0.07, green: 0.57, blue: 0.25), fg_color: .white),
        SubwayLine(id: "7", label: "7", bg_color: Color(red: 0.72, green: 0.23, blue: 0.67), fg_color: .white),
        SubwayLine(id: "A", label: "A", bg_color: Color(red: 0.03, green: 0.24, blue: 0.64), fg_color: .white),
        SubwayLine(id: "C", label: "C", bg_color: Color(red: 0.03, green: 0.24, blue: 0.64), fg_color: .white),
        SubwayLine(id: "E", label: "E", bg_color: Color(red: 0.03, green: 0.24, blue: 0.64), fg_color: .white),
        SubwayLine(id: "G", label: "G", bg_color: Color(red: 0.44, green: 0.74, blue: 0.30), fg_color: .white),
        SubwayLine(id: "B", label: "B", bg_color: Color(red: 0.98, green: 0.39, blue: 0.17), fg_color: .white),
        SubwayLine(id: "D", label: "D", bg_color: Color(red: 0.98, green: 0.39, blue: 0.17), fg_color: .white),
        SubwayLine(id: "F", label: "F", bg_color: Color(red: 0.98, green: 0.39, blue: 0.17), fg_color: .white),
        SubwayLine(id: "M", label: "M", bg_color: Color(red: 0.98, green: 0.39, blue: 0.17), fg_color: .white),
        SubwayLine(id: "N", label: "N", bg_color: Color(red: 0.98, green: 0.80, blue: 0.19), fg_color: .black),
        SubwayLine(id: "Q", label: "Q", bg_color: Color(red: 0.98, green: 0.80, blue: 0.19), fg_color: .black),
        SubwayLine(id: "R", label: "R", bg_color: Color(red: 0.98, green: 0.80, blue: 0.19), fg_color: .black),
        SubwayLine(id: "W", label: "W", bg_color: Color(red: 0.98, green: 0.80, blue: 0.19), fg_color: .black),
        SubwayLine(id: "J", label: "J", bg_color: Color(red: 0.60, green: 0.40, blue: 0.22), fg_color: .white),
        SubwayLine(id: "Z", label: "Z", bg_color: Color(red: 0.60, green: 0.40, blue: 0.22), fg_color: .white),
        SubwayLine(id: "L", label: "L", bg_color: Color(red: 0.65, green: 0.66, blue: 0.67), fg_color: .white)
    ]
}

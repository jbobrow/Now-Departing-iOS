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
                
                // Add small delay to avoid initialization issues
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    nearbyTrainsManager.updateStationDataManager(stationDataManager)
                    
                    print("DEBUG: Location enabled: \(locationManager.isLocationEnabled)")
                    print("DEBUG: Authorization status: \(locationManager.authorizationStatus.rawValue)")
                    print("DEBUG: Current location: \(locationManager.location?.description ?? "nil")")
                    
                    // Request permission if not determined
                    if locationManager.authorizationStatus == .notDetermined {
                        print("DEBUG: Requesting location permission")
                        locationManager.requestLocationPermission()
                    } else if locationManager.authorizationStatus == .authorizedWhenInUse && locationManager.location == nil {
                        print("DEBUG: Permission granted but no location, requesting update")
                        locationManager.requestOneTimeUpdate()
                    }
                }
            }
        }
        .onChange(of: locationManager.location) { oldLocation, newLocation in
            print("DEBUG: Location changed from \(oldLocation?.description ?? "nil") to \(newLocation?.description ?? "nil")")
            if let location = newLocation {
                nearbyTrainsManager.startFetching(location: location)
            }
        }
    }
    
    @ViewBuilder
    func AuthorizedView() -> some View {
        if locationManager.isSearchingForLocation {
            ProgressView("Finding your location...")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let error = locationManager.locationError {
            VStack {
                Text("Location Error:")
                Text(error)
            }
        } else if nearbyTrainsManager.isLoading && nearbyTrainsManager.nearbyTrains.isEmpty {
            ProgressView("Loading nearby trains...")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if !nearbyTrainsManager.errorMessage.isEmpty {
            VStack {
                Text("API Error:")
                Text(nearbyTrainsManager.errorMessage)
            }
        } else if nearbyTrainsManager.nearbyTrains.isEmpty {
            VStack {
                Text("No trains found")
                if let location = locationManager.location {
                    Text("Lat: \(location.coordinate.latitude)")
                    Text("Lon: \(location.coordinate.longitude)")
                }
            }
        } else {
            TrainsList()
        }
    }
    @ViewBuilder
    func TrainsList() -> some View {
        List {
            ForEach(groupTrainsByStation(), id: \.stationId) { group in
                Section {
                    // Northbound trains
                    if let northData = group.northbound {
                        ConsolidatedTrainRow(
                            primaryTrain: northData.trains[0],
                            additionalTrains: Array(northData.trains.dropFirst()),
                            line: northData.line
                        )
                    }
                    
                    // Southbound trains
                    if let southData = group.southbound {
                        ConsolidatedTrainRow(
                            primaryTrain: southData.trains[0],
                            additionalTrains: Array(southData.trains.dropFirst()),
                            line: southData.line
                        )
                    }
                } header: {
                    HStack(alignment: .top) {
                        Text(group.stationDisplay)
                            .font(.custom("HelveticaNeue-Bold", size: 26))
                            .foregroundColor(.primary)
                            .textCase(.none)
                            .padding(EdgeInsets(top: 4, leading: 0, bottom: 0, trailing: 0))
                        
                        Spacer()
                        
                        Text(group.distanceText)
                            .font(.custom("HelveticaNeue", size: 14))
                            .foregroundColor(.secondary)
                            .textCase(.none)
                            .padding(EdgeInsets(top: 8, leading: 0, bottom: 0, trailing: 0))
                    }
                    .overlay(
                        Rectangle()
                            .frame(height: 2)
                            .foregroundColor(.primary), // or whatever color you want
                        alignment: .top
                    )
                }
            }
        }
        .listStyle(.plain)
        .refreshable {
            if let location = locationManager.location {
                nearbyTrainsManager.startFetching(location: location)
            }
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
    
    func groupTrainsByStation() -> [(stationId: String, stationDisplay: String, distanceText: String, northbound: (line: SubwayLine, trains: [NearbyTrain])?, southbound: (line: SubwayLine, trains: [NearbyTrain])?)] {
        let grouped = Dictionary(grouping: nearbyTrainsManager.nearbyTrains) { $0.stationId }
        
        return grouped.map { (stationId, trains) in
            let firstTrain = trains.first!
            let distanceText = formatDistance(firstTrain.distanceInMeters)
            
            // Group by direction
            let northTrains = trains.filter { $0.direction == "N" }.sorted { $0.arrivalTime < $1.arrivalTime }
            let southTrains = trains.filter { $0.direction == "S" }.sorted { $0.arrivalTime < $1.arrivalTime }
            
            // Get line info for each direction
            let northData: (line: SubwayLine, trains: [NearbyTrain])? = if !northTrains.isEmpty,
                let line = getLine(for: northTrains[0].lineId) {
                (line: line, trains: northTrains)
            } else {
                nil
            }
            
            let southData: (line: SubwayLine, trains: [NearbyTrain])? = if !southTrains.isEmpty,
                let line = getLine(for: southTrains[0].lineId) {
                (line: line, trains: southTrains)
            } else {
                nil
            }
            
            return (
                stationId: stationId,
                stationDisplay: firstTrain.stationDisplay,
                distanceText: distanceText,
                northbound: northData,
                southbound: southData
            )
        }.sorted { $0.stationDisplay < $1.stationDisplay }
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
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 50))
                .foregroundColor(.orange)
            
            Text(message)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
            
            Button("Try Again", action: retry)
                .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}

struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "tram")
                .font(.system(size: 50))
                .foregroundColor(.gray)
            
            Text("No Nearby Trains")
                .font(.title3.bold())
            
            Text("No trains found within 30 minutes")
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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

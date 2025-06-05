//
//  NearbyView.swift
//  Now Departing
//
//  Created by Jonathan Bobrow on 6/4/25.
//

import SwiftUI
import WatchKit

// New data structures for organized display
struct StationGroup: Identifiable {
    let id = UUID()
    let stationName: String
    let stationDisplay: String
    let distanceInMeters: Double
    let lineGroups: [LineGroup]
    
    var distanceText: String {
        // Convert meters to feet
        let feet = distanceInMeters * 3.28084
        
        if feet < 1000 {
            return "\(Int(feet))ft"
        } else {
            // Convert to miles (5280 feet = 1 mile)
            let miles = feet / 5280
            if miles < 10 {
                return String(format: "%.1fmi", miles)
            } else {
                return "\(Int(miles))mi"
            }
        }
    }
}

struct LineGroup: Identifiable {
    let id = UUID()
    let lineId: String
    let northbound: NearbyTrain?
    let southbound: NearbyTrain?
}

struct NearbyView: View {
    @StateObject private var nearbyTrainsManager = NearbyTrainsManager()
    @EnvironmentObject var locationManager: LocationManager
    @State private var hasAppeared = false
    
    let onSelect: (SubwayLine, Station, String) -> Void
    let lines: [SubwayLine]
    
    private func getLine(for id: String) -> SubwayLine? {
        return lines.first(where: { $0.id == id })
    }
    
    // Organize trains into station groups with line groupings
    private var stationGroups: [StationGroup] {
        // Group trains by station
        let trainsByStation = Dictionary(grouping: nearbyTrainsManager.nearbyTrains) { train in
            train.stationName
        }
        
        // Convert to StationGroup objects
        let groups = trainsByStation.map { (stationName, trains) -> StationGroup in
            // Get station info from first train
            let firstTrain = trains.first!
            
            // Group trains by line within this station
            let trainsByLine = Dictionary(grouping: trains) { train in
                train.lineId
            }
            
            // Create LineGroup objects
            let lineGroups = trainsByLine.map { (lineId, lineTrains) -> LineGroup in
                // Find the closest northbound and southbound trains for this line
                let northbound = lineTrains
                    .filter { $0.direction == "N" }
                    .min { $0.minutes < $1.minutes }
                
                let southbound = lineTrains
                    .filter { $0.direction == "S" }
                    .min { $0.minutes < $1.minutes }
                
                return LineGroup(
                    lineId: lineId,
                    northbound: northbound,
                    southbound: southbound
                )
            }
            .filter { $0.northbound != nil || $0.southbound != nil } // Only include lines with at least one direction
            .sorted { group1, group2 in
                // Sort lines alphabetically
                group1.lineId < group2.lineId
            }
            
            return StationGroup(
                stationName: stationName,
                stationDisplay: firstTrain.stationDisplay,
                distanceInMeters: firstTrain.distanceInMeters,
                lineGroups: lineGroups
            )
        }
        
        // Sort stations by distance
        return groups.sorted { $0.distanceInMeters < $1.distanceInMeters }
    }
    
    var body: some View {
        Group {
            switch locationManager.authorizationStatus {
            case .notDetermined:
                VStack(spacing: 8) {
                    Image(systemName: "location")
                        .foregroundColor(.white)
                        .font(.title2)
                    Text("Enable Location")
                        .font(.headline)
                        .foregroundColor(.white)
                    Text("See nearby train times")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                    Button("Allow Location") {
                        locationManager.requestLocationPermission()
                    }
                    .buttonStyle(.borderedProminent)
                    .font(.caption)
                }
                .padding()
                
            case .denied, .restricted:
                VStack(spacing: 8) {
                    Image(systemName: "location.slash")
                        .foregroundColor(.red)
                        .font(.title2)
                    Text("Location Disabled")
                        .font(.headline)
                        .foregroundColor(.white)
                    Text("Enable location in Settings to see nearby trains")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                }
                .padding()
                
            case .authorizedWhenInUse, .authorizedAlways:
                if locationManager.isSearchingForLocation {
                    VStack(spacing: 8) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        Text("Finding your location...")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                } else if let locationError = locationManager.locationError {
                    VStack(spacing: 8) {
                        Image(systemName: "location.slash")
                            .foregroundColor(.orange)
                            .font(.title2)
                        Text("Location Error")
                            .font(.headline)
                            .foregroundColor(.white)
                        Text(locationError)
                            .font(.caption)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                        
                        Button("Try Again") {
                            locationManager.retryLocation()
                        }
                        .buttonStyle(.borderedProminent)
                        .font(.caption)
                    }
                    .padding()
                } else if nearbyTrainsManager.isLoading && nearbyTrainsManager.nearbyTrains.isEmpty {
                    VStack(spacing: 8) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        Text("Finding nearby trains...")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                } else if !nearbyTrainsManager.errorMessage.isEmpty && nearbyTrainsManager.nearbyTrains.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle")
                            .foregroundColor(.orange)
                            .font(.title2)
                        Text(nearbyTrainsManager.errorMessage)
                            .font(.caption)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                        
                        Button("Retry") {
                            if let location = locationManager.location {
                                nearbyTrainsManager.startFetching(location: location)
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .font(.caption)
                    }
                    .padding()
                } else if stationGroups.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "tram")
                            .foregroundColor(.gray)
                            .font(.title2)
                        Text("No Nearby Trains")
                            .font(.headline)
                            .foregroundColor(.white)
                        Text("No trains found in your area")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                } else {
                    List {
                        ForEach(stationGroups) { stationGroup in
                            Section {
                                ForEach(stationGroup.lineGroups) { lineGroup in
                                    if let line = getLine(for: lineGroup.lineId) {
                                        VStack(spacing: 8) {
                                            // Northbound train if available
                                            if let northTrain = lineGroup.northbound {
                                                TrainRowView(
                                                    line: line,
                                                    train: northTrain,
                                                    onSelect: onSelect
                                                )
                                            }
                                            
                                            // Southbound train if available
                                            if let southTrain = lineGroup.southbound {
                                                TrainRowView(
                                                    line: line,
                                                    train: southTrain,
                                                    onSelect: onSelect
                                                )
                                            }
                                        }
                                        .listRowInsets(EdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8))
                                    }
                                }
                            }
                            header: {
                                HStack(alignment: .top) {
                                    Text(stationGroup.stationDisplay)
                                        .font(.custom("HelveticaNeue-Bold", size: 16))
                                        .foregroundColor(.white)
                                        .textCase(.none)
                                    
                                    Spacer()
                                    
                                    Text(stationGroup.distanceText)
                                        .font(.custom("HelveticaNeue", size: 12))
                                        .foregroundColor(.gray)
                                        .textCase(.none)
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .overlay(
                                    Rectangle()
                                        .frame(height: 1)
                                        .foregroundColor(.white),
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
                
            @unknown default:
                EmptyView()
            }
        }
        .onAppear {
            guard !hasAppeared else { return }
            hasAppeared = true
            print("DEBUG: NearbyView appeared for first time")
            
            if locationManager.isLocationEnabled, let location = locationManager.location {
                print("DEBUG: Starting fetch with location: \(location)")
                nearbyTrainsManager.startFetching(location: location)
            } else {
                print("DEBUG: Location not available - enabled: \(locationManager.isLocationEnabled), location: \(locationManager.location?.description ?? "nil")")
            }
        }
        .onChange(of: locationManager.location) { oldLocation, newLocation in
            guard hasAppeared else { return }
            print("DEBUG: Location changed from \(oldLocation?.description ?? "nil") to \(newLocation?.description ?? "nil")")
            if let location = newLocation {
                nearbyTrainsManager.startFetching(location: location)
            }
        }
        .onChange(of: locationManager.isLocationEnabled) { wasEnabled, isEnabled in
            guard hasAppeared else { return }
            print("DEBUG: Location enabled changed from \(wasEnabled) to \(isEnabled)")
            if isEnabled, let location = locationManager.location {
                nearbyTrainsManager.startFetching(location: location)
            } else if !isEnabled {
                nearbyTrainsManager.stopFetching()
            }
        }
    }
}

// Individual train row component
struct TrainRowView: View {
    let line: SubwayLine
    let train: NearbyTrain
    let onSelect: (SubwayLine, Station, String) -> Void
    
    var body: some View {
        Button(action: {
            // Trigger haptic feedback
            WKInterfaceDevice.current().play(.start)
            
            let station = Station(display: train.stationDisplay, name: train.stationName)
            onSelect(line, station, train.direction)
        }) {
            HStack(spacing: 8) {
                // Train line circle
                Text(line.label)
                    .font(.custom("HelveticaNeue-Bold", size: 16))
                    .foregroundColor(line.fg_color)
                    .frame(width: 24, height: 24)
                    .background(Circle().fill(line.bg_color))
                
                // Direction info
                Text("to \(train.destination)")
                    .font(.custom("HelveticaNeue", size: 12))
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                Spacer()
                
                // Time display
                Text(train.timeText)
                    .font(.custom("HelveticaNeue-Bold", size: 14))
                    .foregroundColor(.white)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}

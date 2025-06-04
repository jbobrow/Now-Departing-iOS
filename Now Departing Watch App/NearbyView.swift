//
//  NearbyView.swift
//  Now Departing
//
//  Created by Jonathan Bobrow on 6/4/25.
//

import SwiftUI
import WatchKit

struct NearbyView: View {
    @StateObject private var nearbyTrainsManager = NearbyTrainsManager()
    @EnvironmentObject var locationManager: LocationManager
    @State private var hasAppeared = false
    
    let onSelect: (SubwayLine, Station, String) -> Void
    let lines: [SubwayLine]
    
    private func getLine(for id: String) -> SubwayLine? {
        return lines.first(where: { $0.id == id })
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
                } else if nearbyTrainsManager.nearbyTrains.isEmpty {
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
                    List(nearbyTrainsManager.nearbyTrains) { train in
                        if let line = getLine(for: train.lineId) {
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
                                        .frame(width: 26, height: 26)
                                        .background(Circle().fill(line.bg_color))
                                    
                                    // Station and destination info
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(train.stationDisplay)
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundColor(.white)
                                            .lineLimit(1)
                                        
                                        Text("to \(train.destination)")
                                            .font(.system(size: 11))
                                            .foregroundColor(.gray)
                                            .lineLimit(1)
                                    }
                                    
                                    Spacer()
                                    
                                    // Time and distance display
                                    VStack(alignment: .trailing, spacing: 2) {
                                        Text(train.timeText)
                                            .font(.system(size: 16, weight: .bold))
                                            .foregroundColor(train.minutes <= 1 ? .orange : .white)
                                        
                                        Text(train.distanceText)
                                            .font(.system(size: 10))
                                            .foregroundColor(.gray)
                                    }
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(PlainButtonStyle())
                            .listRowInsets(EdgeInsets(top: 6, leading: 8, bottom: 6, trailing: 8))
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

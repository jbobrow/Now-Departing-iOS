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
    let stationId: String
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

// ObservableObject wrapper for individual trains to handle loading state
class NearbyTrainWithState: ObservableObject, Identifiable {
    let id = UUID()
    let train: NearbyTrain
    @Published var isWaitingToStart = true
    @Published var hasAppeared = false
    
    var shouldShowLoader: Bool {
        return isWaitingToStart && hasAppeared
    }
    
    init(train: NearbyTrain) {
        self.train = train
    }
    
    func startDisplaying(delay: Double = 0.3) {
        hasAppeared = true
        
        if delay > 0 {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                self?.isWaitingToStart = false
            }
        } else {
            isWaitingToStart = false
        }
    }
}

struct NearbyView: View {
    @EnvironmentObject var locationManager: LocationManager
    @EnvironmentObject var stationDataManager: StationDataManager
    @StateObject private var nearbyTrainsManager = NearbyTrainsManager(stationDataManager: StationDataManager())
    @State private var hasAppeared = false
    @State private var isInitialized = false
    @State private var trainsWithState: [NearbyTrainWithState] = []
    
    let onSelect: (SubwayLine, Station, String) -> Void
    let lines: [SubwayLine]
    
    private func getLine(for id: String) -> SubwayLine? {
        return lines.first(where: { $0.id == id })
    }
    
    // Update trainsWithState when nearbyTrains changes
    private func updateTrainsWithState() {
        // Create new NearbyTrainWithState objects for current trains
        trainsWithState = nearbyTrainsManager.nearbyTrains.enumerated().map { index, train in
            let trainWithState = NearbyTrainWithState(train: train)
            
            // Add a small delay to stagger the appearance of trains
            let delay = Double(index) * 0.1 // 100ms apart
            trainWithState.startDisplaying(delay: delay)
            
            return trainWithState
        }
    }
    
    // Organize trains into station groups with line groupings - now grouped by station ID
    private var stationGroups: [StationGroup] {
        // Group trains by station ID instead of station name
        let trainsByStationId = Dictionary(grouping: trainsWithState) { trainWithState in
            trainWithState.train.stationId
        }
        
        // Convert to StationGroup objects
        let groups = trainsByStationId.map { (stationId, trainsWithState) -> StationGroup in
            // Get station info from first train
            let firstTrain = trainsWithState.first!.train
            
            // Group trains by line within this station
            let trainsByLine = Dictionary(grouping: trainsWithState) { trainWithState in
                trainWithState.train.lineId
            }
            
            // Create LineGroup objects
            let lineGroups = trainsByLine.map { (lineId, lineTrainsWithState) -> LineGroup in
                // Find the closest northbound and southbound trains for this line
                let northbound = lineTrainsWithState
                    .filter { $0.train.direction == "N" }
                    .min { $0.train.arrivalTime < $1.train.arrivalTime }?.train
                
                let southbound = lineTrainsWithState
                    .filter { $0.train.direction == "S" }
                    .min { $0.train.arrivalTime < $1.train.arrivalTime }?.train
                
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
                stationId: stationId,
                stationName: firstTrain.stationName,
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
                locationNotDeterminedView
                
            case .denied, .restricted:
                locationDeniedView
                
            case .authorizedWhenInUse, .authorizedAlways:
                authorizedLocationView
                
            @unknown default:
                EmptyView()
            }
        }
        .onAppear {
            guard !hasAppeared else { return }
            hasAppeared = true
            print("DEBUG: NearbyView appeared for first time")
            
            // Reinitialize the manager with the real stationDataManager
            if !isInitialized {
                nearbyTrainsManager.updateStationDataManager(stationDataManager)
                isInitialized = true
            }
            
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
        .onChange(of: nearbyTrainsManager.nearbyTrains) { _, _ in
            updateTrainsWithState()
        }
    }
    
    // MARK: - View Components
    
    private var locationNotDeterminedView: some View {
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
    }
    
    private var locationDeniedView: some View {
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
    }
    
    private var authorizedLocationView: some View {
        Group {
            if locationManager.isSearchingForLocation {
                searchingLocationView
            } else if let locationError = locationManager.locationError {
                locationErrorView(error: locationError)
            } else if nearbyTrainsManager.isLoading && nearbyTrainsManager.nearbyTrains.isEmpty {
                loadingTrainsView
            } else if !nearbyTrainsManager.errorMessage.isEmpty && nearbyTrainsManager.nearbyTrains.isEmpty {
                trainsErrorView
            } else if stationGroups.isEmpty {
                noTrainsView
            } else {
                trainsListView
            }
        }
    }
    
    private var searchingLocationView: some View {
        VStack(spacing: 8) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .white))
            Text("Finding your location...")
                .font(.caption)
                .foregroundColor(.gray)
        }
    }
    
    private func locationErrorView(error: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: "location.slash")
                .foregroundColor(.orange)
                .font(.title2)
            Text("Location Error")
                .font(.headline)
                .foregroundColor(.white)
            Text(error)
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
    }
    
    private var loadingTrainsView: some View {
        VStack(spacing: 8) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .white))
            Text("Finding nearby trains...")
                .font(.caption)
                .foregroundColor(.gray)
        }
    }
    
    private var trainsErrorView: some View {
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
    }
    
    private var noTrainsView: some View {
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
    }
    
    private var trainsListView: some View {
        List {
            ForEach(stationGroups) { stationGroup in
                stationSection(for: stationGroup)
            }
        }
        .listStyle(.plain)
        .refreshable {
            if let location = locationManager.location {
                nearbyTrainsManager.startFetching(location: location)
            }
        }
    }
    
    private func stationSection(for stationGroup: StationGroup) -> some View {
        Section {
            ForEach(stationGroup.lineGroups) { lineGroup in
                lineGroupView(lineGroup: lineGroup)
            }
        } header: {
            stationHeaderView(for: stationGroup)
        }
    }
    
    private func lineGroupView(lineGroup: LineGroup) -> some View {
        Group {
            if let line = getLine(for: lineGroup.lineId) {
                // Northbound train if available
                if let northTrain = lineGroup.northbound {
                    if let trainWithState = trainsWithState.first(where: { $0.train.id == northTrain.id }) {
                        trainRowView(line: line, trainWithState: trainWithState)
                    }
                }
                
                // Southbound train if available
                if let southTrain = lineGroup.southbound {
                    if let trainWithState = trainsWithState.first(where: { $0.train.id == southTrain.id }) {
                        trainRowView(line: line, trainWithState: trainWithState)
                    }
                }
            }
        }
    }
    
    private func trainRowView(line: SubwayLine, trainWithState: NearbyTrainWithState) -> some View {
        TrainRowView(
            line: line,
            trainWithState: trainWithState,
            onSelect: onSelect
        )
        .listRowInsets(EdgeInsets(top: 6, leading: 8, bottom: 6, trailing: 8))
        .id("train-\(trainWithState.train.lineId)-\(trainWithState.train.stationId)-\(trainWithState.train.direction)")
    }
    
    private func stationHeaderView(for stationGroup: StationGroup) -> some View {
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
                .foregroundColor(.white), // or whatever color you want
            alignment: .top
        )
    }
}

// Individual train row component - now uses NearbyTrainWithState
struct TrainRowView: View {
    let line: SubwayLine
    @ObservedObject var trainWithState: NearbyTrainWithState
    let onSelect: (SubwayLine, Station, String) -> Void
    
    var body: some View {
        Button(action: {
            // Trigger haptic feedback
            WKInterfaceDevice.current().play(.start)
            
            let station = Station(display: trainWithState.train.stationDisplay, name: trainWithState.train.stationName)
            onSelect(line, station, trainWithState.train.direction)
        }) {
            HStack(spacing: 8) {
                // Train line circle
                Text(line.label)
                    .font(.custom("HelveticaNeue-Bold", size: 20))
                    .foregroundColor(line.fg_color)
                    .frame(width: 30, height: 30)
                    .background(Circle().fill(line.bg_color))
                
                // Direction info
                Text("to \(trainWithState.train.destination)")
                    .font(.custom("HelveticaNeue", size: 14))
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                Spacer()
                
                // Time display with loading state like FavoritesView
                VStack(alignment: .trailing, spacing: 2) {
                    if trainWithState.shouldShowLoader {
                        ProgressView()
                            .scaleEffect(1.2)
                    } else {
                        LiveTimeDisplay(train: trainWithState.train)
                    }
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// Separate component for live time display with its own timer
struct LiveTimeDisplay: View {
    let train: NearbyTrain
    
    @State private var displayedTimeText: String = ""
    @State private var currentTime = Date()
    @State private var hasInitialized = false
    
    // Timer for this specific component only
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    private var currentTimeText: String {
        return train.getLiveTimeText(currentTime: currentTime)
    }
    
    var body: some View {
        Text(displayedTimeText)
            .font(.custom("HelveticaNeue-Bold", size: displayedTimeText.count < 5 ? 20 : 16))
            .foregroundColor(.white)
            .animation(hasInitialized ? .easeInOut(duration: 0.3) : .none, value: displayedTimeText)
            .onAppear {
                currentTime = Date()
                displayedTimeText = currentTimeText
                // Small delay to prevent animation on initial appearance
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    hasInitialized = true
                }
            }
            .onReceive(timer) { time in
                currentTime = time
                let newTimeText = currentTimeText
                // Only update when the displayed text actually changes
                if newTimeText != displayedTimeText {
                    displayedTimeText = newTimeText
                }
            }
    }
}

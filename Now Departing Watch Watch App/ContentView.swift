//
//  ContentView.swift
//  Now Departing WatchOS App
//
//  Created by Jonathan Bobrow on 12/29/24.
//

import SwiftUI
import Combine
import WatchKit

// MARK: - Models
// Note: SubwayLine, Station, APIResponse, StationData, Train are now imported from SharedModels.swift
// Note: NavigationState is now imported from NavigationModels.swift

struct TrainData: Decodable {
    let station: String
    let arrivalTimes: [Int]

    private enum CodingKeys: String, CodingKey {
        case station
        case arrivalTimes = "times"
    }
}

// Main App Views
struct ContentView: View {
    @EnvironmentObject var stationDataManager: StationDataManager
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject var settingsManager: SettingsManager
    @StateObject private var navigationState = NavigationState()
    @StateObject private var favoritesManager = FavoritesManager()
    @StateObject private var locationManager = LocationManager()
    @State private var showSettings = false
    @State private var selectedTab = 0

    // Use shared subway line factory
    let lines = SubwayLineFactory.allLines
    
    private func scheduleNextBackgroundRefresh() {
        let refreshDate = Date().addingTimeInterval(15 * 60) // 15 minutes
        WKExtension.shared().scheduleBackgroundRefresh(withPreferredDate: refreshDate, userInfo: nil) { error in
            if let error = error {
                print("Failed to schedule background refresh: \(error)")
            }
        }
    }
    
    var body: some View {
        NavigationStack(path: $navigationState.path) {
            TabView(selection: $selectedTab) {
                // Nearby Trains View (new - leftmost)
                NearbyView(
                    onSelect: { line, station, direction in
                        // Trigger haptic feedback
                        WKInterfaceDevice.current().play(.start)

                        navigationState.line = line
                        navigationState.station = station
                        navigationState.terminal = station
                        navigationState.direction = direction
                        DispatchQueue.main.async {
                            navigationState.path.append("times")
                        }
                    },
                    lines: lines
                )
                .environmentObject(locationManager)
                .tag(0)
                
                // Lines Grid View (moved to middle)
                LineSelectionView(
                    lines: lines,
                    onSelect: { line in
                        navigationState.line = line
                        DispatchQueue.main.async {
                            navigationState.path.append("stations")
                        }
                    },
                    onSettings: {
                        showSettings = true
                    }
                )
                .tag(1)
                
                // Favorites View (rightmost)
                FavoritesView(
                    onSelect: { line, station, direction in
                        
                        // Trigger haptic feedback
                        WKInterfaceDevice.current().play(.start)

                        navigationState.line = line
                        navigationState.station = station
                        navigationState.terminal = station
                        navigationState.direction = direction
                        DispatchQueue.main.async {
                            navigationState.path.append("times")
                        }
                    },
                    lines: lines
                )
                .tag(2)
            }
            .tabViewStyle(.page)
            .navigationDestination(for: String.self) { route in
                switch route {
                case "stations":
                    if case .loading = stationDataManager.loadingState {
                        ProgressView()
                    } else if let line = navigationState.line {
                        StationSelectionView(line: line, onSelect: { station in
                            navigationState.station = station
                            DispatchQueue.main.async {
                                navigationState.path.append("terminals")
                            }
                        })
                        .onAppear {
                            // Load stations specifically for this line
                            stationDataManager.loadStationsForLine(line.id)
                        }
                    } else {
                        ProgressView()
                            .task {
                                stationDataManager.loadStations()
                            }
                    }
                    
                case "terminals":
                    if case .loading = stationDataManager.loadingState {
                        ProgressView()
                    } else if let line = navigationState.line,
                              let stations = stationDataManager.stations(for: line.id) {
                        TerminalSelectionView(line: line, stations: stations, onSelect: { terminal, direction in
                            navigationState.terminal = terminal
                            navigationState.direction = direction
                            DispatchQueue.main.async {
                                navigationState.path.append("times")
                            }
                        })
                    } else {
                        ProgressView()
                            .task {
                                stationDataManager.loadStations()
                            }
                    }
                    
                case "times":
                    if case .loading = stationDataManager.loadingState {
                        ProgressView()
                    } else if let line = navigationState.line,
                              let station = navigationState.station,
                              let direction = navigationState.direction {
                        let viewModel = TimesViewModel()
                        TimesView(viewModel: viewModel, line: line, station: station, direction: direction)
                    } else {
                        ProgressView()
                            .task {
                                stationDataManager.loadStations()
                            }
                    }
                    
                default:
                    EmptyView()
                }
            }
            .sheet(isPresented: $showSettings) {
                NavigationStack {
                    SettingsView()
                        .environmentObject(settingsManager)
                }
            }
        }
        .environmentObject(navigationState)
        .environmentObject(favoritesManager)
        .onChange(of: selectedTab) { oldTab, newTab in
            if newTab == 0 { // Nearby tab
                // User swiped to location tab - request fresh location and start updates
                locationManager.startLocationUpdates()
            } else if oldTab == 0 {
                // User swiped away from location tab - stop continuous updates
                locationManager.stopLocationUpdates()
            }
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            // print("DEBUG: Scene phase changed from \(oldPhase) to \(newPhase)")
            switch newPhase {
            case .active:
                stationDataManager.refreshStations()
                scheduleNextBackgroundRefresh()
                // If on nearby tab, restart location updates with a small delay to ensure proper state
                if selectedTab == 0 {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        locationManager.startLocationUpdates()
                    }
                }
            case .background:
                // Stop location updates to save battery
                locationManager.stopLocationUpdates()
                break
            case .inactive:
                // Don't stop location on inactive - this happens during transitions
                break
            @unknown default:
                break
            }
        }
        .onAppear {
            // If starting on nearby tab, begin location updates
            if selectedTab == 0 {
                locationManager.startLocationUpdates()
            }
        }
    }
}

struct LineSelectionView: View {
    let lines: [SubwayLine]
    let onSelect: (SubwayLine) -> Void
    let onSettings: () -> Void
    @State private var pressedLineId: String? = nil
    @State private var selectedLineId: String? = nil
    
    var body: some View {
        GeometryReader { geometry in
            let isSmallScreen = geometry.size.width < 165
            let spacing: CGFloat = 4  // Fixed spacing for all screen sizes
            let columnCount = 4
            
            // Fixed button sizes based on screen size
            let buttonSize: CGFloat = isSmallScreen ? 34 : 38
            
            // Calculate the fixed grid width
            let gridWidth = buttonSize * CGFloat(columnCount) + spacing * CGFloat(columnCount - 1)
            
            // Center the grid in the available space
            let horizontalPadding = (geometry.size.width - gridWidth) / 2
            
            ScrollView {
                VStack(spacing: 0) {
                    // Create rows based on our column count
                    ForEach(0..<(lines.count + columnCount - 1) / columnCount, id: \.self) { rowIndex in
                        ZStack(alignment: .topLeading) {
                            HStack(spacing: spacing) {
                                ForEach(0..<columnCount, id: \.self) { columnIndex in
                                    let index = rowIndex * columnCount + columnIndex
                                    if index < lines.count {
                                        Color.clear
                                            .frame(width: buttonSize, height: buttonSize)
                                    } else {
                                        Color.clear
                                            .frame(width: 0, height: 0)
                                    }
                                }
                            }
                            
                            // Position buttons
                            ForEach(0..<columnCount, id: \.self) { columnIndex in
                                let index = rowIndex * columnCount + columnIndex
                                if index < lines.count {
                                    let line = lines[index]
                                    let xPos = CGFloat(columnIndex) * (buttonSize + spacing)
                                    
                                    if line.id == "X" {
                                        Button(action: onSettings) {
                                            Image(systemName: "gear")
                                                .foregroundColor(.black)
                                                .frame(width: buttonSize, height: buttonSize)
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                        .position(x: xPos + buttonSize/2, y: buttonSize/2)
                                    } else {
                                        ZStack {
                                            // Normal state button (always visible)
                                            Button(action: {
                                                // Trigger haptic feedback
                                                WKInterfaceDevice.current().play(.start)
                                                
                                                selectedLineId = line.id
                                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                                    selectedLineId = nil
                                                    pressedLineId = nil
                                                    onSelect(line)
                                                }
                                            }) {
                                                Text(line.label)
                                                    .font(.custom("HelveticaNeue-Bold", size: isSmallScreen ? 22 : 26))
                                                    .foregroundColor(line.fg_color)
                                                    .frame(width: buttonSize, height: buttonSize)
                                                    .background(Circle().fill(line.bg_color))
                                                    .scaleEffect(2.0) // Draw at 2x size
                                                    .scaleEffect(0.5) // Scale down to 50% normally
                                            }
                                            .buttonStyle(PlainButtonStyle())
                                            .opacity((pressedLineId == line.id || selectedLineId == line.id) ? 0 : 1)
                                            
                                            // Pressed state button (only visible when pressed)
                                            if pressedLineId == line.id || selectedLineId == line.id {
                                                Text(line.label)
                                                    .font(.custom("HelveticaNeue-Bold", size: isSmallScreen ? 44 : 52)) // Double the font size
                                                    .foregroundColor(line.fg_color)
                                                    .frame(width: buttonSize * 2, height: buttonSize * 2) // Double the frame size
                                                    .background(
                                                        Circle()
                                                            .fill(line.bg_color)
                                                            .shadow(color: .black.opacity(0.6), radius: 10)
                                                    )
                                            }
                                        }
                                        .position(x: xPos + buttonSize/2, y: buttonSize/2)
                                        .offset(y: (pressedLineId == line.id || selectedLineId == line.id) ? -40 : 0)
                                        .zIndex(pressedLineId == line.id || selectedLineId == line.id ? 10 : 0)
                                        .animation(
                                            (pressedLineId == line.id || selectedLineId == line.id) ?
                                                .spring(response: 0.15, dampingFraction: 0.6, blendDuration: 0.1) :
                                                .spring(response: 0.3, dampingFraction: 0.6, blendDuration: 0.1),
                                            value: pressedLineId == line.id || selectedLineId == line.id
                                        )
                                        .onLongPressGesture(minimumDuration: .infinity, maximumDistance: .infinity,
                                            pressing: { isPressing in
                                                if isPressing && pressedLineId != line.id {
                                                    // Trigger haptic feedback when long press starts
                                                    WKInterfaceDevice.current().play(.start)
                                                }
                                                withAnimation(.spring(response: 0, dampingFraction: 0.4, blendDuration: 0)) {
                                                    pressedLineId = isPressing ? line.id : nil
                                                }
                                            }, perform: { }
                                        )
                                    }
                                }
                            }
                        }
                        .frame(height: buttonSize)
                        .padding(.bottom, spacing) // Use the fixed spacing here too
                    }
                }
                .padding(.horizontal, horizontalPadding) // Use calculated padding to center the grid
            }
        }
        .onDisappear {
            pressedLineId = nil
            selectedLineId = nil
        }
    }
}

struct StationSelectionView: View {
    let line: SubwayLine
    let onSelect: (Station) -> Void
    @EnvironmentObject var dataManager: StationDataManager
    
    var body: some View {
        Group {
            switch dataManager.loadingState {
            case .loading:
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle())
            case .error(let message):
                Text(message)
                    .foregroundColor(.red)
            case .loaded:
                if let stations = dataManager.stations(for: line.id) {
                    List(stations) { station in
                        Button(action: {
                            // Trigger haptic feedback
                            WKInterfaceDevice.current().play(.start)

                            onSelect(station) }) {
                            HStack {
                                if station.hasAvailableTimes == false {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundColor(Color(red: 0.6, green: 0.6, blue: 0.6))
                                    Text(station.display)
                                        .font(.custom("HelveticaNeue-Bold", size: 16))
                                        .foregroundColor(Color(red: 0.6, green: 0.6, blue: 0.6))
                                }
                                else {
                                    Text(station.display)
                                        .font(.custom("HelveticaNeue-Bold", size: 16))
                                        .foregroundColor(.white)
                                }
                                Spacer()
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            case .idle:
                Color.clear.onAppear { dataManager.loadStations() }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .automatic) {
                HStack {
                    Text(line.label)
                        .font(.custom("HelveticaNeue-Bold", size: 20))
                        .foregroundColor(line.fg_color)
                        .frame(width: 30, height: 30)
                        .background(Circle().fill(line.bg_color))
                    Text("Select a station")
                        .font(.custom("HelveticaNeue-Bold", size: 16))
                }
            }
        }
    }
}

struct TerminalSelectionView: View {
    let line: SubwayLine
    let stations: [Station]
    let onSelect: (Station, String) -> Void  // Updated to include direction
    
    var terminals: [(station: Station, direction: String, description: String)] {
        guard stations.count > 1 else {
            // If only one station, still provide both directions if available
            if let station = stations.first {
                return [
                    (station: station, direction: "N", description: DirectionHelper.getToDestination(for: line.id, direction: "N")),
                    (station: station, direction: "S", description: DirectionHelper.getToDestination(for: line.id, direction: "S"))
                ]
            }
            return []
        }
        
        // Use first and last stations as terminals
        let terminals: [(station: Station, direction: String, description: String)] = [
            (station: stations.first!, direction: "N", description: DirectionHelper.getToDestination(for: line.id, direction: "N")),
            (station: stations.last!, direction: "S", description: DirectionHelper.getToDestination(for: line.id, direction: "S"))
        ]
        
        return terminals
    }
    
    var body: some View {
        List(terminals, id: \.station.id) { terminal in
            Button(action: {
                // Trigger haptic feedback
                WKInterfaceDevice.current().play(.start)
                
                onSelect(terminal.station, terminal.direction)
            }) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(terminal.station.display)
                        .font(.custom("HelveticaNeue-Bold", size: 16))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.leading)
                    
                    Text(terminal.description)
                        .font(.custom("HelveticaNeue", size: 14))
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .listStyle(.plain)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .automatic) {
                HStack {
                    Text(line.label)
                        .font(.custom("HelveticaNeue-Bold", size: 20))
                        .foregroundColor(line.fg_color)
                        .frame(width: 30, height: 30)
                        .background(Circle().fill(line.bg_color))
                    Text("Select direction")
                        .font(.custom("HelveticaNeue-Bold", size: 16))
                }
            }
        }
    }
}

// MARK: - Separate View Components

// Simple container for train time data
struct TrainTime: Equatable, Hashable {
    let minutes: Int
    let seconds: Int
}

// View for displaying a subway line circle
struct LineCircleView: View {
    let line: SubwayLine
    let isSmallScreen: Bool
    
    var body: some View {
        Text(line.label)
            .font(.custom("HelveticaNeue-Bold", size: isSmallScreen ? 48 : 60))
            .foregroundColor(line.fg_color)
            .frame(width: isSmallScreen ? 80 : 100, height: isSmallScreen ? 80 : 100)
            .background(Circle().fill(line.bg_color))
            .padding(.bottom, isSmallScreen ? 2 : 4)
    }
}

// View for displaying an error message
struct ErrorView: View {
    let message: String
    let isSmallScreen: Bool
    
    var body: some View {
        Text(message)
            .font(.custom("HelveticaNeue-Bold", size: 14))
            .foregroundColor(.red)
            .padding(.vertical, isSmallScreen ? 4 : 8)
            .multilineTextAlignment(.center)
            .transition(.opacity.combined(with: .scale))
    }
}

// View for displaying a loading message
struct LoadingView: View {
    let isSmallScreen: Bool
    
    var body: some View {
        Text("Loading...")
            .font(.custom("HelveticaNeue-Bold", size: isSmallScreen ? 18 : 20))
            .foregroundColor(Color(red: 0.6, green: 0.6, blue: 0.6))
            .transition(.opacity)
    }
}

// View for displaying the primary train time
struct PrimaryTrainView: View {
    let train: TrainTime
    let isSmallScreen: Bool
    let showPreciseMode: Bool
    
    private var text: String {
        let totalSeconds = train.minutes * 60 + train.seconds
        
        if showPreciseMode {
            // Precise mode with minutes and seconds
            if train.minutes > 0 {
                return "\(train.minutes)m\(train.seconds)s"
            }
            else {
                return "\(train.seconds)s"
            }
        } else {
            if totalSeconds == 0 {
                return "Departing"
            } else if totalSeconds <= 30 {
                // Final 20 seconds - "Departing"
                return "Departing"
            } else if totalSeconds < 60 {
                // Under 60 seconds but more than 20 - "Arriving"
                return "Arriving"
            } else {
                // Standard mode - just minutes
                return "\(train.minutes) min"
            }
        }
    }
    
    private var fontSize: CGFloat {
        let totalSeconds = train.minutes * 60 + train.seconds
        let isSpecialState = totalSeconds < 60 // "Arriving" or "Departing"
        
        if isSpecialState {
            return isSmallScreen ? 24 : 28
        } else {
            return isSmallScreen ? 28 : 32
        }
    }
    
    var body: some View {
        Text(text)
            .font(.custom("HelveticaNeue-Bold", size: fontSize))
            .foregroundColor(.white)
            .transition(.opacity.combined(with: .scale))
            .id("primaryTime-\(text)")
    }
}

// View for displaying additional train times
struct AdditionalTrainsView: View {
    let trains: [TrainTime]
    let showPreciseMode: Bool
    
    private var text: String {
        return trains.prefix(3).map { train -> String in
            let totalSeconds = train.minutes * 60 + train.seconds
            
            if totalSeconds < 60 {
                if totalSeconds <= 20 {
                    return "Departing"
                } else {
                    return "Arriving"
                }
            } else if showPreciseMode {
                return "\(train.minutes)m\(train.seconds)s"
            } else {
                return "\(train.minutes) min"
            }
        }.joined(separator: ", ")
    }
    
    private var idString: String {
        return trains.prefix(3).map { "\($0.minutes)-\($0.seconds)" }.joined()
    }
    
    var body: some View {
        Text(text)
            .font(.custom("HelveticaNeue-Bold", size: 14))
            .foregroundColor(Color(red: 0.6, green: 0.6, blue: 0.6))
            .lineLimit(1)
            .truncationMode(.tail)
            .transition(.opacity.combined(with: .scale))
            .id("secondaryTimes-\(idString)")
    }
}

// View for displaying the station name
struct StationNameView: View {
    let stationName: String
    let isSmallScreen: Bool
    
    var body: some View {
        Text(stationName)
            .font(.custom("HelveticaNeue-Medium", size: isSmallScreen ? 18 : 20))
            .foregroundColor(.white)
            .multilineTextAlignment(.center)
            .padding(.horizontal, isSmallScreen ? 8 : 12)
    }
}

// View for displaying the loading indicator
struct LoadingIndicatorView: View {
    let geometry: GeometryProxy
    
    var body: some View {
        ProgressView()
            .progressViewStyle(CircularProgressViewStyle(tint: .white))
            .frame(width: 20, height: 20)
            .offset(x: geometry.size.width - 32, y: -geometry.size.height/2 + 44)
    }
}

// Container view for train times display
struct TrainTimesContainerView: View {
    let trains: [TrainTime]
    let errorMessage: String
    let isLoading: Bool
    let isActive: Bool
    let isSmallScreen: Bool
    let showPreciseMode: Bool
    
    private var height: CGFloat {
        if !errorMessage.isEmpty {
            return isSmallScreen ? 28 : 32  // Height for error message
        } else if !trains.isEmpty {
            return isSmallScreen ? 60 : 60  // Height for times
        } else if isLoading && isActive {
            return isSmallScreen ? 28 : 32  // Height for loading
        }
        return 0  // Collapsed height when no content
    }
    
    var body: some View {
        VStack(spacing: 0) {
            if !errorMessage.isEmpty {
                ErrorView(message: errorMessage, isSmallScreen: isSmallScreen)
            } else if !trains.isEmpty {
                PrimaryTrainView(
                    train: trains[0],
                    isSmallScreen: isSmallScreen,
                    showPreciseMode: showPreciseMode
                )
                
                if trains.count > 1 {
                    AdditionalTrainsView(
                        trains: Array(trains.dropFirst()),
                        showPreciseMode: showPreciseMode
                    )
                }
            } else if isLoading && isActive {
                LoadingView(isSmallScreen: isSmallScreen)
            }
        }
        .frame(height: height)
        .clipped()
    }
}

// Main TimesView
struct TimesView: View {
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject var favoritesManager: FavoritesManager
    @EnvironmentObject var navigationState: NavigationState
    @EnvironmentObject var settingsManager: SettingsManager
    @StateObject private var viewModel: TimesViewModel = TimesViewModel()
    @State private var showingFavoriteAlert = false
    let line: SubwayLine
    let station: Station
    let direction: String
    
    // Convert the ViewModel's data format to our simplified TrainTime struct
    private var trainTimes: [TrainTime] {
        return viewModel.nextTrains.map { TrainTime(minutes: $0.minutes, seconds: $0.seconds) }
    }
    
    init(viewModel: TimesViewModel, line: SubwayLine, station: Station, direction: String) {
        self.line = line
        self.station = station
        self.direction = direction
    }
    
    var body: some View {
        GeometryReader { geometry in
            let isSmallScreen = geometry.size.width < 165
            
            ZStack {
                // Main content
                VStack(alignment: .center, spacing: 0) {
                    // Line circle
                    LineCircleView(line: line, isSmallScreen: isSmallScreen)
                    
                    // Train times container
                    TrainTimesContainerView(
                        trains: trainTimes,
                        errorMessage: viewModel.errorMessage,
                        isLoading: viewModel.loading,
                        isActive: scenePhase == .active,
                        isSmallScreen: isSmallScreen,
                        showPreciseMode: settingsManager.showPreciseMode
                    )
                    .animation(.easeInOut(duration: 0.3), value: viewModel.nextTrains.isEmpty)
                    .animation(.easeInOut(duration: 0.3), value: viewModel.errorMessage)
                    
                    // Station name
                    StationNameView(stationName: station.display, isSmallScreen: isSmallScreen)
                }
                .frame(
                    minWidth: geometry.size.width,
                    minHeight: geometry.size.height,
                    alignment: .center
                )
                .animation(.easeInOut(duration: 0.3), value: viewModel.loading || !viewModel.nextTrains.isEmpty)
                
                // Loading indicator overlay
                if viewModel.loading {
                    LoadingIndicatorView(geometry: geometry)
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(action: {
                    // Trigger haptic feedback
                    WKInterfaceDevice.current().play(.start)

                    navigationState.reset()
                }) {
                    Image(systemName: "xmark")
                }
            }
        }
        .onAppear {
            viewModel.startFetchingTimes(for: line, station: station, direction: direction)
        }
        .onDisappear {
            viewModel.stopFetchingTimes()
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            switch newPhase {
            case .active:
                viewModel.startFetchingTimes(for: line, station: station, direction: direction)
                viewModel.adjustUpdateFrequency(isActive: true)
            case .inactive:
                viewModel.adjustUpdateFrequency(isActive: false)
            case .background:
                if WKExtension.shared().isAutorotating {
                    viewModel.stopFetchingTimes()
                } else {
                    viewModel.adjustUpdateFrequency(isActive: false)
                }
            @unknown default:
                break
            }
        }
        .onLongPressGesture {
            // Trigger haptic feedback
            WKInterfaceDevice.current().play(.start)

            showingFavoriteAlert = true
        }
        .confirmationDialog("Add to Favorites?", isPresented: $showingFavoriteAlert, titleVisibility: .visible) {
            // Create favorites buttons outside the main view hierarchy
            FavoritesButtons(
                line: line,
                station: station,
                direction: direction,
                favoritesManager: favoritesManager
            )
        }
    }
}

// Extracted favorites dialog buttons to separate view
struct FavoritesButtons: View {
    let line: SubwayLine
    let station: Station
    let direction: String
    let favoritesManager: FavoritesManager
    
    var body: some View {
        Group {
            if !favoritesManager.isFavorite(lineId: line.id, stationName: station.name, direction: direction) {
                Button("Add to Favorites") {
                    favoritesManager.addFavorite(
                        lineId: line.id,
                        stationName: station.name,
                        stationDisplay: station.display,
                        direction: direction
                    )
                }
            } else {
                Button("Remove from Favorites", role: .destructive) {
                    if let favorite = favoritesManager.favorites.first(where: {
                        $0.lineId == line.id &&
                        $0.stationName == station.name &&
                        $0.direction == direction
                    }) {
                        favoritesManager.removeFavorite(favorite: favorite)
                    }
                }
            }
            Button("Cancel", role: .cancel) {}
        }
    }
}

// Preview provider for SwiftUI previews
//#Preview {
//    ContentView()
//        .environmentObject(StationDataManager())
//        .environmentObject(FavoritesManager())
//}

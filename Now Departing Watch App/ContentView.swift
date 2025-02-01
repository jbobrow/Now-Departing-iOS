//
//  ContentView.swift
//  Now Departing WatchOS App
//
//  Created by Jonathan Bobrow on 12/29/24.
//

import SwiftUI
import Combine
import WatchKit

// Models
struct SubwayLine: Identifiable, Equatable {
    let id: String
    let label: String
    let bg_color: Color
    let fg_color: Color
}

struct Station: Identifiable, Codable, Equatable {
    let id: String = UUID().uuidString // Automatically generated unique ID
    let display: String
    let name: String
    var hasAvailableTimes: Bool?  // New property
    
    private enum CodingKeys: String, CodingKey {
        case display
        case name
        case id
        case hasAvailableTimes
    }
    
    // Custom encoding to ensure id is included
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(display, forKey: .display)
        try container.encode(name, forKey: .name)
        try container.encode(id, forKey: .id)
        try container.encodeIfPresent(hasAvailableTimes, forKey: .hasAvailableTimes)
    }
}

struct APIResponse: Decodable {
    let data: [StationData]
}

struct StationData: Decodable {
    let name: String
    let N: [Train]
    let S: [Train]
}

struct Train: Decodable {
    let route: String
    let time: String
}

struct TrainData: Decodable {
    let station: String
    let arrivalTimes: [Int]
    
    private enum CodingKeys: String, CodingKey {
        case station
        case arrivalTimes = "times"
    }
}

// Navigation State Management
class NavigationState: ObservableObject {
    @Published var line: SubwayLine?
    @Published var station: Station?
    @Published var terminal: Station?
    @Published var path = NavigationPath()
    
    func reset() {
        line = nil
        station = nil
        terminal = nil
        path = NavigationPath()
    }
}

// Main App Views
struct ContentView: View {
    @EnvironmentObject var stationDataManager: StationDataManager
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var navigationState = NavigationState()
    @StateObject private var favoritesManager = FavoritesManager()
    @State private var showSettings = false
    @State private var selectedTab = 0
    
    let lines = [
        SubwayLine(id: "1", label: "1", bg_color: SubwayConfiguration.lineColors["1"]!.background, fg_color: SubwayConfiguration.lineColors["1"]!.foreground),
        SubwayLine(id: "2", label: "2", bg_color: SubwayConfiguration.lineColors["2"]!.background, fg_color: SubwayConfiguration.lineColors["2"]!.foreground),
        SubwayLine(id: "3", label: "3", bg_color: SubwayConfiguration.lineColors["3"]!.background, fg_color: SubwayConfiguration.lineColors["3"]!.foreground),
        SubwayLine(id: "X", label: "X", bg_color: SubwayConfiguration.lineColors["X"]!.background, fg_color: SubwayConfiguration.lineColors["X"]!.foreground),
        SubwayLine(id: "4", label: "4", bg_color: SubwayConfiguration.lineColors["4"]!.background, fg_color: SubwayConfiguration.lineColors["4"]!.foreground),
        SubwayLine(id: "5", label: "5", bg_color: SubwayConfiguration.lineColors["5"]!.background, fg_color: SubwayConfiguration.lineColors["5"]!.foreground),
        SubwayLine(id: "6", label: "6", bg_color: SubwayConfiguration.lineColors["6"]!.background, fg_color: SubwayConfiguration.lineColors["6"]!.foreground),
        SubwayLine(id: "7", label: "7", bg_color: SubwayConfiguration.lineColors["7"]!.background, fg_color: SubwayConfiguration.lineColors["7"]!.foreground),
        SubwayLine(id: "A", label: "A", bg_color: SubwayConfiguration.lineColors["A"]!.background, fg_color: SubwayConfiguration.lineColors["A"]!.foreground),
        SubwayLine(id: "C", label: "C", bg_color: SubwayConfiguration.lineColors["C"]!.background, fg_color: SubwayConfiguration.lineColors["C"]!.foreground),
        SubwayLine(id: "E", label: "E", bg_color: SubwayConfiguration.lineColors["E"]!.background, fg_color: SubwayConfiguration.lineColors["E"]!.foreground),
        SubwayLine(id: "G", label: "G", bg_color: SubwayConfiguration.lineColors["G"]!.background, fg_color: SubwayConfiguration.lineColors["G"]!.foreground),
        SubwayLine(id: "B", label: "B", bg_color: SubwayConfiguration.lineColors["B"]!.background, fg_color: SubwayConfiguration.lineColors["B"]!.foreground),
        SubwayLine(id: "D", label: "D", bg_color: SubwayConfiguration.lineColors["D"]!.background, fg_color: SubwayConfiguration.lineColors["D"]!.foreground),
        SubwayLine(id: "F", label: "F", bg_color: SubwayConfiguration.lineColors["F"]!.background, fg_color: SubwayConfiguration.lineColors["F"]!.foreground),
        SubwayLine(id: "M", label: "M", bg_color: SubwayConfiguration.lineColors["M"]!.background, fg_color: SubwayConfiguration.lineColors["M"]!.foreground),
        SubwayLine(id: "N", label: "N", bg_color: SubwayConfiguration.lineColors["N"]!.background, fg_color: SubwayConfiguration.lineColors["N"]!.foreground),
        SubwayLine(id: "Q", label: "Q", bg_color: SubwayConfiguration.lineColors["Q"]!.background, fg_color: SubwayConfiguration.lineColors["Q"]!.foreground),
        SubwayLine(id: "R", label: "R", bg_color: SubwayConfiguration.lineColors["R"]!.background, fg_color: SubwayConfiguration.lineColors["R"]!.foreground),
        SubwayLine(id: "W", label: "W", bg_color: SubwayConfiguration.lineColors["W"]!.background, fg_color: SubwayConfiguration.lineColors["W"]!.foreground),
        SubwayLine(id: "J", label: "J", bg_color: SubwayConfiguration.lineColors["J"]!.background, fg_color: SubwayConfiguration.lineColors["J"]!.foreground),
        SubwayLine(id: "Z", label: "Z", bg_color: SubwayConfiguration.lineColors["Z"]!.background, fg_color: SubwayConfiguration.lineColors["Z"]!.foreground),
        SubwayLine(id: "L", label: "L", bg_color: SubwayConfiguration.lineColors["L"]!.background, fg_color: SubwayConfiguration.lineColors["L"]!.foreground)
    ]
    
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
                // Lines Grid View
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
                .tag(0)
                
                // Favorites View
                FavoritesView(
                    onSelect: { line, station, direction in
                        navigationState.line = line
                        navigationState.station = station
                        // For favorites, we'll use the station as both station and terminal
                        // since we already know the direction
                        navigationState.terminal = station
                        DispatchQueue.main.async {
                            navigationState.path.append("times")
                        }
                    },
                    lines: lines
                )
                .tag(1)
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
                        TerminalSelectionView(line: line, stations: stations, onSelect: { terminal in
                            navigationState.terminal = terminal
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
                              let terminal = navigationState.terminal,
                              let stations = stationDataManager.stations(for: line.id) {
                        let viewModel = TimesViewModel()
                        let terminalDirection = terminal == stations.first ? "N" : "S"
                        TimesView(viewModel: viewModel, line: line, station: station, direction: terminalDirection)
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
                }
            }
        }
        .environmentObject(favoritesManager)
        .onChange(of: scenePhase) { oldPhase, newPhase in
            switch newPhase {
            case .active:
                stationDataManager.refreshStations()
                scheduleNextBackgroundRefresh()
            case .background:
                // Handle background state
                break
            case .inactive:
                break
            @unknown default:
                break
            }
        }
    }
}


// Line Selection View
struct LineSelectionView: View {
    let lines: [SubwayLine]
    let onSelect: (SubwayLine) -> Void
    let onSettings: () -> Void
    
    var body: some View {
        GeometryReader { geometry in
            let isSmallScreen = geometry.size.width < 165
            
            let columns = [
                GridItem(.flexible(minimum: 32, maximum: 38), spacing: isSmallScreen ? 2 : 4),
                GridItem(.flexible(minimum: 32, maximum: 38), spacing: isSmallScreen ? 2 : 4),
                GridItem(.flexible(minimum: 32, maximum: 38), spacing: isSmallScreen ? 2 : 4),
                GridItem(.flexible(minimum: 32, maximum: 38), spacing: isSmallScreen ? 2 : 4)
            ]
            
            ScrollView {
                LazyVGrid(columns: columns, spacing: isSmallScreen ? 2 : 4) {
                    ForEach(lines) { line in
                        if line.id == "X" {
                            Button(action: onSettings) {
                                Image(systemName: "gear")
                                    .foregroundColor(.black)
                                    .frame(width: isSmallScreen ? 34 : 38, height: isSmallScreen ? 34 : 38)
                            }
                            .buttonStyle(PlainButtonStyle())
                        } else {
                            Button(action: { onSelect(line) }) {
                                Text(line.label)
                                    .font(.custom("HelveticaNeue-Bold", size: isSmallScreen ? 22 : 26))
                                    .foregroundColor(line.fg_color)
                                    .frame(width: isSmallScreen ? 34 : 38, height: isSmallScreen ? 34 : 38)
                                    .background(Circle().fill(line.bg_color))
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                }
            }
            .padding(.horizontal)
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
                        Button(action: { onSelect(station) }) {
                            HStack {
                                if station.hasAvailableTimes == false {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundColor(Color(red: 0.6, green: 0.6, blue: 0.6))
                                    Text(station.display)
                                        .foregroundColor(Color(red: 0.6, green: 0.6, blue: 0.6))
                                }
                                else {
                                    Text(station.display)
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
                        .font(.custom("HelveticaNeue-Bold", size: 26))
                        .foregroundColor(line.fg_color)
                        .frame(width: 40, height: 40)
                        .background(Circle().fill(line.bg_color))
                    Text("Select a station")
                        .font(.custom("HelveticaNeue-Bold", size: 18))
                }
            }
        }
    }
}

struct TerminalSelectionView: View {
    let line: SubwayLine
    let stations: [Station]
    let onSelect: (Station) -> Void
    
    var terminals: [Station] {
        guard stations.count > 1 else { return stations }
        return [stations.first!, stations.last!]
    }
    
    var body: some View {
        List(terminals) { terminal in
            Button(action: { onSelect(terminal) }) {
                Text(terminal.display)
                    .foregroundColor(.white)
            }
        }
        .listStyle(.plain)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .automatic) {
                HStack {
                    Text(line.label)
                        .font(.custom("HelveticaNeue-Bold", size: 26))
                        .foregroundColor(line.fg_color)
                        .frame(width: 40, height: 40)
                        .background(Circle().fill(line.bg_color))
                    Text("Select terminal station")
                        .font(.custom("HelveticaNeue-Bold", size: 18))
                }
            }
        }
    }
}

struct TimesView: View {
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject var favoritesManager: FavoritesManager
    @StateObject private var viewModel: TimesViewModel = TimesViewModel()
    @State private var showingFavoriteAlert = false
    let line: SubwayLine
    let station: Station
    let direction: String
    
    init(viewModel: TimesViewModel, line: SubwayLine, station: Station, direction: String) {
        self.line = line
        self.station = station
        self.direction = direction
    }
    
    var body: some View {
        GeometryReader { geometry in
            let isSmallScreen = geometry.size.width < 165
            
            if viewModel.loading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .frame(width: 20, height: 20)
                    .offset(x: geometry.size.width - 32, y: -geometry.size.height/2 + 44)
            }
            
            VStack(alignment: .center, spacing: 0) {
                // Line Label
                Text(line.label)
                    .font(.custom("HelveticaNeue-Bold", size: isSmallScreen ? 48 : 60))
                    .foregroundColor(line.fg_color)
                    .frame(width: isSmallScreen ? 80 : 100, height: isSmallScreen ? 80 : 100)
                    .background(Circle().fill(line.bg_color))
                    .padding(.bottom, isSmallScreen ? 2 : 4)
                
                // Times Container - Always present but height animates
                VStack(spacing: 4) {
                    if !viewModel.errorMessage.isEmpty {
                        Text(viewModel.errorMessage)
                            .font(.custom("HelveticaNeue-Bold", size: 14))
                            .foregroundColor(.red)
                            .padding(.vertical, isSmallScreen ? 4 : 8)
                            .multilineTextAlignment(.center)
                            .transition(.opacity.combined(with: .scale))
                    } else {
                        let nextTrains = viewModel.nextTrains
                        if !nextTrains.isEmpty {
                            // Primary Time Display
                            let firstTrainText = nextTrains[0] == 0 ? "Departing" : "\(nextTrains[0]) min"
                            let firstTrainTextSize: CGFloat = nextTrains[0] == 0
                                ? (isSmallScreen ? 24 : 28)
                                : (isSmallScreen ? 32 : 36)
                            
                            Text(firstTrainText)
                                .font(.custom("HelveticaNeue-Bold", size: firstTrainTextSize))
                                .foregroundColor(.white)
                                .transition(.opacity.combined(with: .scale))
                                .id("primaryTime-\(firstTrainText)")
                            
                            // Additional Times
                            if nextTrains.count > 1 {
                                Text(nextTrains.dropFirst()
                                    .prefix(3)
                                    .map { "\($0) min" }
                                    .joined(separator: ", "))
                                    .font(.custom("HelveticaNeue-Bold", size: 14))
                                    .foregroundColor(Color(red: 0.6, green: 0.6, blue: 0.6))
                                    .lineLimit(1)
                                    .truncationMode(.tail)
                                    .transition(.opacity.combined(with: .scale))
                                    .id("secondaryTimes-\(nextTrains.dropFirst().prefix(3).map{String($0)}.joined())")
                            }
                        } else if viewModel.loading && scenePhase == .active {
                            Text("Loading...")
                                .font(.custom("HelveticaNeue-Bold", size: isSmallScreen ? 18 : 20))
                                .foregroundColor(Color(red: 0.6, green: 0.6, blue: 0.6))
                                .transition(.opacity)
                        }
                    }
                }
                .animation(.easeInOut(duration: 0.3), value: viewModel.nextTrains)
                .animation(.easeInOut(duration: 0.3), value: viewModel.errorMessage)
                // Add frame with fixed height to prevent layout jumps
                .frame(height: {
    if !viewModel.errorMessage.isEmpty {
        return isSmallScreen ? 40 : 50  // Height for error message
    } else if !viewModel.nextTrains.isEmpty {
        return isSmallScreen ? 60 : 70  // Height for times
    } else if viewModel.loading && scenePhase == .active {
        return isSmallScreen ? 30 : 35  // Height for loading
    }
    return 0  // Collapsed height when no content
}())
                .clipped()
                
                // Station Name
                Text(station.display)
                    .font(.custom("HelveticaNeue-Medium", size: isSmallScreen ? 18 : 20))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, isSmallScreen ? 8 : 12)
            }
            .frame(
                minWidth: geometry.size.width,
                minHeight: geometry.size.height,
                alignment: .center
            )
            .animation(.easeInOut(duration: 0.3), value: !viewModel.nextTrains.isEmpty || (viewModel.loading && scenePhase == .active))
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
            showingFavoriteAlert = true
        }
        .confirmationDialog("Add to Favorites?", isPresented: $showingFavoriteAlert, titleVisibility: .visible) {
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
#Preview {
    ContentView()
        .environmentObject(StationDataManager())
        .environmentObject(FavoritesManager())
}

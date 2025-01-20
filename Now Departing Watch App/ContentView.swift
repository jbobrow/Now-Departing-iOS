//
//  ContentView.swift
//  Now Departing WatchOS App
//
//  Created by Jonathan Bobrow on 12/29/24.
//

import SwiftUI
import Combine

// Models
struct SubwayLine: Identifiable, Equatable {
    let id: String
    let label: String
    let bg_color: Color
    let fg_color: Color
}

struct Station: Identifiable, Decodable, Equatable {
    let id: String = UUID().uuidString // Automatically generated unique ID
    let display: String
    let name: String
    
    private enum CodingKeys: String, CodingKey {
        case display
        case name
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
        case arrivalTimes = "times" // Adjust if the API uses a different key
    }
}

// Main App Views
struct ContentView: View {
    @EnvironmentObject var stationDataManager: StationDataManager
    @State private var selectedLine: SubwayLine?
    @State private var selectedStation: Station?
    @State private var selectedTerminal: Station?
    @State private var navigationPath = NavigationPath()
    @State private var showSettings = false
    @Environment(\.scenePhase) private var scenePhase
    
    let lines = [
        SubwayLine(id: "1", label: "1", bg_color: Color(red: 0.92, green: 0.22, blue: 0.21), fg_color: .white),
        SubwayLine(id: "2", label: "2", bg_color: Color(red: 0.92, green: 0.22, blue: 0.21), fg_color: .white),
        SubwayLine(id: "3", label: "3", bg_color: Color(red: 0.92, green: 0.22, blue: 0.21), fg_color: .white),
        SubwayLine(id: "X", label: "X", bg_color: Color(red: 0.0, green: 0.0, blue: 0.0), fg_color: .black),
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
    

    var body: some View {
        NavigationStack(path: $navigationPath) {
            LineSelectionView(
                lines: lines,
                onSelect: { line in
                    selectedLine = line
                    DispatchQueue.main.async {
                        navigationPath.append("stations")
                    }
                },
                onSettings: {
                    showSettings = true
                }
            )
            .navigationDestination(for: String.self) { route in
                switch route {
                case "stations":
                    if stationDataManager.isLoading {
                        ProgressView()
                    } else if let line = selectedLine {
                        StationSelectionView(line: line, onSelect: { station in
                            selectedStation = station
                            DispatchQueue.main.async {
                                navigationPath.append("terminals")
                            }
                        })
                    } else {
                        ProgressView()
                            .task {
                                stationDataManager.loadStations()
                            }
                    }
                    
                case "terminals":
                    if stationDataManager.isLoading {
                        ProgressView()
                    } else if let line = selectedLine,
                              let stations = stationDataManager.stations(for: line.id) {
                        TerminalSelectionView(line: line, stations: stations, onSelect: { terminal in
                            selectedTerminal = terminal
                            DispatchQueue.main.async {
                                navigationPath.append("times")
                            }
                        })
                    } else {
                        ProgressView()
                            .task {
                                stationDataManager.loadStations()
                            }
                    }
                    
                case "times":
                    if stationDataManager.isLoading {
                        ProgressView()
                    } else if let line = selectedLine,
                              let station = selectedStation,
                              let terminal = selectedTerminal,
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
    }
}

// Line Selection View
struct LineSelectionView: View {
    let lines: [SubwayLine]
    let onSelect: (SubwayLine) -> Void
    let onSettings: () -> Void  // callback for settings
    
    var body: some View {
        GeometryReader { geometry in
            let isSmallScreen = geometry.size.width < 165  // Approximate size for smaller watches
            
            // Helper Tool: display if the screen is small on screen
            //            VStack {
            //                Text("Screen Width: \(geometry.size.width, specifier: "%.2f")")
            //                if isSmallScreen {
            //                    Text("Small Screen Detected")
            //                } else {
            //                    Text("Large Screen Detected")
            //                }
            //            }
            //            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            let columns = [
                GridItem(.flexible(minimum: 32, maximum: 38), spacing: isSmallScreen ? 2 : 4),
                GridItem(.flexible(minimum: 32, maximum: 38), spacing: isSmallScreen ? 2 : 4),
                GridItem(.flexible(minimum: 32, maximum: 38), spacing: isSmallScreen ? 2 : 4),
                GridItem(.flexible(minimum: 32, maximum: 38), spacing: isSmallScreen ? 2 : 4)
            ]
            
            ScrollView {
                LazyVGrid(columns: columns, spacing: isSmallScreen ? 2 : 4) {
                    ForEach(lines) { line in
                        // handle the settings button
                        if( line.id == "X") {
                            Button(action: onSettings) {
                                Image(systemName: "gear")
                                    .foregroundColor(.black)
                                    .frame(width: isSmallScreen ? 34 : 38, height: isSmallScreen ? 34 : 38)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        else {
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
            if dataManager.isLoading {
                ProgressView()
            } else if let stations = dataManager.stations(for: line.id) {
                List(stations) { station in
                    Button(action: { onSelect(station) }) {
                        Text(station.display)
                            .foregroundColor(.white)
                    }
                }
                .listStyle(.plain)
            } else {
                ProgressView()
                    .task {
                        dataManager.refreshStations()
                    }
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

// Terminal Selection View
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

// Times View
struct TimesView: View {
    @Environment(\.scenePhase) private var scenePhase
    @ObservedObject var viewModel: TimesViewModel
    let line: SubwayLine
    let station: Station
    let direction: String
    
    var body: some View {
        GeometryReader { geometry in
            let isSmallScreen = geometry.size.width < 165
            
            VStack(alignment: .center, spacing: 0) {
                Text(line.label)
                    .font(.custom("HelveticaNeue-Bold", size: isSmallScreen ? 48 : 60))
                    .foregroundColor(line.fg_color)
                    .frame(width: isSmallScreen ? 80 : 100, height: isSmallScreen ? 80 : 100)
                    .background(Circle().fill(line.bg_color))
                    .padding(.bottom, isSmallScreen ? 2 : 4)
                
                if viewModel.loading {
                    Text("Loading...")
                        .font(.custom("HelveticaNeue-Bold", size: isSmallScreen ? 18 : 20))
                        .foregroundColor(Color(red: 0.6, green: 0.6, blue: 0.6))
                } else if !viewModel.errorMessage.isEmpty {
                    Text(viewModel.errorMessage)
                        .font(.custom("HelveticaNeue-Bold", size: 14))
                        .foregroundColor(.red)
                        .padding(.vertical, isSmallScreen ? 4 : 8)
                        .multilineTextAlignment(.center)
                } else {
                    let nextTrains = viewModel.nextTrains;
                    if !nextTrains.isEmpty {
                        let firstTrainText = nextTrains[0] == 0 ? "Departing" : "\(nextTrains[0]) min"
                        let firstTrainTextSize: CGFloat = nextTrains[0] == 0
                        ? (isSmallScreen ? 24 : 28)
                        : (isSmallScreen ? 32 : 36)
                        
                        Text(firstTrainText)
                            .font(.custom("HelveticaNeue-Bold", size: firstTrainTextSize))
                            .foregroundColor(.white)
                        
                        // Next trains on single line with truncation
                        Text(nextTrains.dropFirst()
                            .prefix(3)  // Limit to next 3 trains
                            .map { "\($0) min" }
                            .joined(separator: ", "))
                        .font(.custom("HelveticaNeue-Bold", size: 14))
                        .foregroundColor(Color(red: 0.6, green: 0.6, blue: 0.6))
                        .lineLimit(1)
                        .truncationMode(.tail)
                    } else {
                        Text("Loading...")
                            .font(.custom("HelveticaNeue-Bold", size: isSmallScreen ? 18 : 20))
                            .foregroundColor(Color(red: 0.6, green: 0.6, blue: 0.6))
                    }
                }
                
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
                break
            case .inactive:
                break
            case .background:
                viewModel.stopFetchingTimes()
                break
            @unknown default:
                break
            }
        }
    }
}

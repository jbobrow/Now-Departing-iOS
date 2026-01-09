//
//  LinesBrowseView.swift
//  Now Departing
//
//  Browse subway lines, stations, and departures (iOS version)
//

import SwiftUI

// MARK: - Main Browse View

struct LinesBrowseView: View {
    @EnvironmentObject var stationDataManager: StationDataManager
    @EnvironmentObject var favoritesManager: FavoritesManager
    @StateObject private var navigationState = NavigationState()

    let lines = [
        SubwayLine(id: "1", label: "1", bg_color: SubwayConfiguration.lineColors["1"]!.background, fg_color: SubwayConfiguration.lineColors["1"]!.foreground),
        SubwayLine(id: "2", label: "2", bg_color: SubwayConfiguration.lineColors["2"]!.background, fg_color: SubwayConfiguration.lineColors["2"]!.foreground),
        SubwayLine(id: "3", label: "3", bg_color: SubwayConfiguration.lineColors["3"]!.background, fg_color: SubwayConfiguration.lineColors["3"]!.foreground),
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

    var body: some View {
        NavigationStack {
            LineSelectionView(lines: lines, navigationState: navigationState)
                .environmentObject(navigationState)
                .navigationDestination(for: NavigationRoute.self) { route in
                    switch route {
                    case .stations(let line):
                        StationSelectionView(line: line)
                            .environmentObject(navigationState)
                    case .terminals(let line, let station):
                        TerminalSelectionView(line: line, station: station)
                            .environmentObject(navigationState)
                    case .times(let line, let station, let direction):
                        TimesView(line: line, station: station, direction: direction)
                            .environmentObject(navigationState)
                    }
                }
        }
    }
}

// MARK: - Navigation State

enum NavigationRoute: Hashable {
    case stations(SubwayLine)
    case terminals(SubwayLine, Station)
    case times(SubwayLine, Station, String)
}

class NavigationState: ObservableObject {
    @Published var path = NavigationPath()

    func reset() {
        path = NavigationPath()
    }
}

// MARK: - Line Selection View

struct LineSelectionView: View {
    let lines: [SubwayLine]
    @ObservedObject var navigationState: NavigationState
    @State private var selectedLineId: String? = nil

    var body: some View {
        ScrollView {
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                ForEach(lines) { line in
                    Button(action: {
                        // Haptic feedback
                        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                        impactFeedback.impactOccurred()

                        selectedLineId = line.id
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            selectedLineId = nil
                            navigationState.path.append(NavigationRoute.stations(line))
                        }
                    }) {
                        Text(line.label)
                            .font(.custom("HelveticaNeue-Bold", size: 44))
                            .foregroundColor(line.fg_color)
                            .frame(width: 100, height: 100)
                            .background(Circle().fill(line.bg_color))
                            .scaleEffect(selectedLineId == line.id ? 1.05 : 1.0)
                            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: selectedLineId == line.id)
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Browse by Line")
        .navigationBarTitleDisplayMode(.large)
    }
}

// MARK: - Station Selection View

struct StationSelectionView: View {
    let line: SubwayLine
    @EnvironmentObject var stationDataManager: StationDataManager
    @ObservedObject var navigationState: NavigationState

    var body: some View {
        Group {
            switch stationDataManager.loadingState {
            case .loading:
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle())
            case .error(let message):
                Text(message)
                    .foregroundColor(.red)
            case .loaded:
                if let stations = stationDataManager.stations(for: line.id) {
                    List(stations) { station in
                        Button(action: {
                            // Haptic feedback
                            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                            impactFeedback.impactOccurred()

                            navigationState.path.append(NavigationRoute.terminals(line, station))
                        }) {
                            HStack {
                                if station.hasAvailableTimes == false {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundColor(Color(red: 0.6, green: 0.6, blue: 0.6))
                                    Text(station.display)
                                        .font(.custom("HelveticaNeue-Bold", size: 18))
                                        .foregroundColor(Color(red: 0.6, green: 0.6, blue: 0.6))
                                } else {
                                    Text(station.display)
                                        .font(.custom("HelveticaNeue-Bold", size: 18))
                                        .foregroundColor(.primary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.secondary)
                                    .font(.system(size: 14))
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            case .idle:
                Color.clear.onAppear {
                    stationDataManager.loadStationsForLine(line.id)
                }
            }
        }
        .navigationTitle(line.label + " Line")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .principal) {
                HStack(spacing: 8) {
                    Text(line.label)
                        .font(.custom("HelveticaNeue-Bold", size: 24))
                        .foregroundColor(line.fg_color)
                        .frame(width: 40, height: 40)
                        .background(Circle().fill(line.bg_color))
                }
            }
        }
        .onAppear {
            stationDataManager.loadStationsForLine(line.id)
        }
    }
}

// MARK: - Terminal Selection View

struct TerminalSelectionView: View {
    let line: SubwayLine
    let station: Station
    @EnvironmentObject var stationDataManager: StationDataManager
    @ObservedObject var navigationState: NavigationState

    var terminals: [(direction: String, description: String)] {
        [
            (direction: "N", description: DirectionHelper.getToDestination(for: line.id, direction: "N")),
            (direction: "S", description: DirectionHelper.getToDestination(for: line.id, direction: "S"))
        ]
    }

    var body: some View {
        List(terminals, id: \.direction) { terminal in
            Button(action: {
                // Haptic feedback
                let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                impactFeedback.impactOccurred()

                navigationState.path.append(NavigationRoute.times(line, station, terminal.direction))
            }) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(station.display)
                        .font(.custom("HelveticaNeue-Bold", size: 20))
                        .foregroundColor(.primary)

                    Text(terminal.description)
                        .font(.custom("HelveticaNeue", size: 16))
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 8)
            }
        }
        .listStyle(.plain)
        .navigationTitle("Select Direction")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .principal) {
                HStack(spacing: 8) {
                    Text(line.label)
                        .font(.custom("HelveticaNeue-Bold", size: 24))
                        .foregroundColor(line.fg_color)
                        .frame(width: 40, height: 40)
                        .background(Circle().fill(line.bg_color))
                }
            }
        }
    }
}

// MARK: - Times View

struct TimesView: View {
    let line: SubwayLine
    let station: Station
    let direction: String

    @EnvironmentObject var favoritesManager: FavoritesManager
    @EnvironmentObject var stationDataManager: StationDataManager
    @ObservedObject var navigationState: NavigationState
    @StateObject private var viewModel = TimesViewModel()
    @State private var showingFavoriteAlert = false
    @State private var currentTime = Date()

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    // Check if this is already favorited
    private var isFavorited: Bool {
        favoritesManager.isFavorite(
            lineId: line.id,
            stationName: station.name,
            direction: direction
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header with line badge
            VStack(spacing: 16) {
                Text(line.label)
                    .font(.custom("HelveticaNeue-Bold", size: 80))
                    .foregroundColor(line.fg_color)
                    .frame(width: 140, height: 140)
                    .background(Circle().fill(line.bg_color))

                Text(station.display)
                    .font(.custom("HelveticaNeue-Bold", size: 28))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                Text(DirectionHelper.getToTerminalStation(
                    for: line.id,
                    direction: direction,
                    stationDataManager: stationDataManager
                ))
                .font(.custom("HelveticaNeue", size: 18))
                .foregroundColor(.secondary)
            }
            .padding(.top, 40)

            Spacer()

            // Train times
            if viewModel.loading && viewModel.nextTrains.isEmpty {
                ProgressView()
                    .scaleEffect(1.5)
                    .padding()
            } else if !viewModel.errorMessage.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.orange)

                    Text(viewModel.errorMessage)
                        .font(.custom("HelveticaNeue", size: 18))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
            } else if !viewModel.nextTrains.isEmpty {
                VStack(spacing: 12) {
                    // Primary time
                    Text(getTimeText(for: viewModel.nextTrains[0]))
                        .font(.custom("HelveticaNeue-Bold", size: 48))
                        .foregroundColor(.primary)

                    // Additional times
                    if viewModel.nextTrains.count > 1 {
                        Text(viewModel.nextTrains.dropFirst().prefix(3).map { train in
                            getAdditionalTimeText(for: train)
                        }.joined(separator: ", "))
                        .font(.custom("HelveticaNeue", size: 20))
                        .foregroundColor(.secondary)
                    }
                }
            }

            Spacer()

            // Favorite button
            Button(action: {
                showingFavoriteAlert = true
            }) {
                HStack(spacing: 8) {
                    Image(systemName: isFavorited ? "heart.fill" : "heart")
                    Text(isFavorited ? "Remove from Favorites" : "Add to Favorites")
                }
                .font(.custom("HelveticaNeue-Bold", size: 18))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(isFavorited ? Color.red : Color.blue)
                .cornerRadius(14)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: {
                    navigationState.reset()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "xmark")
                        Text("Close")
                    }
                }
            }
        }
        .onAppear {
            viewModel.startFetchingTimes(for: line, station: station, direction: direction)
        }
        .onDisappear {
            viewModel.stopFetchingTimes()
        }
        .onReceive(timer) { time in
            currentTime = time
        }
        .confirmationDialog("Favorites", isPresented: $showingFavoriteAlert, titleVisibility: .visible) {
            if isFavorited {
                Button("Remove from Favorites", role: .destructive) {
                    removeFavorite()
                }
            } else {
                Button("Add to Favorites") {
                    addToFavorites()
                }
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    private func getTimeText(for train: (minutes: Int, seconds: Int)) -> String {
        let totalSeconds = train.minutes * 60 + train.seconds

        if totalSeconds == 0 {
            return "Departing"
        } else if totalSeconds <= 30 {
            return "Departing"
        } else if totalSeconds < 60 {
            return "Arriving"
        } else {
            return "\(train.minutes) min"
        }
    }

    private func getAdditionalTimeText(for train: (minutes: Int, seconds: Int)) -> String {
        let totalSeconds = train.minutes * 60 + train.seconds

        if totalSeconds < 60 {
            return "Arriving"
        } else {
            return "\(train.minutes) min"
        }
    }

    private func addToFavorites() {
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()

        favoritesManager.addFavorite(
            lineId: line.id,
            stationName: station.name,
            stationDisplay: station.display,
            direction: direction
        )
    }

    private func removeFavorite() {
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()

        if let favorite = favoritesManager.favorites.first(where: {
            $0.lineId == line.id &&
            $0.stationName == station.name &&
            $0.direction == direction
        }) {
            favoritesManager.removeFavorite(favorite: favorite)
        }
    }
}

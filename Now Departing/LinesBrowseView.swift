//
//  LinesBrowseView.swift
//  Now Departing
//
//  Browse subway lines, stations, and departures (iOS version)
//

import SwiftUI
import ActivityKit

// MARK: - Main Browse View

struct LinesBrowseView: View {
    @EnvironmentObject var stationDataManager: StationDataManager
    @EnvironmentObject var favoritesManager: FavoritesManager
    @StateObject private var navigationState = NavigationState()

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

    var body: some View {
        NavigationStack(path: $navigationState.path) {
            LineSelectionView(lines: lines)
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

    func hash(into hasher: inout Hasher) {
        switch self {
        case .stations(let line):
            hasher.combine("stations")
            hasher.combine(line.id)
        case .terminals(let line, let station):
            hasher.combine("terminals")
            hasher.combine(line.id)
            hasher.combine(station.id)
        case .times(let line, let station, let direction):
            hasher.combine("times")
            hasher.combine(line.id)
            hasher.combine(station.id)
            hasher.combine(direction)
        }
    }

    static func == (lhs: NavigationRoute, rhs: NavigationRoute) -> Bool {
        switch (lhs, rhs) {
        case (.stations(let line1), .stations(let line2)):
            return line1.id == line2.id
        case (.terminals(let line1, let station1), .terminals(let line2, let station2)):
            return line1.id == line2.id && station1.id == station2.id
        case (.times(let line1, let station1, let dir1), .times(let line2, let station2, let dir2)):
            return line1.id == line2.id && station1.id == station2.id && dir1 == dir2
        default:
            return false
        }
    }
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
    @EnvironmentObject var navigationState: NavigationState
    @State private var selectedLineId: String? = nil

    var body: some View {
        ScrollView {
            LazyVGrid(columns: [
                GridItem(.flexible()),
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
                            .font(.custom("HelveticaNeue-Bold", size: 56))
                            .foregroundColor(line.fg_color)
                            .frame(width: 80, height: 80)
                            .background(Circle().fill(line.bg_color))
                            .scaleEffect(selectedLineId == line.id ? 1.05 : 1.0)
                            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: selectedLineId == line.id)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding()
        }
        .navigationTitle("Select Line")
        .navigationBarTitleDisplayMode(.large)
    }
}

// MARK: - Station Selection View

struct StationSelectionView: View {
    let line: SubwayLine
    @EnvironmentObject var stationDataManager: StationDataManager
    @EnvironmentObject var navigationState: NavigationState

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
        .navigationTitle("Select Station")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .principal) {
                HStack(spacing: 8) {
                    Text(line.label)
                        .font(.custom("HelveticaNeue-Bold", size: 28))
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
    @EnvironmentObject var navigationState: NavigationState

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
                    Text(LocationBasedDirectionHelper.getContextualDestination(
                        for: line.id,
                        direction: terminal.direction,
                        currentLocation: nil,
                    ))
                        .font(.custom("HelveticaNeue-Bold", size: 20))
                        .foregroundColor(.primary)

                    Text(DirectionHelper.getToTerminalStation(
                        for: line.id,
                        direction: terminal.direction,
                        stationDataManager: stationDataManager
                    ))
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
                        .font(.custom("HelveticaNeue-Bold", size: 28))
                        .foregroundColor(line.fg_color)
                        .frame(width: 40, height: 40)
                        .background(Circle().fill(line.bg_color))
                }
            }
        }
    }
}

// MARK: - Times View Model (iOS)

class TimesViewModeliOS: ObservableObject {
    @Published var nextTrains: [(minutes: Int, seconds: Int)] = []
    @Published var loading: Bool = false
    @Published var errorMessage: String = ""

    private var apiTimer: Timer?
    private var displayTimer: Timer?
    private var arrivalTimes: [Date] = []

    func startFetchingTimes(for line: SubwayLine, station: Station, direction: String) {
        loading = true
        fetchArrivalTimes(for: line, station: station, direction: direction)

        // Refresh every 30 seconds
        apiTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.fetchArrivalTimes(for: line, station: station, direction: direction)
        }

        // Update display every second
        displayTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.updateDisplayTimes()
        }
    }

    func stopFetchingTimes() {
        apiTimer?.invalidate()
        apiTimer = nil
        displayTimer?.invalidate()
        displayTimer = nil
    }

    private func updateDisplayTimes() {
        let now = Date()
        nextTrains = arrivalTimes.compactMap { arrivalTime in
            let interval = arrivalTime.timeIntervalSince(now)
            if interval < 0 { return nil }

            let totalSeconds = Int(interval)
            let minutes = totalSeconds / 60
            let seconds = totalSeconds % 60

            return (minutes: minutes, seconds: seconds)
        }.sorted { $0.minutes * 60 + $0.seconds < $1.minutes * 60 + $1.seconds }

        // Clean up past arrival times
        arrivalTimes = arrivalTimes.filter { $0 > now }
    }

    private func fetchArrivalTimes(for line: SubwayLine, station: Station, direction: String) {
        let apiURL = "https://api.wheresthefuckingtrain.com/by-route/\(line.id)"

        guard let url = URL(string: apiURL) else {
            errorMessage = "Invalid URL"
            loading = false
            return
        }

        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    self?.errorMessage = "Network error: \(error.localizedDescription)"
                    self?.loading = false
                    return
                }

                guard let data = data else {
                    self?.errorMessage = "No data received"
                    self?.loading = false
                    return
                }

                do {
                    let response = try JSONDecoder().decode(APIResponse.self, from: data)
                    if let stationData = response.data.first(where: { $0.name == station.name }) {
                        let trains = direction == "N" ? stationData.N : stationData.S
                        let filteredTrains = trains.filter { $0.route == line.id }

                        let formatter = ISO8601DateFormatter()
                        self?.arrivalTimes = filteredTrains.compactMap { train -> Date? in
                            formatter.date(from: train.time)
                        }.filter { $0 > Date() }
                        .sorted()

                        if self?.arrivalTimes.isEmpty == true {
                            self?.errorMessage = "No trains scheduled"
                        } else {
                            self?.errorMessage = ""
                        }
                        self?.updateDisplayTimes()
                    } else {
                        self?.errorMessage = "Station not found"
                    }
                    self?.loading = false
                } catch {
                    self?.errorMessage = "Failed to decode data"
                    self?.loading = false
                }
            }
        }.resume()
    }
}

// MARK: - Times View

struct TimesView: View {
    let line: SubwayLine
    let station: Station
    let direction: String

    @EnvironmentObject var favoritesManager: FavoritesManager
    @EnvironmentObject var stationDataManager: StationDataManager
    @StateObject private var viewModel = TimesViewModeliOS()
    @State private var showingFavoriteAlert = false
    @State private var showingWidgetInfo = false
    @State private var showingLiveActivityInfo = false
    @State private var liveActivityStarted = false
    @State private var currentTime = Date()
    @State private var widgetSize: WidgetSize = .large

    // Make navigationState optional - only exists when navigating from LinesBrowseView
    @Environment(\.dismiss) private var dismiss

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    enum WidgetSize: String, CaseIterable {
        case small = "Small"
        case medium = "Medium"
        case large = "Large"
    }

    // Check if this is already favorited
    private var isFavorited: Bool {
        favoritesManager.isFavorite(
            lineId: line.id,
            stationName: station.name,
            direction: direction
        )
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Widget size picker with SF Symbols
                Picker("Widget Size", selection: $widgetSize) {
                    Image(systemName: "widget.small")
                        .tag(WidgetSize.small)
                    Image(systemName: "widget.medium")
                        .tag(WidgetSize.medium)
                    Image(systemName: "widget.large")
                        .tag(WidgetSize.large)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 24)
                .padding(.top, 20)

                // Widget preview container with centered content
                ZStack {
                    // Glass/frosted background
                    RoundedRectangle(cornerRadius: widgetCornerRadius)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: widgetCornerRadius)
                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                        )
                        .shadow(color: Color.black.opacity(0.2), radius: 12, x: 0, y: 6)

                    // Widget content
                    switch widgetSize {
                    case .small:
                        smallWidgetContent
                    case .medium:
                        mediumWidgetContent
                    case .large:
                        largeWidgetContent
                    }
                }
                .frame(width: widgetWidth, height: widgetHeight)
                .aspectRatio(widgetSize == .small ? 1 : nil, contentMode: .fit)
                .animation(.easeInOut(duration: 0.3), value: widgetSize)
                .frame(maxWidth: .infinity) // Center the widget
                .padding(.horizontal, 24)

                // Action buttons with glass effect
                VStack(spacing: 12) {
                    // Add Widget to Homescreen button
                    Button(action: {
                        showingWidgetInfo = true
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "plus.app.fill")
                            Text("Add to Homescreen")
                        }
                        .font(.custom("HelveticaNeue-Bold", size: 18))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(Color.green.opacity(0.5), lineWidth: 2)
                        )
                        .cornerRadius(14)
                    }

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
                        .background(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(isFavorited ? Color.red.opacity(0.5) : Color.blue.opacity(0.5), lineWidth: 2)
                        )
                        .cornerRadius(14)
                    }

                    // Live Activity for StandBy mode button
                    if #available(iOS 16.2, *), LiveActivityManager.isSupported() {
                        Button(action: {
                            toggleLiveActivity()
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: liveActivityStarted ? "iphone.gen3.radiowaves.left.and.right" : "iphone.gen3")
                                Text(liveActivityStarted ? "Stop Live Activity" : "Start Live Activity")
                            }
                            .font(.custom("HelveticaNeue-Bold", size: 18))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(.ultraThinMaterial)
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(liveActivityStarted ? Color.orange.opacity(0.5) : Color.purple.opacity(0.5), lineWidth: 2)
                            )
                            .cornerRadius(14)
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
        }
        .background(Color(UIColor.systemGroupedBackground))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            viewModel.startFetchingTimes(for: line, station: station, direction: direction)
        }
        .onDisappear {
            viewModel.stopFetchingTimes()
            // Stop Live Activity when leaving the view
            if liveActivityStarted {
                if #available(iOS 16.2, *) {
                    LiveActivityManager.shared.endActivity()
                }
                liveActivityStarted = false
            }
        }
        .onReceive(timer) { time in
            currentTime = time
        }
        .onReceive(viewModel.$nextTrains) { trains in
            // Update Live Activity when train times change
            if liveActivityStarted && !trains.isEmpty {
                if #available(iOS 16.2, *) {
                    LiveActivityManager.shared.updateActivity(nextTrains: trains)
                }
            }
        }
        .alert("Add Widget to Homescreen", isPresented: $showingWidgetInfo) {
            Button("Got It", role: .cancel) {}
        } message: {
            Text("To add a widget to your homescreen:\n\n1. Long press on your homescreen\n2. Tap the + button\n3. Search for 'Now Departing'\n4. Select this train and direction")
        }
        .alert("Live Activity for StandBy", isPresented: $showingLiveActivityInfo) {
            Button("Got It", role: .cancel) {}
        } message: {
            Text("Live Activity started! Place your iPhone horizontally on a charger to see it in StandBy mode.\n\nThe display will show real-time train arrivals and automatically update.")
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

    // MARK: - Live Activity Functions

    @available(iOS 16.2, *)
    private func toggleLiveActivity() {
        if liveActivityStarted {
            LiveActivityManager.shared.endActivity()
            liveActivityStarted = false
        } else {
            startLiveActivity()
        }
    }

    @available(iOS 16.2, *)
    private func startLiveActivity() {
        let destinationStation = DirectionHelper.getToTerminalStation(
            for: line.id,
            direction: direction,
            stationDataManager: stationDataManager
        )

        LiveActivityManager.shared.startActivity(
            lineId: line.id,
            lineLabel: line.label,
            lineBgColor: line.bg_color,
            lineFgColor: line.fg_color,
            stationName: station.name,
            stationDisplay: station.display,
            direction: direction,
            destinationStation: destinationStation,
            nextTrains: viewModel.nextTrains
        )

        liveActivityStarted = true
        showingLiveActivityInfo = true

        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
    }

    private var widgetCornerRadius: CGFloat {
        switch widgetSize {
        case .small: return 20
        case .medium: return 20
        case .large: return 24
        }
    }

    private var widgetWidth: CGFloat {
        switch widgetSize {
        case .small: return 160
        case .medium: return 338
        case .large: return 338
        }
    }

    private var widgetHeight: CGFloat {
        switch widgetSize {
        case .small: return 160
        case .medium: return 160
        case .large: return 340
        }
    }

    // Small widget - compact view with directional background
    private var smallWidgetContent: some View {
        ZStack {
            // Directional background shape
            DirectionalBackground(direction: direction, lineColor: line.bg_color)

            VStack(spacing: 4) {
                // Top row: Line badge and updated time
                HStack {
                    Text(line.label)
                        .font(.custom("HelveticaNeue-Bold", size: 28))
                        .foregroundColor(line.fg_color)
                        .frame(width: 44, height: 44)
                        .background(Circle().fill(line.bg_color))

                    Spacer()
                }

                // Center: Train time
                if viewModel.loading && viewModel.nextTrains.isEmpty {
                    ProgressView()
                } else if !viewModel.errorMessage.isEmpty {
                    Text("--")
                        .font(.custom("HelveticaNeue-Bold", size: 28))
                        .foregroundColor(.primary)
                } else if !viewModel.nextTrains.isEmpty {
                    Text(getTimeText(for: viewModel.nextTrains[0]))
                        .font(.custom("HelveticaNeue-Bold", size: 28))
                        .foregroundColor(.primary)
                    
                    if viewModel.nextTrains.count > 1 {
                        Text(viewModel.nextTrains.dropFirst().prefix(2).map { train in
                            getAdditionalTimeText(for: train)
                        }.joined(separator: ", "))
                        .font(.custom("HelveticaNeue", size: 14))
                        .foregroundColor(.secondary)
                    }
                }

                // Bottom: Station name
                Text(station.display)
                    .font(.custom("HelveticaNeue-Bold", size: 14))
                    .foregroundColor(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
            }
            .padding(16)
        }
    }

    // Directional background shape for small widget
    private struct DirectionalBackground: View {
        let direction: String
        let lineColor: Color

        var body: some View {
            GeometryReader { geometry in
                Path { path in
                    let width = geometry.size.width
                    let height = geometry.size.height

                    if direction == "N" {
                        // Northbound - curve at top
                        path.move(to: CGPoint(x: 0, y: height * 0.3))
                        path.addQuadCurve(
                            to: CGPoint(x: width, y: height * 0.3),
                            control: CGPoint(x: width / 2, y: 0)
                        )
                        path.addLine(to: CGPoint(x: width, y: height))
                        path.addLine(to: CGPoint(x: 0, y: height))
                        path.closeSubpath()
                    } else {
                        // Southbound - curve at bottom
                        path.move(to: CGPoint(x: 0, y: 0))
                        path.addLine(to: CGPoint(x: width, y: 0))
                        path.addLine(to: CGPoint(x: width, y: height * 0.7))
                        path.addQuadCurve(
                            to: CGPoint(x: 0, y: height * 0.7),
                            control: CGPoint(x: width / 2, y: height)
                        )
                        path.closeSubpath()
                    }
                }
                .fill(lineColor.opacity(0.15))
            }
        }
    }

    // Medium widget - horizontal layout
    private var mediumWidgetContent: some View {
        HStack(spacing: 16) {
            // Left side - Line and station info
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Text(line.label)
                        .font(.custom("HelveticaNeue-Bold", size: 32))
                        .foregroundColor(line.fg_color)
                        .frame(width: 48, height: 48)
                        .background(Circle().fill(line.bg_color))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(station.display)
                            .font(.custom("HelveticaNeue-Bold", size: 16))
                            .lineLimit(2)
                        Text(DirectionHelper.getToTerminalStation(for: line.id, direction: direction, stationDataManager: stationDataManager))
                            .font(.custom("HelveticaNeue", size: 12))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
            }

            // Right side - Train times
            VStack(spacing: 4) {
                if viewModel.loading && viewModel.nextTrains.isEmpty {
                    ProgressView()
                } else if !viewModel.errorMessage.isEmpty {
                    Text("--")
                        .font(.custom("HelveticaNeue-Bold", size: 28))
                        .foregroundColor(.secondary)
                } else if !viewModel.nextTrains.isEmpty {
                    Text(getTimeText(for: viewModel.nextTrains[0]))
                        .font(.custom("HelveticaNeue-Bold", size: 28))
                        .foregroundColor(.primary)

                    if viewModel.nextTrains.count > 1 {
                        Text(viewModel.nextTrains.dropFirst().prefix(2).map { train in
                            getAdditionalTimeText(for: train)
                        }.joined(separator: ", "))
                        .font(.custom("HelveticaNeue", size: 14))
                        .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding(20)
    }

    // Large widget - vertical layout with more info
    private var largeWidgetContent: some View {
        VStack(spacing: 16) {
            // Header
            HStack(alignment: .top, spacing: 12) {
                Text(line.label)
                    .font(.custom("HelveticaNeue-Bold", size: 50))
                    .foregroundColor(line.fg_color)
                    .frame(width: 72, height: 72)
                    .background(Circle().fill(line.bg_color))

                VStack(alignment: .leading, spacing: 4) {
                    Text(station.display)
                        .font(.custom("HelveticaNeue-Bold", size: 24))
                    Text(DirectionHelper.getToTerminalStation(for: line.id, direction: direction, stationDataManager: stationDataManager))
                        .font(.custom("HelveticaNeue", size: 16))
                        .foregroundColor(.secondary)
                }
                Spacer()
            }

            Divider()

            // Train times
            if viewModel.loading && viewModel.nextTrains.isEmpty {
                Spacer()
                ProgressView()
                    .scaleEffect(1.5)
                Spacer()
            } else if !viewModel.errorMessage.isEmpty {
                Spacer()
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.orange)
                    Text(viewModel.errorMessage)
                        .font(.custom("HelveticaNeue", size: 14))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                Spacer()
            } else if !viewModel.nextTrains.isEmpty {
                VStack(spacing: 12) {
                    // Primary time
                    Text(getTimeText(for: viewModel.nextTrains[0]))
                        .font(.custom("HelveticaNeue-Bold", size: 72))
                        .foregroundColor(.primary)

                    // Additional times
                    if viewModel.nextTrains.count > 1 {
                        Text(viewModel.nextTrains.dropFirst().prefix(5).map { train in
                            getAdditionalTimeText(for: train)
                        }.joined(separator: ", "))
                        .font(.custom("HelveticaNeue", size: 20))
                        .foregroundColor(.secondary)
                    }
                }

                Spacer()
            }
        }
        .padding(24)
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

//
//  LinesBrowseView.swift
//  Now Departing
//
//  Browse subway lines, stations, and departures (iOS version)
//

import SwiftUI
import ActivityKit
import MapKit

// MARK: - Main Browse View

struct LinesBrowseView: View {
    @EnvironmentObject var stationDataManager: StationDataManager
    @EnvironmentObject var favoritesManager: FavoritesManager
    @StateObject private var navigationState = NavigationState()

    // Use shared subway line factory
    let lines = SubwayLineFactory.allLines

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
// NavigationState and NavigationRoute are imported from Shared/NavigationModels.swift

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
        MTAFeedService.shared.fetchArrivals(
            routeId: line.id,
            station: station,
            direction: direction
        ) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let arrivals):
                self.arrivalTimes = arrivals
                self.errorMessage = arrivals.isEmpty ? "No trains scheduled" : ""
                self.updateDisplayTimes()
            case .failure(let error):
                self.errorMessage = error.localizedDescription
            }
            self.loading = false
        }
    }
}

// MARK: - Times View

struct TimesView: View {
    let line: SubwayLine
    let station: Station

    @EnvironmentObject var favoritesManager: FavoritesManager
    @EnvironmentObject var stationDataManager: StationDataManager
    @EnvironmentObject var serviceAlertsManager: ServiceAlertsManager
    @StateObject private var viewModel = TimesViewModeliOS()
    @State private var direction: String
    @State private var showingLiveActivityInfo = false
    @State private var liveActivityStarted = false
    @State private var showingServiceAlerts = false

    @Environment(\.dismiss) private var dismiss

    init(line: SubwayLine, station: Station, direction: String) {
        self.line = line
        self.station = station
        self._direction = State(initialValue: direction)
    }

    private var oppositeDirection: String {
        direction == "N" ? "S" : "N"
    }

    private var isFavorited: Bool {
        favoritesManager.isFavorite(
            lineId: line.id,
            stationName: station.name,
            direction: direction
        )
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    // Service alert banner — yellow if active now, grey if only upcoming
                    if serviceAlertsManager.hasAlerts(for: line.id) {
                        let isActive = serviceAlertsManager.hasActiveAlerts(for: line.id)
                        Button(action: { showingServiceAlerts = true }) {
                            HStack(spacing: 8) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(isActive ? .yellow : .secondary)
                                Text(isActive ? "Service Change" : "Planned Service Changes")
                                    .font(.custom("HelveticaNeue-Bold", size: 15))
                                    .foregroundColor(isActive ? .yellow : .secondary)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(isActive ? .yellow.opacity(0.7) : .secondary.opacity(0.7))
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(isActive ? Color.yellow.opacity(0.15) : Color.secondary.opacity(0.1))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(isActive ? Color.yellow.opacity(0.4) : Color.secondary.opacity(0.25), lineWidth: 1)
                            )
                            .cornerRadius(12)
                        }
                        .padding(.horizontal, 24)
                    }

                    // Header: line badge + station + direction terminal
                    HStack(alignment: .top, spacing: 12) {
                        Text(line.label)
                            .font(.custom("HelveticaNeue-Bold", size: 50))
                            .foregroundColor(line.fg_color)
                            .frame(width: 72, height: 72)
                            .background(Circle().fill(line.bg_color))

                        VStack(alignment: .leading, spacing: 4) {
                            Text(station.display)
                                .font(.custom("HelveticaNeue-Bold", size: 24))
                                .foregroundColor(.white)
                            Text(DirectionHelper.getToTerminalStation(for: line.id, direction: direction, stationDataManager: stationDataManager))
                                .font(.custom("HelveticaNeue", size: 16))
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 8)

                    // Train times
                    if viewModel.loading && viewModel.nextTrains.isEmpty {
                        ProgressView()
                            .scaleEffect(1.5)
                            .padding(.vertical, 48)
                    } else if !viewModel.errorMessage.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 40))
                                .foregroundColor(.orange)
                            Text(viewModel.errorMessage)
                                .font(.custom("HelveticaNeue", size: 14))
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.vertical, 48)
                    } else if !viewModel.nextTrains.isEmpty {
                        VStack(spacing: 12) {
                            Text(getTimeText(for: viewModel.nextTrains[0]))
                                .font(.custom("HelveticaNeue-Bold", size: 80))
                                .foregroundColor(.white)

                            if viewModel.nextTrains.count > 1 {
                                Text(viewModel.nextTrains.dropFirst().prefix(5).map { train in
                                    getAdditionalTimeText(for: train)
                                }.joined(separator: ", "))
                                .font(.custom("HelveticaNeue", size: 20))
                                .foregroundColor(.secondary)
                            }
                        }
                        .padding(.horizontal, 24)
                    }

                    // Action buttons
                    VStack(spacing: 12) {
                        Button(action: { openDirectionsToStation() }) {
                            HStack(spacing: 8) {
                                Image(systemName: "map.fill")
                                Text("Get Directions")
                            }
                            .font(.custom("HelveticaNeue-Bold", size: 18))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(.ultraThinMaterial)
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
                            )
                            .cornerRadius(14)
                        }

                        Button(action: {
                            if isFavorited { removeFavorite() } else { addToFavorites() }
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
                                    .stroke(isFavorited ? Color.red.opacity(0.5) : Color.white.opacity(0.2), lineWidth: 1)
                            )
                            .cornerRadius(14)
                        }

                        if #available(iOS 16.2, *), LiveActivityManager.isSupported() {
                            Button(action: { toggleLiveActivity() }) {
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
                                        .stroke(liveActivityStarted ? Color.red.opacity(0.5) : Color.white.opacity(0.2), lineWidth: 1)
                                )
                                .cornerRadius(14)
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 40)
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.black, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .principal) {
                HStack(spacing: 8) {
                    Text(line.label)
                        .font(.custom("HelveticaNeue-Bold", size: 22))
                        .foregroundColor(line.fg_color)
                        .frame(width: 34, height: 34)
                        .background(Circle().fill(line.bg_color))
                    Text(station.display)
                        .font(.custom("HelveticaNeue-Bold", size: 16))
                        .foregroundColor(.white)
                        .lineLimit(1)
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: toggleDirection) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                }
            }
        }
        .onAppear {
            viewModel.startFetchingTimes(for: line, station: station, direction: direction)
            serviceAlertsManager.fetchAlerts()
        }
        .onChange(of: direction) { newDirection in
            viewModel.stopFetchingTimes()
            viewModel.startFetchingTimes(for: line, station: station, direction: newDirection)
            if liveActivityStarted {
                if #available(iOS 16.2, *) {
                    LiveActivityManager.shared.endActivity()
                }
                liveActivityStarted = false
            }
        }
        .sheet(isPresented: $showingServiceAlerts) {
            ServiceAlertsSheet(alerts: serviceAlertsManager.alerts(for: line.id), line: line)
        }
        .onDisappear {
            viewModel.stopFetchingTimes()
            if liveActivityStarted {
                if #available(iOS 16.2, *) {
                    LiveActivityManager.shared.endActivity()
                }
                liveActivityStarted = false
            }
        }
        .onReceive(viewModel.$nextTrains) { trains in
            if liveActivityStarted && !trains.isEmpty {
                if #available(iOS 16.2, *) {
                    LiveActivityManager.shared.updateActivity(nextTrains: trains)
                }
            }
        }
        .alert("Live Activity for StandBy", isPresented: $showingLiveActivityInfo) {
            Button("Got It", role: .cancel) {}
        } message: {
            Text("Live Activity started! Place your iPhone horizontally on a charger to see it in StandBy mode.\n\nThe display will show real-time train arrivals and automatically update.")
        }
    }

    private func toggleDirection() {
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        direction = oppositeDirection
    }

    @available(iOS 16.2, *)
    private func toggleLiveActivity() {
        if liveActivityStarted {
            LiveActivityManager.shared.endActivity()
            liveActivityStarted = false
        } else {
            startLiveActivity()
        }
    }

    private func openDirectionsToStation() {
        guard let lat = station.latitude, let lon = station.longitude else { return }
        let coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon)
        let placemark = MKPlacemark(coordinate: coordinate)
        let mapItem = MKMapItem(placemark: placemark)
        mapItem.name = station.display
        mapItem.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeWalking])
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

    private func getTimeText(for train: (minutes: Int, seconds: Int)) -> String {
        return TimeFormatter.formatArrivalTime(minutes: train.minutes, seconds: train.seconds, fullText: true)
    }

    private func getAdditionalTimeText(for train: (minutes: Int, seconds: Int)) -> String {
        return TimeFormatter.formatAdditionalTime(minutes: train.minutes, seconds: train.seconds)
    }

    private func addToFavorites() {
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()

        favoritesManager.addFavorite(
            lineId: line.id,
            stationName: station.name,
            stationDisplay: station.display,
            direction: direction,
            gtfsStopId: station.gtfsStopId
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

// MARK: - Service Alerts Sheet

struct ServiceAlertsSheet: View {
    let alerts: [ServiceAlert]
    let line: SubwayLine
    @Environment(\.dismiss) private var dismiss
    @State private var upcomingExpanded = false
    @State private var visibleUpcomingCount = 0

    private var activeAlerts: [ServiceAlert]   { alerts.filter { $0.isCurrentlyActive } }
    private var upcomingAlerts: [ServiceAlert] { alerts.filter { !$0.isCurrentlyActive } }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Active alerts
                    ForEach(activeAlerts) { alert in
                        alertCard(alert)
                    }

                    // Upcoming alerts — collapsible with staggered reveal
                    if !upcomingAlerts.isEmpty {
                        Button(action: toggleUpcoming) {
                            HStack(spacing: 6) {
                                Text(upcomingExpanded
                                     ? "Hide upcoming (\(upcomingAlerts.count))"
                                     : "Show upcoming (\(upcomingAlerts.count))")
                                    .font(.custom("HelveticaNeue-Bold", size: 14))
                                    .foregroundColor(.secondary)
                                Spacer()
                                Image(systemName: upcomingExpanded ? "chevron.up" : "chevron.down")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal, 4)
                        }

                        if upcomingExpanded {
                            ForEach(Array(upcomingAlerts.enumerated()), id: \.element.id) { index, alert in
                                alertCard(alert)
                                    .opacity(index < visibleUpcomingCount ? 1 : 0)
                            }
                        }
                    }
                }
                .padding(20)
            }
            .navigationTitle("Service Changes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    HStack(spacing: 8) {
                        Text(line.label)
                            .font(.custom("HelveticaNeue-Bold", size: 24))
                            .foregroundColor(line.fg_color)
                            .frame(width: 36, height: 36)
                            .background(Circle().fill(line.bg_color))
                        Text("Service Changes")
                            .font(.custom("HelveticaNeue-Bold", size: 17))
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(.custom("HelveticaNeue-Bold", size: 17))
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func toggleUpcoming() {
        if upcomingExpanded {
            withAnimation(.easeIn(duration: 0.15)) {
                upcomingExpanded = false
                visibleUpcomingCount = 0
            }
        } else {
            upcomingExpanded = true
            for i in 0..<upcomingAlerts.count {
                DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.07) {
                    withAnimation(.easeOut(duration: 0.22)) {
                        visibleUpcomingCount = i + 1
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func alertCard(_ alert: ServiceAlert) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Top row: effect badge left, timing right
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.yellow)
                Text(alert.effect.displayText)
                    .font(.custom("HelveticaNeue-Bold", size: 13))
                    .foregroundColor(.yellow)
                Spacer()
                if let timing = alert.activePeriodSummary {
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                        Text(timing)
                            .font(.custom("HelveticaNeue", size: 13))
                            .foregroundColor(.secondary)
                    }
                }
            }
            alertInlineText(alert.headerText, fontSize: 17)
                .font(.custom("HelveticaNeue-Bold", size: 17))
                .foregroundColor(.primary)
                .fixedSize(horizontal: false, vertical: true)
            if !alert.descriptionText.isEmpty {
                alertInlineText(alert.descriptionText, fontSize: 15)
                    .font(.custom("HelveticaNeue", size: 15))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.yellow.opacity(0.08))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.yellow.opacity(0.3), lineWidth: 1)
        )
        .cornerRadius(12)
    }
}

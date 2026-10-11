//
//  LinePeekView.swift
//  Now Departing
//
//  The closest station on a line, its distance and walking time, and the next
//  trains in both directions — laid out like a station section on the Nearby
//  page. Shown as the long-press preview on the Lines page and at the top of a
//  line's station list.
//

import SwiftUI
import CoreLocation
import Combine

// MARK: - Closest Station

enum ClosestStation {
    /// The station on `line` nearest to `location`, skipping stations without
    /// coordinates or a GTFS stop ID. Prefers one with live times, so a stop
    /// trains are skipping isn't picked; when none have times (say, a line that
    /// doesn't run overnight), still the closest, so its times read "No trains".
    static func find(for line: SubwayLine, near location: CLLocation, in stationDataManager: StationDataManager) -> (station: Station, meters: Double)? {
        guard let stations = stationDataManager.stations(for: line.id) else { return nil }
        let candidates = stations.compactMap { station -> (station: Station, meters: Double)? in
            guard station.gtfsStopId?.isEmpty == false,
                  let lat = station.latitude,
                  let lon = station.longitude else { return nil }
            return (station, location.distance(from: CLLocation(latitude: lat, longitude: lon)))
        }
        let running = candidates.filter { $0.station.hasAvailableTimes != false }
        return (running.isEmpty ? candidates : running).min { $0.meters < $1.meters }
    }

    /// Farther than this, or a longer walk than this (say, across a river), the
    /// closest station isn't worth a section at the top of the station list.
    static let stationListMaxMeters = 2 * 1609.344
    static let stationListMaxWalkSeconds: TimeInterval = 40 * 60

    /// The closest station if it's within two miles, before checking the walk.
    static func findWithinStationListDistance(for line: SubwayLine, near location: CLLocation?, in stationDataManager: StationDataManager) -> (station: Station, meters: Double)? {
        guard let location = location,
              let closest = find(for: line, near: location, in: stationDataManager),
              closest.meters <= stationListMaxMeters else { return nil }
        return closest
    }

    /// The closest station for the top of the station list: within two miles
    /// and a 40-minute walk. Waits for Maps' walking time rather than showing
    /// on the estimate and then disappearing; falls back to the estimate only
    /// if Maps can't answer.
    static func findForStationList(for line: SubwayLine, near location: CLLocation?, in stationDataManager: StationDataManager) -> (station: Station, meters: Double)? {
        guard let closest = findWithinStationListDistance(for: line, near: location, in: stationDataManager),
              let coordinate = closest.station.coordinate else { return nil }
        let walkTimes = WalkTimes.shared
        let walk: TimeInterval
        if let seconds = walkTimes.seconds(to: coordinate) {
            walk = seconds
        } else if walkTimes.hasFailed(to: coordinate) {
            walk = WalkTime.estimatedSeconds(closest.meters)
        } else {
            return nil  // still waiting on Maps
        }
        return walk <= stationListMaxWalkSeconds ? closest : nil
    }

    static func formatDistance(_ meters: Double) -> String {
        let feet = meters * 3.28084
        if feet < 1000 {
            return "\(Int(feet))ft"
        } else {
            let miles = feet / 5280
            return String(format: "%.1fmi", miles)
        }
    }
}

extension Station {
    var coordinate: CLLocationCoordinate2D? {
        guard let lat = latitude, let lon = longitude else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }
}

// MARK: - Closest Station View Model

class ClosestStationViewModel: ObservableObject {
    @Published var arrivals: [String: [MTAArrival]] = [:]
    @Published var loaded: Set<String> = []

    func fetchArrivals(line: SubwayLine, station: Station) {
        for direction in ["N", "S"] {
            MTAFeedService.shared.fetchTrainArrivals(
                routeId: line.id,
                station: station,
                direction: direction
            ) { [weak self] result in
                guard let self = self else { return }
                if case .success(let trains) = result {
                    self.arrivals[direction] = trains
                }
                self.loaded.insert(direction)
            }
        }
    }
}

// MARK: - Closest Station Header

private struct ClosestStationHeader: View {
    let closest: (station: Station, meters: Double)

    @EnvironmentObject var locationManager: LocationManager

    var body: some View {
        WalkingStationHeader(
            stationDisplay: closest.station.display,
            distanceText: ClosestStation.formatDistance(closest.meters),
            meters: closest.meters,
            coordinate: closest.station.coordinate,
            origin: locationManager.location
        )
    }
}

// MARK: - Peek View

struct LinePeekView: View {
    let line: SubwayLine

    @EnvironmentObject var stationDataManager: StationDataManager
    @EnvironmentObject var locationManager: LocationManager
    @StateObject private var viewModel = ClosestStationViewModel()
    @State private var currentTime = Date()

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var closest: (station: Station, meters: Double)? {
        guard let location = locationManager.location else { return nil }
        return ClosestStation.find(for: line, near: location, in: stationDataManager)
    }

    var body: some View {
        Group {
            if let closest = closest {
                VStack(alignment: .leading, spacing: 12) {
                    ClosestStationHeader(closest: closest)

                    ForEach(["N", "S"], id: \.self) { direction in
                        ClosestDirectionRow(
                            line: line,
                            direction: direction,
                            arrivals: viewModel.arrivals[direction] ?? [],
                            loaded: viewModel.loaded.contains(direction),
                            currentTime: currentTime
                        )
                        .peekTapTarget(NavigationRoute.times(line, closest.station, direction))
                    }
                }
                // Take the height long station names need; the preview otherwise
                // truncates them at two lines
                .fixedSize(horizontal: false, vertical: true)
                .onAppear {
                    viewModel.fetchArrivals(line: line, station: closest.station)
                }
            } else {
                // Say why there's nothing to show
                HStack(spacing: 12) {
                    Image(systemName: locationManager.location == nil ? "location.slash" : "questionmark.circle")
                        .font(.system(size: 22))
                        .foregroundColor(.secondary)
                    Text(locationManager.location == nil
                         ? "Turn on location on the Nearby page to see the closest station."
                         : "Couldn't find a station on the \(line.label).")
                        .font(.custom("HelveticaNeue", size: 16))
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(20)
        .frame(width: UIScreen.main.bounds.width - 32, alignment: .leading)
        .background(Color(UIColor.systemBackground))
        .onReceive(timer) { time in
            currentTime = time
        }
    }
}

// MARK: - Station List Section

/// The closest station as the first section of a line's station list. Each
/// direction opens its times page.
struct ClosestStationSection: View {
    let line: SubwayLine

    @EnvironmentObject var stationDataManager: StationDataManager
    @EnvironmentObject var locationManager: LocationManager
    @StateObject private var viewModel = ClosestStationViewModel()
    @ObservedObject private var walkTimes = WalkTimes.shared  // the cutoff depends on it
    @State private var currentTime = Date()

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    // The list can stay open, unlike the peek, so keep its times fresh
    private let refreshTimer = Timer.publish(every: 30, on: .main, in: .common).autoconnect()

    private var closest: (station: Station, meters: Double)? {
        ClosestStation.findForStationList(for: line, near: locationManager.location, in: stationDataManager)
    }

    var body: some View {
        if let closest = closest {
            Section {
                ForEach(["N", "S"], id: \.self) { direction in
                    NavigationLink(value: NavigationRoute.times(line, closest.station, direction)) {
                        ClosestDirectionRow(
                            line: line,
                            direction: direction,
                            arrivals: viewModel.arrivals[direction] ?? [],
                            loaded: viewModel.loaded.contains(direction),
                            currentTime: currentTime
                        )
                    }
                }
            } header: {
                VStack(alignment: .leading, spacing: 8) {
                    StationListCaption(text: "Closest")
                    ClosestStationHeader(closest: closest)
                }
            }
            // Re-fetch when moving brings a different station closest
            .task(id: closest.station.gtfsStopId) {
                viewModel.fetchArrivals(line: line, station: closest.station)
            }
            .onReceive(timer) { time in
                currentTime = time
            }
            .onReceive(refreshTimer) { _ in
                viewModel.fetchArrivals(line: line, station: closest.station)
            }
        }
    }
}

/// Small label over a section of the station list.
struct StationListCaption: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.custom("HelveticaNeue-Bold", size: 14))
            .foregroundColor(.secondary)
            .textCase(.none)
    }
}

// MARK: - Direction Row

/// One direction at the closest station, with the same metrics as the Nearby
/// page's ConsolidatedTrainRow.
private struct ClosestDirectionRow: View {
    let line: SubwayLine
    let direction: String
    let arrivals: [MTAArrival]
    let loaded: Bool
    let currentTime: Date

    @EnvironmentObject var stationDataManager: StationDataManager
    @EnvironmentObject var locationManager: LocationManager

    private var upcoming: [MTAArrival] {
        arrivals.filter { $0.time.timeIntervalSince(currentTime) > -30 }
    }

    var body: some View {
        HStack(spacing: 12) {
            Text(line.label)
                .font(.custom("HelveticaNeue-Bold", size: 32))
                .foregroundColor(line.fg_color)
                .frame(width: 48, height: 48)
                .background(Circle().fill(line.bg_color))

            VStack(alignment: .leading, spacing: 2) {
                Text(LocationBasedDirectionHelper.getContextualDestination(
                    for: line.id,
                    direction: direction,
                    currentLocation: locationManager.location
                ))
                    .font(.custom("HelveticaNeue-Bold", size: 20))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Text(DirectionHelper.getToTerminalStation(
                    for: line.id,
                    direction: direction,
                    stationDataManager: stationDataManager
                ))
                    .font(.custom("HelveticaNeue", size: 14))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                if let first = upcoming.first {
                    ExpressMark.label(timeText(first.time, fullText: true), isExpress: first.isExpress, color: line.bg_color, fontSize: 26)
                        .font(.custom("HelveticaNeue-Bold", size: 26))
                        .foregroundColor(.primary)

                    if upcoming.count > 1 {
                        ExpressMark.list(upcoming.dropFirst().prefix(2).map { train in
                            (text: timeText(train.time), isExpress: train.isExpress)
                        }, color: line.bg_color, fontSize: 14)
                        .font(.custom("HelveticaNeue", size: 14))
                        .foregroundColor(.secondary)
                    }
                } else if loaded {
                    Text("No trains")
                        .font(.custom("HelveticaNeue", size: 16))
                        .foregroundColor(.secondary)
                } else {
                    ProgressView()
                }
            }
        }
        .padding(.vertical, 4)
    }

    /// Matches NearbyTrain.getLiveTimeText.
    private func timeText(_ time: Date, fullText: Bool = false) -> String {
        let totalSeconds = Int(time.timeIntervalSince(currentTime))
        if totalSeconds <= 30 { return "Now" }
        if totalSeconds < 60 { return fullText ? "Arriving" : "Soon" }
        return fullText ? "\(totalSeconds / 60) min" : "\(totalSeconds / 60)m"
    }
}

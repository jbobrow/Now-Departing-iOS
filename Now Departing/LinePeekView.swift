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
import MapKit

// MARK: - Closest Station

enum ClosestStation {
    /// The station on `line` nearest to `location`, skipping stations without
    /// coordinates, a GTFS stop ID, or live times.
    static func find(for line: SubwayLine, near location: CLLocation, in stationDataManager: StationDataManager) -> (station: Station, meters: Double)? {
        guard let stations = stationDataManager.stations(for: line.id) else { return nil }
        return stations
            .compactMap { station -> (station: Station, meters: Double)? in
                guard station.hasAvailableTimes != false,
                      station.gtfsStopId?.isEmpty == false,
                      let lat = station.latitude,
                      let lon = station.longitude else { return nil }
                return (station, location.distance(from: CLLocation(latitude: lat, longitude: lon)))
            }
            .min { $0.meters < $1.meters }
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

    /// Rough walking time from straight-line distance, shown until Maps answers:
    /// streets add about a third to the crow-flies distance, walked at 1.4 m/s.
    static func estimatedWalkSeconds(_ meters: Double) -> TimeInterval {
        meters * 1.3 / 1.4
    }

    /// The walking-figure symbol followed by the minutes, e.g. "33 min".
    static func formatWalk(_ seconds: TimeInterval) -> Text {
        let minutes = max(1, Int((seconds / 60).rounded()))
        return (Text(Image(systemName: "figure.walk")) + Text(" \(minutes) min"))
            .accessibilityLabel("\(minutes) minute walk")
    }
}

// MARK: - Closest Station View Model

class ClosestStationViewModel: ObservableObject {
    @Published var arrivals: [String: [MTAArrival]] = [:]
    @Published var loaded: Set<String> = []
    /// Walking time from Maps; nil until it answers (or if it can't).
    @Published var walkSeconds: TimeInterval?

    private var directions: MKDirections?

    func fetch(line: SubwayLine, station: Station, from location: CLLocation) {
        fetchWalkTime(to: station, from: location)
        fetchArrivals(line: line, station: station)
    }

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

    private func fetchWalkTime(to station: Station, from location: CLLocation) {
        guard let lat = station.latitude, let lon = station.longitude else { return }
        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: location.coordinate))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon)))
        request.transportType = .walking

        directions?.cancel()
        let directions = MKDirections(request: request)
        self.directions = directions
        directions.calculateETA { [weak self] response, _ in
            guard let response = response else { return }
            DispatchQueue.main.async {
                self?.walkSeconds = response.expectedTravelTime
            }
        }
    }

    deinit {
        directions?.cancel()
    }
}

// MARK: - Closest Station Header

/// The Nearby page's station header, with the walking time under the distance.
private struct ClosestStationHeader: View {
    let closest: (station: Station, meters: Double)
    let walkSeconds: TimeInterval?

    var body: some View {
        NearbyView.StationHeader(
            stationDisplay: closest.station.display,
            distanceText: ClosestStation.formatDistance(closest.meters),
            detailText: ClosestStation.formatWalk(walkSeconds ?? ClosestStation.estimatedWalkSeconds(closest.meters))
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
                    ClosestStationHeader(closest: closest, walkSeconds: viewModel.walkSeconds)

                    ForEach(["N", "S"], id: \.self) { direction in
                        ClosestDirectionRow(
                            line: line,
                            direction: direction,
                            arrivals: viewModel.arrivals[direction] ?? [],
                            loaded: viewModel.loaded.contains(direction),
                            currentTime: currentTime
                        )
                    }
                }
                .onAppear {
                    if let location = locationManager.location {
                        viewModel.fetch(line: line, station: closest.station, from: location)
                    }
                }
            } else {
                // No location yet — say why there's nothing to show
                HStack(spacing: 12) {
                    Image(systemName: "location.slash")
                        .font(.system(size: 22))
                        .foregroundColor(.secondary)
                    Text("Turn on location on the Nearby page to see the closest station.")
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
    @State private var currentTime = Date()

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    // The list can stay open, unlike the peek, so keep its times fresh
    private let refreshTimer = Timer.publish(every: 30, on: .main, in: .common).autoconnect()

    private var closest: (station: Station, meters: Double)? {
        guard let location = locationManager.location else { return nil }
        return ClosestStation.find(for: line, near: location, in: stationDataManager)
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
                    ClosestStationHeader(closest: closest, walkSeconds: viewModel.walkSeconds)
                }
            }
            // Re-fetch when moving brings a different station closest
            .task(id: closest.station.gtfsStopId) {
                if let location = locationManager.location {
                    viewModel.fetch(line: line, station: closest.station, from: location)
                }
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

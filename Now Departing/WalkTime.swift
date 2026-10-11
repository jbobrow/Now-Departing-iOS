//
//  WalkTime.swift
//  Now Departing
//
//  Walking time to a station, from Maps, shared by every station header that
//  shows one (Nearby, the line peek, the top of a line's station list).
//

import SwiftUI
import CoreLocation
import Combine
import MapKit

// MARK: - Formatting

enum WalkTime {
    /// Rough walking time from straight-line distance, shown until Maps answers:
    /// streets add about a third to the crow-flies distance, walked at 1.4 m/s.
    static func estimatedSeconds(_ meters: Double) -> TimeInterval {
        meters * 1.3 / 1.4
    }

    /// The walking-figure symbol followed by the minutes, e.g. "33 min".
    static func format(_ seconds: TimeInterval) -> Text {
        let minutes = max(1, Int((seconds / 60).rounded()))
        return (Text(Image(systemName: "figure.walk")) + Text(" \(minutes) min"))
            .accessibilityLabel("\(minutes) minute walk")
    }
}

// MARK: - Cache

/// Walking times from Maps, keyed by station coordinate. Asks again once you've
/// moved about a block from where a time was measured, so Nearby's frequent
/// location updates don't turn into a stream of requests.
final class WalkTimes: ObservableObject {
    static let shared = WalkTimes()

    @Published private(set) var seconds: [String: TimeInterval] = [:]
    /// Stations Maps couldn't give a time for (offline, throttled), so callers
    /// waiting on an answer can fall back to the estimate.
    @Published private(set) var failed: Set<String> = []

    private var measuredFrom: [String: CLLocation] = [:]
    private var inFlight: Set<String> = []
    private let remeasureMeters: CLLocationDistance = 100

    static func key(for coordinate: CLLocationCoordinate2D) -> String {
        String(format: "%.5f,%.5f", coordinate.latitude, coordinate.longitude)
    }

    /// Changes when the origin moves about 100m, for `.task(id:)` modifiers that
    /// call `request` so it re-runs as you walk.
    static func requestID(to coordinate: CLLocationCoordinate2D?, from origin: CLLocation?) -> String {
        guard let origin = origin, let coordinate = coordinate else { return "" }
        return key(for: coordinate) + String(format: "@%.3f,%.3f", origin.coordinate.latitude, origin.coordinate.longitude)
    }

    /// The last walking time to `coordinate`, which may have been measured from
    /// up to a block away; nil if Maps hasn't answered yet.
    func seconds(to coordinate: CLLocationCoordinate2D) -> TimeInterval? {
        seconds[Self.key(for: coordinate)]
    }

    /// Whether the last request for `coordinate` failed with no earlier time to
    /// fall back on.
    func hasFailed(to coordinate: CLLocationCoordinate2D) -> Bool {
        failed.contains(Self.key(for: coordinate))
    }

    /// Asks Maps for the walking time from `origin` to `coordinate`, unless
    /// there's already one measured nearby or a request on the way.
    func request(to coordinate: CLLocationCoordinate2D, from origin: CLLocation) {
        let key = Self.key(for: coordinate)
        guard !inFlight.contains(key) else { return }
        if let from = measuredFrom[key], from.distance(from: origin) < remeasureMeters { return }

        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: origin.coordinate))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: coordinate))
        request.transportType = .walking

        inFlight.insert(key)
        MKDirections(request: request).calculateETA { [weak self] response, _ in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.inFlight.remove(key)
                guard let response = response else {
                    if self.seconds[key] == nil { self.failed.insert(key) }
                    return
                }
                // Animated so a section waiting on this slides in, and an
                // estimate settling into Maps' time crossfades
                withAnimation {
                    self.seconds[key] = response.expectedTravelTime
                    self.failed.remove(key)
                }
                self.measuredFrom[key] = origin
            }
        }
    }
}

// MARK: - Header

/// The Nearby page's station header with the walking time under the distance:
/// Maps' time once it answers, an estimate from `meters` until then.
struct WalkingStationHeader: View {
    let stationDisplay: String
    let distanceText: String
    let meters: Double
    let coordinate: CLLocationCoordinate2D?
    let origin: CLLocation?

    @ObservedObject private var walkTimes = WalkTimes.shared

    private var walkSeconds: TimeInterval {
        coordinate.flatMap { walkTimes.seconds(to: $0) } ?? WalkTime.estimatedSeconds(meters)
    }

    var body: some View {
        NearbyView.StationHeader(
            stationDisplay: stationDisplay,
            distanceText: distanceText,
            detailText: WalkTime.format(walkSeconds)
        )
        .task(id: WalkTimes.requestID(to: coordinate, from: origin)) {
            guard let origin = origin, let coordinate = coordinate else { return }
            walkTimes.request(to: coordinate, from: origin)
        }
    }
}

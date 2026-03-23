//
//  MTAFeedService.swift
//  Now Departing
//
//  High-level service that replaces the third-party api.wheresthefuckingtrain.com
//  JSON API with direct calls to the MTA's official GTFS-RT binary feeds.
//
//  ## How it works
//
//  1.  The MTA publishes GTFS-RT "trip update" feeds (one per group of lines).
//      Each feed is a binary Protocol Buffer file containing real-time arrival
//      predictions for every in-service train in that group.
//
//  2.  `MTAFeedService` fetches the relevant feed(s), parses them with
//      `GTFSRTParser`, and returns the subset of arrivals the caller wants.
//
//  3.  GTFS-RT identifies stations by *stop ID*, e.g. "127N" for the
//      northbound 1/2/3 platform at Times Square.  To translate between the
//      user-visible station names stored in `stations.json` and GTFS stop IDs,
//      each `Station` now carries an optional `gtfsStopId` field (the *parent*
//      station ID, without the N/S direction suffix).
//
//      To populate `gtfsStopId` values in `stations.json`, run the helper
//      script at `scripts/generate_gtfs_mapping.py` once against the MTA's
//      GTFS static data.  See that script for full instructions.
//
//  ## Station-lookup approach
//
//  •  For **by-station** queries (`TimesViewModel`):
//     Use `Station.gtfsStopId` + direction suffix ("N" or "S") to find the
//     matching stop in the parsed feed.
//
//  •  For **nearby-train** queries (`NearbyTrainsManager`):
//     Use `Station.location` (lat/lon from `stations.json`) to compute the
//     distance from the user, then pull arrivals for all stops within the
//     desired radius from every feed group.
//

import Foundation
import CoreLocation

// MARK: - Nearby Arrival (target-agnostic intermediate type)

/// Raw result from `fetchNearbyArrivals`.  Converted to `NearbyTrain` by
/// `NearbyTrainsManager`, which is the only target that needs the richer type.
struct MTANearbyArrival {
    let routeId: String
    let gtfsStopId: String?
    let stationName: String
    let stationDisplay: String
    let direction: String    // "N" or "S"
    let arrivalTime: Date
    let distanceInMeters: Double
    let latitude: Double?
    let longitude: Double?
}


enum MTAFeedError: Error, LocalizedError {
    case missingStopId(stationName: String)
    case networkError(Error)
    case httpError(Int)
    case parseError(Error)
    case noData

    var errorDescription: String? {
        switch self {
        case .missingStopId(let name):
            return "No GTFS stop ID found for station \"\(name)\". Update stations.json."
        case .networkError(let e):
            return "Network error: \(e.localizedDescription)"
        case .httpError(let code):
            return "MTA server returned HTTP \(code)."
        case .parseError(let e):
            return "Failed to parse GTFS-RT feed: \(e.localizedDescription)"
        case .noData:
            return "No data received from MTA feed."
        }
    }
}

// MARK: - Service

/// Fetches and parses MTA GTFS-RT feeds, returning arrival times compatible
/// with the existing `TimesViewModel` and `NearbyTrainsManager` interfaces.
final class MTAFeedService {

    static let shared = MTAFeedService()

    private let parser = GTFSRTParser()
    private let session: URLSession

    // Simple in-memory cache: feed URL → (fetchDate, parsedUpdates)
    private var cache: [URL: (date: Date, updates: [GTFSTripUpdate])] = [:]
    private var alertCache: [URL: (date: Date, alerts: [GTFSAlert])] = [:]
    private let cacheTTL: TimeInterval = 30  // seconds; GTFS-RT feeds refresh ~every 30s

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 30
        session = URLSession(configuration: config)
    }

    // MARK: - By-Station Query (replaces /by-route/<lineId>)

    /// Fetches arrival times at a specific station for a given route and direction.
    ///
    /// - Parameters:
    ///   - routeId:     Subway route ID, e.g. "1", "A", "L".
    ///   - station:     The `Station` value from `stations.json`.  Its
    ///                  `gtfsStopId` must be non-nil for the lookup to work.
    ///   - direction:   "N" (northbound / uptown) or "S" (southbound / downtown).
    ///   - completion:  Called on the main thread with arrival `Date` values or an error.
    func fetchArrivals(
        routeId: String,
        station: Station,
        direction: String,
        completion: @escaping (Result<[Date], MTAFeedError>) -> Void
    ) {
        guard let parentStopId = station.gtfsStopId, !parentStopId.isEmpty else {
            DispatchQueue.main.async {
                completion(.failure(.missingStopId(stationName: station.name)))
            }
            return
        }

        let targetStopId = parentStopId + direction  // e.g. "127" + "N" → "127N"

        fetchFeed(for: routeId) { result in
            switch result {
            case .failure(let error):
                DispatchQueue.main.async { completion(.failure(error)) }

            case .success(let updates):
                let now = Date()
                let arrivals: [Date] = updates
                    .filter { $0.routeId == routeId }
                    .flatMap { update -> [Date] in
                        update.stopTimeUpdates
                            .filter { $0.stopId == targetStopId }
                            .compactMap { $0.arrivalTime ?? $0.departureTime }
                    }
                    .filter { $0 > now }
                    .sorted()

                DispatchQueue.main.async { completion(.success(arrivals)) }
            }
        }
    }

    // MARK: - By-Location Query (replaces /by-location?lat=…&lon=…)

    /// Fetches all arrivals within `radiusMeters` of `location` across every
    /// feed group and returns raw `MTANearbyArrival` values.
    /// `NearbyTrainsManager` converts these to the richer `NearbyTrain` type.
    ///
    /// - Parameters:
    ///   - location:       The user's current `CLLocation`.
    ///   - radiusMeters:   Search radius (default 800 m ≈ 0.5 miles).
    ///   - stationsByLine: The full station dictionary from `StationDataManager`.
    ///   - completion:     Called on the main thread.
    func fetchNearbyArrivals(
        location: CLLocation,
    radiusMeters: Double = 1600,    // ~ 1 mile radius
        stationsByLine: [String: [Station]],
        completion: @escaping (Result<[MTANearbyArrival], MTAFeedError>) -> Void
    ) {
        // Collect all unique stations that have a GTFS stop ID and a known location,
        // and are within the search radius.
        struct NearbyStop {
            let station: Station
            let distance: Double
            let stationLocation: CLLocation
        }

        var nearbyStops: [NearbyStop] = []
        var seenStationNames = Set<String>()

        for stations in stationsByLine.values {
            for station in stations {
                guard !seenStationNames.contains(station.name),
                      station.gtfsStopId != nil,
                      let lat = station.latitude,
                      let lon = station.longitude else { continue }

                let stationLocation = CLLocation(latitude: lat, longitude: lon)
                let distance = location.distance(from: stationLocation)
                if distance <= radiusMeters {
                    nearbyStops.append(NearbyStop(station: station, distance: distance, stationLocation: stationLocation))
                    seenStationNames.insert(station.name)
                }
            }
        }

        guard !nearbyStops.isEmpty else {
            DispatchQueue.main.async { completion(.success([MTANearbyArrival]())) }
            return
        }

        // Determine which GTFS-RT feeds we need.
        let allRoutes = stationsByLine.keys.map { $0 }
        let feedURLs = MTAFeedConfiguration.feedURLs(for: allRoutes)

        // Fetch all required feeds concurrently.
        let group = DispatchGroup()
        var allUpdates: [GTFSTripUpdate] = []
        var firstError: MTAFeedError?
        let lock = NSLock()

        for url in feedURLs {
            group.enter()
            fetchFeedData(url: url) { result in
                defer { group.leave() }
                switch result {
                case .success(let updates):
                    lock.lock()
                    allUpdates.append(contentsOf: updates)
                    lock.unlock()
                case .failure(let error):
                    lock.lock()
                    if firstError == nil { firstError = error }
                    lock.unlock()
                }
            }
        }

        group.notify(queue: .global(qos: .userInitiated)) {
            if allUpdates.isEmpty, let error = firstError {
                DispatchQueue.main.async { completion(.failure(error)) }
                return
            }

            let now = Date()
            var results: [MTANearbyArrival] = []

            for stop in nearbyStops {
                for direction in ["N", "S"] {
                    guard let parentId = stop.station.gtfsStopId else { continue }
                    let stopId = parentId + direction

                    let arrivals: [(route: String, time: Date)] = allUpdates
                        .flatMap { update -> [(String, Date)] in
                            update.stopTimeUpdates
                                .filter { $0.stopId == stopId }
                                .compactMap { stu -> (String, Date)? in
                                    guard let t = stu.arrivalTime ?? stu.departureTime else { return nil }
                                    return (update.routeId, t)
                                }
                        }
                        .filter { $0.1 > now }

                    for (routeId, arrivalTime) in arrivals {
                        let minutesAway = Int(arrivalTime.timeIntervalSinceNow / 60)
                        guard minutesAway >= 0, minutesAway <= 30 else { continue }

                        results.append(MTANearbyArrival(
                            routeId: routeId,
                            gtfsStopId: stop.station.gtfsStopId,
                            stationName: stop.station.name,
                            stationDisplay: stop.station.display,
                            direction: direction,
                            arrivalTime: arrivalTime,
                            distanceInMeters: stop.distance,
                            latitude: stop.station.latitude,
                            longitude: stop.station.longitude
                        ))
                    }
                }
            }

            // Sort: primarily by arrival time; secondarily by distance when times
            // are within 1 minute of each other (matches previous WTFT behaviour).
            let sorted = results.sorted { a, b in
                let tA = a.arrivalTime.timeIntervalSinceNow
                let tB = b.arrivalTime.timeIntervalSinceNow
                if abs(tA - tB) < 60 { return a.distanceInMeters < b.distanceInMeters }
                return tA < tB
            }

            DispatchQueue.main.async { completion(.success(sorted)) }
        }
    }

    // MARK: - Feed Availability Check (replaces /by-route/<lineId> in StationDataManager)

    /// Checks which stations on a line have live arrivals and updates
    /// `hasAvailableTimes` on each `Station`.
    func checkAvailability(
        for lineId: String,
        stations: [Station],
        completion: @escaping ([Station]) -> Void
    ) {
        fetchFeed(for: lineId) { result in
            guard case .success(let updates) = result else {
                DispatchQueue.main.async { completion(stations) }
                return
            }

            // Collect all stop_ids that appear in at least one update.
            let activeStopIds = Set(
                updates.filter { $0.routeId == lineId }
                       .flatMap { $0.stopTimeUpdates.map { $0.stopId } }
            )

            let updated: [Station] = stations.map { station in
                var s = station
                if let parentId = station.gtfsStopId {
                    let hasN = activeStopIds.contains(parentId + "N")
                    let hasS = activeStopIds.contains(parentId + "S")
                    s.hasAvailableTimes = hasN || hasS
                } else {
                    s.hasAvailableTimes = false
                }
                return s
            }

            DispatchQueue.main.async { completion(updated) }
        }
    }

    // MARK: - Service Alerts

    /// Fetches and parses the MTA GTFS-RT Alerts feed, returning all active service alerts.
    /// Results are cached for `cacheTTL` seconds.
    func fetchServiceAlerts(
        completion: @escaping (Result<[GTFSAlert], MTAFeedError>) -> Void
    ) {
        guard let url = MTAFeedConfiguration.alertsFeedURL else {
            completion(.failure(.networkError(URLError(.badURL))))
            return
        }

        // Return cached alerts if still fresh.
        if let cached = alertCache[url], Date().timeIntervalSince(cached.date) < cacheTTL {
            DispatchQueue.main.async { completion(.success(cached.alerts)) }
            return
        }

        let request = MTAFeedConfiguration.request(for: url)
        print("[MTAFeed] Requesting alerts URL: \(url)")
        session.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }

            if let error = error {
                print("[MTAFeed] Alerts network error: \(error)")
                DispatchQueue.main.async { completion(.failure(.networkError(error))) }
                return
            }

            if let http = response as? HTTPURLResponse {
                print("[MTAFeed] Alerts HTTP status: \(http.statusCode)")
                if !(200...299).contains(http.statusCode) {
                    DispatchQueue.main.async { completion(.failure(.httpError(http.statusCode))) }
                    return
                }
            }

            guard let data = data, !data.isEmpty else {
                print("[MTAFeed] Alerts: no data received")
                DispatchQueue.main.async { completion(.failure(.noData)) }
                return
            }

            print("[MTAFeed] Alerts: received \(data.count) bytes, parsing…")
            do {
                let alerts = try self.parser.parseAlerts(data)
                print("[MTAFeed] Alerts: parsed \(alerts.count) alerts")
                self.alertCache[url] = (date: Date(), alerts: alerts)
                DispatchQueue.main.async { completion(.success(alerts)) }
            } catch {
                print("[MTAFeed] Alerts parse error: \(error)")
                DispatchQueue.main.async { completion(.failure(.parseError(error))) }
            }
        }.resume()
    }

    // MARK: - Feed Fetch + Cache

    /// Fetches and parses the GTFS-RT feed for a given route, using the cache
    /// when the cached data is still within `cacheTTL` seconds old.
    func fetchFeed(
        for routeId: String,
        completion: @escaping (Result<[GTFSTripUpdate], MTAFeedError>) -> Void
    ) {
        guard let url = MTAFeedConfiguration.feedURL(for: routeId) else {
            completion(.failure(.networkError(URLError(.badURL))))
            return
        }
        fetchFeedData(url: url, completion: completion)
    }

    private func fetchFeedData(
        url: URL,
        completion: @escaping (Result<[GTFSTripUpdate], MTAFeedError>) -> Void
    ) {
        // Return cached result if fresh enough.
        if let cached = cache[url], Date().timeIntervalSince(cached.date) < cacheTTL {
            completion(.success(cached.updates))
            return
        }

        let request = MTAFeedConfiguration.request(for: url)

        session.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }

            if let error = error {
                completion(.failure(.networkError(error)))
                return
            }

            if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
                completion(.failure(.httpError(http.statusCode)))
                return
            }

            guard let data = data, !data.isEmpty else {
                completion(.failure(.noData))
                return
            }

            do {
                let updates = try self.parser.parse(data)
                self.cache[url] = (date: Date(), updates: updates)
                completion(.success(updates))
            } catch {
                completion(.failure(.parseError(error)))
            }
        }.resume()
    }
}

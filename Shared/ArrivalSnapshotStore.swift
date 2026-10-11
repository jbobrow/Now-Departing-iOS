//
//  ArrivalSnapshotStore.swift
//  Now Departing
//
//  Keeps the last arrivals fetched for each stop so times stay on screen without
//  service, e.g. on a platform underground. Arrivals are absolute times, so a
//  snapshot keeps counting down correctly; a snapshot only expires once every
//  train in it has left. On iPhone the store lives in the App Group, so the app
//  and widget fall back to whatever either of them saw last.
//

import Foundation

struct ArrivalSnapshot: Codable {
    let arrivals: [MTAArrival]
    let fetchedAt: Date
}

struct NearbySnapshot: Codable {
    let arrivals: [MTANearbyArrival]
    let fetchedAt: Date
}

enum ArrivalSnapshotStore {
    private static let stationsKey = "arrivalSnapshots"
    private static let nearbyKey = "nearbyArrivalSnapshot"

    private static var defaults: UserDefaults {
        #if os(watchOS)
        return .standard
        #else
        return UserDefaults(suiteName: "group.com.move38.Now-Departing") ?? .standard
        #endif
    }

    // MARK: - By station

    static func save(_ arrivals: [MTAArrival], routeId: String, stopId: String, direction: String, at date: Date = Date()) {
        save([key(routeId: routeId, stopId: stopId, direction: direction): arrivals], at: date)
    }

    /// Saves a Nearby fetch as station snapshots too, so a train opened from Nearby
    /// without service has the same times to show. Keyed by base line, as the
    /// by-station fetch is, with diamond-express trips kept under their line.
    static func saveStations(from nearby: [MTANearbyArrival], at date: Date = Date()) {
        var byStop: [String: [MTAArrival]] = [:]
        for arrival in nearby {
            guard let stopId = arrival.gtfsStopId, !stopId.isEmpty else { continue }
            let stopKey = key(routeId: ExpressRoute.baseLine(for: arrival.routeId), stopId: stopId, direction: arrival.direction)
            byStop[stopKey, default: []].append(MTAArrival(time: arrival.arrivalTime, routeId: arrival.routeId))
        }
        save(byStop.mapValues { $0.sorted { $0.time < $1.time } }, at: date)
    }

    /// Saves several stops' arrivals, by key, in one write.
    private static func save(_ arrivalsByKey: [String: [MTAArrival]], at date: Date) {
        guard !arrivalsByKey.isEmpty else { return }
        // Drop snapshots whose trains have all left so the store stays small.
        var all = loadAll().filter { $0.value.arrivals.contains { $0.time > date } }
        for (stopKey, arrivals) in arrivalsByKey {
            all[stopKey] = ArrivalSnapshot(arrivals: arrivals, fetchedAt: date)
        }
        if let data = try? JSONEncoder().encode(all) {
            defaults.set(data, forKey: stationsKey)
        }
    }

    /// The last arrivals saved for this stop, trimmed to trains still to come.
    /// Nil when nothing was saved or every saved train has left.
    static func load(routeId: String, stopId: String?, direction: String, now: Date = Date()) -> ArrivalSnapshot? {
        guard let stopId, !stopId.isEmpty,
              let snapshot = loadAll()[key(routeId: routeId, stopId: stopId, direction: direction)] else { return nil }
        let upcoming = snapshot.arrivals.filter { $0.time > now }
        return upcoming.isEmpty ? nil : ArrivalSnapshot(arrivals: upcoming, fetchedAt: snapshot.fetchedAt)
    }

    private static func key(routeId: String, stopId: String, direction: String) -> String {
        "\(routeId)-\(stopId)-\(direction)"
    }

    private static func loadAll() -> [String: ArrivalSnapshot] {
        guard let data = defaults.data(forKey: stationsKey),
              let all = try? JSONDecoder().decode([String: ArrivalSnapshot].self, from: data) else { return [:] }
        return all
    }

    // MARK: - Nearby

    static func saveNearby(_ arrivals: [MTANearbyArrival], at date: Date = Date()) {
        if let data = try? JSONEncoder().encode(NearbySnapshot(arrivals: arrivals, fetchedAt: date)) {
            defaults.set(data, forKey: nearbyKey)
        }
    }

    /// The last nearby arrivals, trimmed to trains still to come. Nil when none remain.
    static func loadNearby(now: Date = Date()) -> NearbySnapshot? {
        guard let data = defaults.data(forKey: nearbyKey),
              let snapshot = try? JSONDecoder().decode(NearbySnapshot.self, from: data) else { return nil }
        let upcoming = snapshot.arrivals.filter { $0.arrivalTime > now }
        return upcoming.isEmpty ? nil : NearbySnapshot(arrivals: upcoming, fetchedAt: snapshot.fetchedAt)
    }
}

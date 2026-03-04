//
//  TimesViewModel.swift
//  Now Departing WatchOS App
//
//  Created by Jonathan Bobrow on 1/4/25.
//

import Foundation
import Combine
import ClockKit

class TimesViewModel: ObservableObject {
    // Updated to store time in seconds for more precision
    @Published var nextTrains: [(minutes: Int, seconds: Int)] = [] {
        didSet {
            if nextTrains.isEmpty && !oldValue.isEmpty {
                print("Debug: nextTrains was cleared. Previous value: \(oldValue)")
            }
        }
    }
    @Published var loading: Bool = false
    @Published var errorMessage: String = ""

    private var apiTimer: Timer?
    private var displayTimer: Timer?
    private var arrivalTimes: [Date] = [] {
        didSet {
            cacheArrivalTimes()
        }
    }
    private var isActivelyViewed = true

    private var currentStation: String?
    private var currentLine: String?
    private var currentDirection: String?

    private let cacheKey = "cachedArrivalTimes"
    private let cacheMetadataKey = "cachedArrivalTimesMetadata"

    private struct CacheMetadata: Codable {
        let station: String
        let line: String
        let direction: String
        let timestamp: Date
    }

    private func cacheArrivalTimes() {
        guard let station = currentStation,
              let line = currentLine,
              let direction = currentDirection,
              !arrivalTimes.isEmpty else { return }

        let metadata = CacheMetadata(station: station, line: line, direction: direction, timestamp: Date())
        let timeStrings = arrivalTimes.map { ISO8601DateFormatter().string(from: $0) }

        if let encoded = try? JSONEncoder().encode(metadata) {
            UserDefaults.standard.set(encoded, forKey: cacheMetadataKey)
            UserDefaults.standard.set(timeStrings, forKey: cacheKey)
        }
    }

    private func loadCachedTimes(for station: String, line: String, direction: String) {
        guard let encodedMetadata = UserDefaults.standard.data(forKey: cacheMetadataKey),
              let timeStrings = UserDefaults.standard.stringArray(forKey: cacheKey),
              let metadata = try? JSONDecoder().decode(CacheMetadata.self, from: encodedMetadata),
              metadata.station == station,
              metadata.line == line,
              metadata.direction == direction,
              abs(metadata.timestamp.timeIntervalSinceNow) < 120 else {
            clearCache()
            return
        }

        let formatter = ISO8601DateFormatter()
        arrivalTimes = timeStrings.compactMap { formatter.date(from: $0) }
        updateDisplayTimes()
    }

    private func clearCache() {
        UserDefaults.standard.removeObject(forKey: cacheKey)
        UserDefaults.standard.removeObject(forKey: cacheMetadataKey)
    }

    func startFetchingTimes(for line: SubwayLine, station: Station, direction: String) {
        print("DEBUG: Start Fetching Times")

        currentStation = station.name
        currentLine = line.id
        currentDirection = direction

        loadCachedTimes(for: station.name, line: line.id, direction: direction)

        if arrivalTimes.isEmpty {
            loading = true
        }

        fetchArrivalTimes(for: line, station: station, direction: direction)

        // Refresh every 5 minutes.
        apiTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            self?.fetchArrivalTimes(for: line, station: station, direction: direction)
        }

        adjustUpdateFrequency(isActive: isActivelyViewed)
    }

    func stopFetchingTimes() {
        apiTimer?.invalidate()
        apiTimer = nil
        displayTimer?.invalidate()
        displayTimer = nil
    }

    func adjustUpdateFrequency(isActive: Bool) {
        isActivelyViewed = isActive
        displayTimer?.invalidate()
        let interval: TimeInterval = isActive ? 1 : 10
        displayTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.updateDisplayTimes()
        }
        updateDisplayTimes()
    }

    private func updateDisplayTimes() {
        let now = Date()

        nextTrains = arrivalTimes.compactMap { arrivalTime in
            let interval = arrivalTime.timeIntervalSince(now)
            if interval < 0 { return nil }
            let totalSeconds = Int(interval)
            return (minutes: totalSeconds / 60, seconds: totalSeconds % 60)
        }.sorted { $0.minutes * 60 + $0.seconds < $1.minutes * 60 + $1.seconds }

        arrivalTimes = arrivalTimes.filter { $0 > now }

        if let station = currentStation, let line = currentLine, let direction = currentDirection {
            let defaults = UserDefaults.standard
            defaults.set(station, forKey: "lastViewedStation")
            defaults.set(line, forKey: "lastViewedLine")
            defaults.set(direction, forKey: "lastViewedDirection")
            defaults.set(nextTrains.map { $0.minutes }, forKey: "nextTrains_\(station)_\(line)_\(direction)")

            let server = CLKComplicationServer.sharedInstance()
            server.activeComplications?.forEach { server.reloadTimeline(for: $0) }
        }
    }

    // MARK: - Fetch via MTA GTFS-RT Feed

    private func fetchArrivalTimes(for line: SubwayLine, station: Station, direction: String) {
        guard !direction.isEmpty else {
            errorMessage = "Invalid terminal station"
            loading = false
            return
        }

        MTAFeedService.shared.fetchArrivals(
            routeId: line.id,
            station: station,
            direction: direction
        ) { [weak self] result in
            guard let self = self else { return }

            switch result {
            case .success(let arrivals):
                if arrivals.isEmpty {
                    self.errorMessage = "No times found"
                } else {
                    self.arrivalTimes = arrivals
                    self.errorMessage = ""
                    self.updateDisplayTimes()
                }
                self.loading = false

            case .failure(let error):
                self.errorMessage = error.localizedDescription
                self.loading = false
            }
        }
    }
}

struct ErrorMessages {
    static func networkError(_ error: Error) -> String {
        switch error {
        case is URLError:
            return "Cannot connect to server. Please check your internet connection."
        case DecodingError.dataCorrupted:
            return "Unable to read train times. Please try again."
        default:
            return "Something went wrong. Please try again later."
        }
    }
}

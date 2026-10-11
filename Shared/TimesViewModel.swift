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
    @Published var nextTrains: [(minutes: Int, seconds: Int, isExpress: Bool)] = [] {
        didSet {
            if nextTrains.isEmpty && !oldValue.isEmpty {
                print("Debug: nextTrains was cleared. Previous value: \(oldValue)")
            }
        }
    }
    @Published var loading: Bool = false
    @Published var errorMessage: String = ""
    /// When the times on screen were fetched; it may be older than the last attempt.
    @Published var lastUpdated: Date?
    /// True when the last refresh failed and the times on screen are from an earlier one.
    @Published var isOffline: Bool = false

    private var apiTimer: Timer?
    private var displayTimer: Timer?
    private var arrivalTimes: [MTAArrival] = []
    private var isActivelyViewed = true

    private var currentStation: String?
    private var currentLine: String?
    private var currentDirection: String?

    func startFetchingTimes(for line: SubwayLine, station: Station, direction: String) {
        print("DEBUG: Start Fetching Times")

        apiTimer?.invalidate()

        currentStation = station.name
        currentLine = line.id
        currentDirection = direction

        // Show the last times seen here until the fetch lands, or for as long as
        // there's no service to fetch with.
        if arrivalTimes.isEmpty,
           let snapshot = ArrivalSnapshotStore.load(routeId: line.id, stopId: station.gtfsStopId, direction: direction) {
            arrivalTimes = snapshot.arrivals
            lastUpdated = snapshot.fetchedAt
            updateDisplayTimes()
        }

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

        nextTrains = arrivalTimes.compactMap { arrival in
            let interval = arrival.time.timeIntervalSince(now)
            if interval < 0 { return nil }
            let totalSeconds = Int(interval)
            return (minutes: totalSeconds / 60, seconds: totalSeconds % 60, isExpress: arrival.isExpress)
        }.sorted { $0.minutes * 60 + $0.seconds < $1.minutes * 60 + $1.seconds }

        arrivalTimes = arrivalTimes.filter { $0.time > now }

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

        MTAFeedService.shared.fetchTrainArrivals(
            routeId: line.id,
            station: station,
            direction: direction
        ) { [weak self] result in
            guard let self = self else { return }

            switch result {
            case .success(let arrivals):
                self.lastUpdated = Date()
                self.isOffline = false
                if arrivals.isEmpty {
                    self.errorMessage = "No times found"
                } else {
                    self.arrivalTimes = arrivals
                    self.errorMessage = ""
                    self.updateDisplayTimes()
                }
                self.loading = false

            case .failure(let error):
                // Keep the times we have; they still count down correctly.
                self.isOffline = true
                self.updateDisplayTimes()
                self.errorMessage = self.arrivalTimes.isEmpty ? error.localizedDescription : ""
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

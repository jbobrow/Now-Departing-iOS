//
//  NearbyTrainsManager.swift
//  Now Departing
//
//  Created by Jonathan Bobrow on 6/4/25.
//

import Foundation
import CoreLocation
import Combine

class NearbyTrainsManager: ObservableObject {
    @Published var nearbyTrains: [NearbyTrain] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String = ""

    private var refreshTimer: Timer?
    private var currentLocation: CLLocation?
    private var stationDataManager: StationDataManager

    init(stationDataManager: StationDataManager) {
        self.stationDataManager = stationDataManager
    }

    func updateStationDataManager(_ newStationDataManager: StationDataManager) {
        self.stationDataManager = newStationDataManager
    }

    func startFetching(location: CLLocation) {
        currentLocation = location
        stopFetching()
        fetchNearbyTrains(location: location)

        // Refresh every 60 seconds.
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.fetchNearbyTrains(location: location)
        }
    }

    func stopFetching() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }

    // MARK: - Fetch via MTA GTFS-RT Feed

    private func fetchNearbyTrains(location: CLLocation) {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = ""

        MTAFeedService.shared.fetchNearbyArrivals(
            location: location,
            stationsByLine: stationDataManager.stationsByLine
        ) { [weak self] result in
            guard let self = self else { return }

            switch result {
            case .success(let rawArrivals):
                let trains: [NearbyTrain] = rawArrivals.map { a in
                    NearbyTrain(
                        lineId: a.routeId,
                        stationId: a.gtfsStopId ?? a.stationName,
                        stationName: a.stationName,
                        stationDisplay: a.stationDisplay,
                        direction: a.direction,
                        destination: DirectionHelper.getDestination(for: a.routeId, direction: a.direction),
                        arrivalTime: a.arrivalTime,
                        distanceInMeters: a.distanceInMeters,
                        gtfsStopId: a.gtfsStopId,
                        complexId: a.complexId,
                        latitude: a.latitude,
                        longitude: a.longitude
                    )
                }
                self.nearbyTrains = trains
                self.errorMessage = trains.isEmpty ? "No trains found within 30 minutes" : ""

            case .failure(let error):
                // Translate MTAFeedError into the same user-facing strings the old
                // code used so nothing in the UI layer needs to change.
                switch error {
                case .networkError(let underlying):
                    if let urlError = underlying as? URLError {
                        switch urlError.code {
                        case .notConnectedToInternet:
                            self.errorMessage = "No internet connection"
                        case .timedOut:
                            self.errorMessage = "Request timed out"
                        case .cannotFindHost, .cannotConnectToHost:
                            self.errorMessage = "Cannot connect to server"
                        default:
                            self.errorMessage = "Network error: \(urlError.localizedDescription)"
                        }
                    } else {
                        self.errorMessage = "Network error: \(error.localizedDescription)"
                    }
                default:
                    self.errorMessage = "Failed to load nearby trains"
                }
            }

            self.isLoading = false
        }
    }
}

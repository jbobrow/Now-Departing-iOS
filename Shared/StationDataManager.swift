//
//  StationDataManager.swift
//  Now Departing WatchOS App
//
//  Created by Jonathan Bobrow on 1/4/25.
//

import Foundation

class StationDataManager: ObservableObject {
    @Published private(set) var loadingState: LoadingState = .idle
    @Published var stationsByLine: [String: [Station]] = [:]
    @Published var isLoading: Bool = true

    private let remoteURL = URL(string: "https://raw.githubusercontent.com/jbobrow/Now-Departing-WatchOS/refs/heads/main/Shared/stations.json")!
    private var lastFetchTime: Date?
    private let cacheDuration: TimeInterval = 3600 // 1 hour

    enum LoadingState: Equatable {
        case idle
        case loading
        case loaded
        case error(String)
    }

    private var documentsFileURL: URL {
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentsDirectory.appendingPathComponent("stations.json")
    }

    init() {
        loadStations()
    }

    // MARK: - Public Methods

    func stations(for lineID: String) -> [Station]? {
        return stationsByLine[lineID]
    }

    func refreshStations() {
        guard stationsByLine.isEmpty || shouldRefreshCache() else {
            print("DEBUG: Skipping refresh, using cached data")
            return
        }
        print("DEBUG: Refreshing stations")
        fetchRemoteStations()
    }

    func loadStations() {
        print("DEBUG: Loading stations")
        loadFromAvailableSources()
    }

    func loadStationsForLine(_ lineId: String) {
        if let existingStations = stationsByLine[lineId] {
            checkStationAvailability(for: lineId, stations: existingStations)
            return
        }
        loadStations()
        if let stations = stationsByLine[lineId] {
            checkStationAvailability(for: lineId, stations: stations)
        }
    }

    // MARK: - Station Lookup Methods

    func getStationDisplayName(for stationName: String) -> String? {
        for stations in stationsByLine.values {
            if let station = stations.first(where: { $0.name == stationName }) {
                return station.display
            }
        }
        return nil
    }

    func findStation(byName stationName: String) -> Station? {
        for stations in stationsByLine.values {
            if let station = stations.first(where: { $0.name == stationName }) {
                return station
            }
        }
        return nil
    }

    // MARK: - Private Methods

    private func shouldRefreshCache() -> Bool {
        guard let lastFetch = lastFetchTime else { return true }
        return Date().timeIntervalSince(lastFetch) > cacheDuration
    }

    private func setLoadingState(_ state: LoadingState) {
        DispatchQueue.main.async {
            self.loadingState = state
            self.isLoading = (state == .loading)
        }
    }

    // MARK: - Unified Data Loading

    private func loadFromAvailableSources() {
        let dataSources: [(name: String, loader: () -> Data?)] = [
            ("documents cache", { try? Data(contentsOf: self.documentsFileURL) }),
            ("app bundle", {
                guard let bundleURL = Bundle.main.url(forResource: "stations", withExtension: "json")
                else { return nil }
                return try? Data(contentsOf: bundleURL)
            })
        ]

        for (sourceName, loader) in dataSources {
            if let data = loader(), let stations = parseStationsData(data) {
                updateStations(stations, source: sourceName)
                return
            }
        }

        DispatchQueue.main.async {
            self.isLoading = false
            print("DEBUG: No local stations found")
        }
    }

    private func fetchRemoteStations() {
        guard shouldRefreshCache() else { return }

        setLoadingState(.loading)

        let task = URLSession.shared.dataTask(with: remoteURL) { [weak self] data, response, error in
            guard let self = self else { return }

            if let error = error {
                print("DEBUG: Network error: \(error.localizedDescription)")
                self.handleRemoteFailure()
                return
            }

            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                print("DEBUG: Invalid response - Status: \((response as? HTTPURLResponse)?.statusCode ?? -1)")
                self.handleRemoteFailure()
                return
            }

            guard let data = data else {
                print("DEBUG: No data received")
                self.handleRemoteFailure()
                return
            }

            guard let decodedData = self.parseStationsData(data),
                  self.validateStationsData(decodedData) else {
                print("DEBUG: Failed to parse or validate remote data")
                self.handleRemoteFailure()
                return
            }

            try? data.write(to: self.documentsFileURL)
            self.cacheData(decodedData)
            self.updateStations(decodedData, source: "remote server")

            DispatchQueue.main.async {
                self.lastFetchTime = Date()
            }
        }

        task.resume()
    }

    private func handleRemoteFailure() {
        print("⚠️ Remote fetch failed, using local data")
        DispatchQueue.main.async {
            if !self.stationsByLine.isEmpty {
                self.setLoadingState(.loaded)
            } else {
                self.loadFromAvailableSources()
                if self.stationsByLine.isEmpty {
                    self.setLoadingState(.error("Unable to load station data. Please check your internet connection."))
                }
            }
        }
    }

    // MARK: - Data Processing Helpers

    private func parseStationsData(_ data: Data) -> [String: [Station]]? {
        do {
            return try JSONDecoder().decode([String: [Station]].self, from: data)
        } catch {
            print("DEBUG: JSON parsing error: \(error)")
            return nil
        }
    }

    private func validateStationsData(_ data: [String: [Station]]) -> Bool {
        guard !data.isEmpty else {
            print("DEBUG: Validation failed - no lines found")
            return false
        }

        let totalStations = data.values.map { $0.count }.reduce(0, +)
        guard totalStations > 0 else {
            print("DEBUG: Validation failed - no stations found")
            return false
        }

        print("DEBUG: Data validation passed - \(data.keys.count) lines, \(totalStations) total stations")
        return true
    }

    private func updateStations(_ stations: [String: [Station]], source: String) {
        DispatchQueue.main.async {
            self.stationsByLine = stations
            self.setLoadingState(.loaded)
            self.isLoading = false
            print("DEBUG: Stations loaded from \(source) ✅")
        }
    }

    private func cacheData(_ stations: [String: [Station]]) {
        guard let data = try? JSONEncoder().encode(stations) else { return }
        UserDefaults.standard.set(data, forKey: "cachedStations")
    }

    // MARK: - Station Availability Check (via MTA GTFS-RT)

    private func checkStationAvailability(for lineId: String, stations: [Station]) {
        MTAFeedService.shared.checkAvailability(for: lineId, stations: stations) { [weak self] updated in
            self?.stationsByLine[lineId] = updated
        }
    }
}

enum DataError: Error {
    case invalidData
}

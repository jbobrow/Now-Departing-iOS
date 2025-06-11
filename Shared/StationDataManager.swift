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
        // If we already have stations for this line, check their availability
        if let existingStations = stationsByLine[lineId] {
            checkStationAvailability(for: lineId, stations: existingStations)
            return
        }
        
        // Load all stations first, then check availability for this line
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
        // Try sources in order of preference: documents cache -> bundle -> error
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
        
        // If all local sources fail
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
            
            // Check for any failure condition
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
            
            // Try to parse and validate remote data
            guard let decodedData = self.parseStationsData(data),
                  self.validateStationsData(decodedData) else {
                print("DEBUG: Failed to parse or validate remote data")
                self.handleRemoteFailure()
                return
            }
            
            // Success - save and update
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
            // If we already have data, just update state without changing data
            if !self.stationsByLine.isEmpty {
                self.setLoadingState(.loaded)
            } else {
                // Try to load local data as fallback
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
    
    // MARK: - Station Availability Check
    
    private func checkStationAvailability(for lineId: String, stations: [Station]) {
        let apiURL = URL(string: "https://api.wheresthefuckingtrain.com/by-route/\(lineId)")!
        print("DEBUG: Checking availability for line \(lineId)")

        let task = URLSession.shared.dataTask(with: apiURL) { [weak self] data, response, error in
            guard let data = data,
                  let response = try? JSONDecoder().decode(APIResponse.self, from: data) else {
                return
            }
            
            DispatchQueue.main.async {
                var updatedStations = stations
                for (index, station) in stations.enumerated() {
                    if let stationData = response.data.first(where: { $0.name == station.name }) {
                        let hasTrains = !stationData.N.isEmpty || !stationData.S.isEmpty
                        updatedStations[index].hasAvailableTimes = hasTrains
                    } else {
                        updatedStations[index].hasAvailableTimes = false
                    }
                }
                self?.stationsByLine[lineId] = updatedStations
            }
        }
        task.resume()
    }
}

enum DataError: Error {
    case invalidData
}

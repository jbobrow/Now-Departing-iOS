//
//  StationDataManager.swift
//  Now Departing WatchOS App
//
//  Created by Jonathan Bobrow on 1/4/25.
//

import Foundation

// Updated Station model with availability status

class StationDataManager: ObservableObject {
    @Published private(set) var loadingState: LoadingState = .idle
    @Published var stationsByLine: [String: [Station]] = [:]
    @Published var isLoading: Bool = true
    
    private let remoteURL = URL(string: "https://raw.githubusercontent.com/jbobrow/Now-Departing-WatchOS/refs/heads/main/Shared/stations.json")!
    private var lastFetchTime: Date?
    private let cacheDuration: TimeInterval = 3600 // 1 hour
    private var loadedLines: Set<String> = []
    
    enum LoadingState {
        case idle
        case loading
        case loaded
        case error(String)
    }
    
    private var documentsFileURL: URL {
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentsDirectory.appendingPathComponent("stations.json")
    }
    
    private var bundleFileURL: URL? {
        return Bundle.main.url(forResource: "stations", withExtension: "json")
    }
    
    init() {
        loadLocalStations()
    }
    
    // MARK: - Station Lookup Methods
    
    /// Find a station's display name by its API name across all lines
    func getStationDisplayName(for stationName: String) -> String? {
        for (_, stations) in stationsByLine {
            if let station = stations.first(where: { $0.name == stationName }) {
                return station.display
            }
        }
        return nil
    }
    
    /// Find a station by its API name across all lines
    func findStation(byName stationName: String) -> Station? {
        for (_, stations) in stationsByLine {
            if let station = stations.first(where: { $0.name == stationName }) {
                return station
            }
        }
        return nil
    }
    
    func shouldRefreshCache() -> Bool {
        guard let lastFetch = lastFetchTime else { return true }
        return Date().timeIntervalSince(lastFetch) > cacheDuration
    }
    
    private func setLoadingState(_ state: LoadingState) {
        DispatchQueue.main.async {
            self.loadingState = state
        }
    }
    
    private func loadLocalStations() {
        var loadedData: [String: [Station]]?
        
        // Try loading from documents directory first
        if let data = try? Data(contentsOf: documentsFileURL),
           let decodedData = try? JSONDecoder().decode([String: [Station]].self, from: data) {
            loadedData = decodedData
            print("DEBUG: Stations found in documents directory")
        }
        
        // If documents directory load failed, try bundle
        if loadedData == nil,
           let bundleURL = bundleFileURL,
           let data = try? Data(contentsOf: bundleURL),
           let decodedData = try? JSONDecoder().decode([String: [Station]].self, from: data) {
            loadedData = decodedData
            print("DEBUG: Stations found in bundle")
        }
        
        // Update state
        DispatchQueue.main.async {
            if let loadedData = loadedData {
                self.stationsByLine = loadedData
            }
            self.isLoading = false
            print("DEBUG: Loaded stations")
        }
    }
    
    private func loadCachedData() -> [String: [Station]]? {
        guard let data = UserDefaults.standard.data(forKey: "cachedStations"),
              let stations = try? JSONDecoder().decode([String: [Station]].self, from: data) else {
            return nil
        }
        return stations
    }
    
    private func cacheData(_ stations: [String: [Station]]) {
        guard let data = try? JSONEncoder().encode(stations) else { return }
        UserDefaults.standard.set(data, forKey: "cachedStations")
    }
    
    private func checkStationAvailability(for lineId: String, stations: [Station]) {
        let apiURL = URL(string: "https://api.wheresthefuckingtrain.com/by-route/\(lineId)")!
        print("DEBUG: Checking Stations")

        let task = URLSession.shared.dataTask(with: apiURL) { [weak self] data, response, error in
            guard let data = data,
                  let response = try? JSONDecoder().decode(APIResponse.self, from: data) else {
                return
            }
            
            DispatchQueue.main.async {
                var updatedStations = stations
                for (index, station) in stations.enumerated() {
                    if let stationData = response.data.first(where: { $0.name == station.name }) {
                        let hasNorthTrains = !stationData.N.isEmpty
                        let hasSouthTrains = !stationData.S.isEmpty
//                        print("DEBUG: trains available at " + station.display)
                        updatedStations[index].hasAvailableTimes = hasNorthTrains || hasSouthTrains
                    } else {
                        updatedStations[index].hasAvailableTimes = false
//                        print("DEBUG: no trains at " + station.display)
                    }
                }
                self?.stationsByLine[lineId] = updatedStations
            }
        }
        task.resume()
    }
    
    func loadStationsForLine(_ lineId: String) {
        // If we already have stations for this line, use them
        if let existingStations = stationsByLine[lineId] {
//            print("DEBUG: Checking availability for line \(lineId)")
            checkStationAvailability(for: lineId, stations: existingStations)
            return
        }
        
        // If we don't have stations yet, load them first
        loadLocalStations()
        
        // After loading, check availability if we now have stations
        if let stations = stationsByLine[lineId] {
//            print("DEBUG: Checking availability for newly loaded line \(lineId)")
            checkStationAvailability(for: lineId, stations: stations)
        }
    }
    
    private func fetchRemoteStations() {
        if !shouldRefreshCache() { return }
        
        setLoadingState(.loading)
        
        let task = URLSession.shared.dataTask(with: remoteURL) { [weak self] data, response, error in
            guard let self = self else { return }
            
            if let error = error {
                print("DEBUG: Network error: \(error)")
                // Instead of setting error state, try local fallback
                self.handleRemoteFailure(reason: "Network error: \(error.localizedDescription)")
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                print("DEBUG: Invalid response - Status: \((response as? HTTPURLResponse)?.statusCode ?? -1)")
                // Instead of setting error state, try local fallback
                self.handleRemoteFailure(reason: "Server responded with status \((response as? HTTPURLResponse)?.statusCode ?? -1)")
                return
            }
            
            guard let data = data else {
                print("DEBUG: No data received")
                // Instead of setting error state, try local fallback
                self.handleRemoteFailure(reason: "No data received from server")
                return
            }
            
            do {
                let decodedData = try JSONDecoder().decode([String: [Station]].self, from: data)
                
                guard self.validate(decodedData) else {
                    print("DEBUG: Data validation failed")
                    // Instead of throwing error, try local fallback
                    self.handleRemoteFailure(reason: "Invalid data format received")
                    return
                }
                
                if !decodedData.isEmpty {
                    // Save to documents directory for future local loads
                    try? data.write(to: self.documentsFileURL)
                    self.cacheData(decodedData)
                    
                    DispatchQueue.main.async {
                        self.lastFetchTime = Date()
                        self.stationsByLine = decodedData
                        self.setLoadingState(.loaded)
                        print("DEBUG: Remote stations fetched successfully ✅")
                    }
                } else {
                    print("DEBUG: Remote data was empty")
                    self.handleRemoteFailure(reason: "No station data available")
                }
            } catch {
                print("DEBUG: JSON processing error: \(error)")
                // Instead of setting error state, try local fallback
                self.handleRemoteFailure(reason: "Failed to process server data")
            }
        }
        
        task.resume()
    }

    // MARK: - Fallback Handler
    private func handleRemoteFailure(reason: String) {
        print("⚠️ Remote fetch failed: \(reason)")
        print("📱 Attempting to load local fallback data...")
        
        // Try to load from local JSON bundle first
        if loadFromLocalBundle() {
            print("✅ Successfully loaded stations from local bundle")
            return
        }
        
        // If bundle fails, try cached file in documents
        if loadFromDocumentsCache() {
            print("✅ Successfully loaded stations from documents cache")
            return
        }
        
        // If both fail, then show error
        DispatchQueue.main.async {
            self.setLoadingState(.error("Unable to load station data. Please check your internet connection."))
            print("❌ All fallback options exhausted")
        }
    }

    // MARK: - Local Bundle Fallback
    private func loadFromLocalBundle() -> Bool {
        guard let bundlePath = Bundle.main.path(forResource: "stations", ofType: "json"),
              let data = NSData(contentsOfFile: bundlePath) as Data? else {
            print("DEBUG: No local stations.json found in bundle")
            return false
        }
        
        do {
            let decodedData = try JSONDecoder().decode([String: [Station]].self, from: data)
            
            guard validate(decodedData) else {
                print("DEBUG: Local bundle data validation failed")
                return false
            }
            
            DispatchQueue.main.async {
                self.stationsByLine = decodedData
                self.setLoadingState(.loaded)
                print("DEBUG: Local bundle stations loaded")
            }
            
            return true
            
        } catch {
            print("DEBUG: Failed to parse local bundle JSON: \(error)")
            return false
        }
    }

    // MARK: - Documents Cache Fallback
    private func loadFromDocumentsCache() -> Bool {
        guard FileManager.default.fileExists(atPath: documentsFileURL.path) else {
            print("DEBUG: No cached file exists in documents")
            return false
        }
        
        do {
            let data = try Data(contentsOf: documentsFileURL)
            let decodedData = try JSONDecoder().decode([String: [Station]].self, from: data)
            
            guard validate(decodedData) else {
                print("DEBUG: Cached data validation failed")
                return false
            }
            
            DispatchQueue.main.async {
                self.stationsByLine = decodedData
                self.setLoadingState(.loaded)
                print("DEBUG: Cached stations loaded from documents")
            }
            
            return true
            
        } catch {
            print("DEBUG: Failed to load cached data: \(error)")
            return false
        }
    }

    // MARK: - Enhanced Validation (Optional Enhancement)
    private func validate(_ data: [String: [Station]]) -> Bool {
        // Basic validation - ensure we have some lines and stations
        guard !data.isEmpty else {
            print("DEBUG: Validation failed - no lines found")
            return false
        }
        
        // Check that we have at least some stations
        let totalStations = data.values.map { $0.count }.reduce(0, +)
        guard totalStations > 0 else {
            print("DEBUG: Validation failed - no stations found")
            return false
        }
        
        // Optional: Validate specific lines exist (add your critical lines)
        let criticalLines = ["1", "4", "6", "N", "Q", "R", "W"] // Add your most important lines
        let hasAnyCriticalLine = criticalLines.contains { lineId in
            data[lineId]?.isEmpty == false
        }
        
        if !hasAnyCriticalLine {
            print("DEBUG: Validation warning - no critical lines found, but allowing data")
            // Don't fail validation, just log warning
        }
        
        print("DEBUG: Data validation passed - \(data.keys.count) lines, \(totalStations) total stations")
        return true
    }

    // MARK: - Helper Methods for Testing/Debugging

    // Method to force local mode (useful for testing)
    private func forceLocalFallback() {
        print("🔄 Forcing local fallback mode")
        handleRemoteFailure(reason: "Forced local mode for testing")
    }

    // Method to check what data source is being used
    private func getDataSource() -> String {
        // You could add metadata to track this
        if FileManager.default.fileExists(atPath: documentsFileURL.path) {
            return "Documents Cache"
        } else if Bundle.main.path(forResource: "stations", ofType: "json") != nil {
            return "Local Bundle"
        } else {
            return "Unknown"
        }
    }

    // Method to clear all local data (for testing)
    private func clearLocalData() {
        try? FileManager.default.removeItem(at: documentsFileURL)
        print("DEBUG: Cleared local cached data")
    }
    
    func stations(for lineID: String) -> [Station]? {
        return stationsByLine[lineID]
    }
    
    func refreshStations() {
        // Only fetch if we haven't loaded stations or if cache is stale
        if stationsByLine.isEmpty || shouldRefreshCache() {
            print("DEBUG: Refreshing stations")
            fetchRemoteStations()
        } else {
            print("DEBUG: Skipping refresh, using cached data")
        }
    }
    
    func loadStations() {
        loadLocalStations()
        print("DEBUG: Loading stations")
    }
}

enum DataError: Error {
    case invalidData
}

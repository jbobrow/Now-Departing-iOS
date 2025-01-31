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
    
    private let remoteURL = URL(string: "https://raw.githubusercontent.com/jbobrow/Now-Departing-WatchOS/refs/heads/main/Now%20Departing%20Watch%20App/stations.json")!
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
        // Only load local stations on init
        loadLocalStations()
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
    
    private func validate(_ data: [String: [Station]]) -> Bool {
        for (lineId, stations) in data {
            guard !lineId.isEmpty,
                  !stations.isEmpty,
                  stations.allSatisfy({ !$0.name.isEmpty && !$0.display.isEmpty }) else {
                return false
            }
        }
        return true
    }
    
    private func loadLocalStations() {
        var loadedData: [String: [Station]]?
        
        // Try loading from documents directory first
        if let data = try? Data(contentsOf: documentsFileURL),
           let decodedData = try? JSONDecoder().decode([String: [Station]].self, from: data) {
            loadedData = decodedData
            print("Debug - Stations found in documents directory")
        }
        
        // If documents directory load failed, try bundle
        if loadedData == nil,
           let bundleURL = bundleFileURL,
           let data = try? Data(contentsOf: bundleURL),
           let decodedData = try? JSONDecoder().decode([String: [Station]].self, from: data) {
            loadedData = decodedData
            print("Debug - Stations found in bundle")
        }
        
        // Update state
        DispatchQueue.main.async {
            if let loadedData = loadedData {
                self.stationsByLine = loadedData
            }
            self.isLoading = false
            print("Debug - Loaded stations")
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
    
    func loadStationsForLine(_ lineId: String) {
        guard !loadedLines.contains(lineId) else { return }
        
        // Load only specific line data
        if let url = Bundle.main.url(forResource: "stations_\(lineId)", withExtension: "json") {
            if let data = try? Data(contentsOf: url),
               let stations = try? JSONDecoder().decode([Station].self, from: data) {
                DispatchQueue.main.async {
                    self.stationsByLine[lineId] = stations
                    self.loadedLines.insert(lineId)
                }
            }
        }
    }
    
    private func fetchRemoteStations() {
        if !shouldRefreshCache() { return }
        
        setLoadingState(.loading)
        
        let task = URLSession.shared.dataTask(with: remoteURL) { [weak self] data, response, error in
            guard let self = self else { return }
            
            if let error = error {
                print("Debug - Network error: \(error)")
                self.setLoadingState(.error(error.localizedDescription))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                print("Debug - Invalid response")
                self.setLoadingState(.error("Invalid server response"))
                return
            }
            
            guard let data = data else {
                print("Debug - No data received")
                self.setLoadingState(.error("No data received"))
                return
            }
            
            do {
                let decodedData = try JSONDecoder().decode([String: [Station]].self, from: data)
                
                guard self.validate(decodedData) else {
                    throw DataError.invalidData
                }
                
                if !decodedData.isEmpty {
                    // Save to documents directory for future local loads
                    try? data.write(to: self.documentsFileURL)
                    self.cacheData(decodedData)
                    
                    DispatchQueue.main.async {
                        self.lastFetchTime = Date()
                        self.stationsByLine = decodedData
                        self.setLoadingState(.loaded)
                        print("Debug - Stations fetched")
                    }
                }
            } catch {
                print("Debug - JSON processing error: \(error)")
                self.setLoadingState(.error("Failed to process data"))
            }
        }
        
        task.resume()
    }
    
    func stations(for lineID: String) -> [Station]? {
        return stationsByLine[lineID]
    }
    
    func refreshStations() {
        // Only fetch if we haven't loaded stations or if cache is stale
        if stationsByLine.isEmpty || shouldRefreshCache() {
            print("Debug - Refreshing stations")
            fetchRemoteStations()
        } else {
            print("Debug - Skipping refresh, using cached data")
        }
    }
    
    func loadStations() {
        loadLocalStations()
        print("Debug - Loading stations")
    }
}

enum DataError: Error {
    case invalidData
}

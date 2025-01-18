//
//  StationDataManager.swift
//  Now Departing WatchOS App
//
//  Created by Jonathan Bobrow on 1/4/25.
//


import Foundation

class StationDataManager: ObservableObject {
    @Published var stationsByLine: [String: [Station]] = [:]
    @Published var isLoading: Bool = true
    
    private let remoteURL = URL(string: "https://raw.githubusercontent.com/jbobrow/Now-Departing-WatchOS/refs/heads/main/Now%20Departing%20Watch%20App/stations.json")!
    
    private var documentsFileURL: URL {
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentsDirectory.appendingPathComponent("stations.json")
    }
    
    private var bundleFileURL: URL? {
        return Bundle.main.url(forResource: "stations", withExtension: "json")
    }
    
    init() {
        loadLocalStations()
        // Only fetch remote data on initial launch
        fetchRemoteStations()
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
    
    private func fetchRemoteStations() {
        let task = URLSession.shared.dataTask(with: remoteURL) { [weak self] data, response, error in
            guard let self = self else { return }
            
            if let error = error {
                print("Debug - Network error: \(error)")
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                print("Debug - Invalid response")
                return
            }
            
            guard let data = data else {
                print("Debug - No data received")
                return
            }
            
            do {
                let decodedData = try JSONDecoder().decode([String: [Station]].self, from: data)
                
                if !decodedData.isEmpty {
                    // Save to documents directory for future local loads
                    try? data.write(to: documentsFileURL)
                    
                    DispatchQueue.main.async {
                        self.stationsByLine = decodedData
                        print("Debug - Stations fetched")
                    }
                }
            } catch {
                print("Debug - JSON processing error: \(error)")
            }
        }
        
        task.resume()
    }
    
    func stations(for lineID: String) -> [Station]? {
        return stationsByLine[lineID]
    }
    
    func refreshStations() {
        // This is now only called when the app comes to foreground
        fetchRemoteStations()
        print("Debug - Refreshing stations")
    }
    
    func loadStations() {
        loadLocalStations()
        print("Debug - Loading stations")
    }
}

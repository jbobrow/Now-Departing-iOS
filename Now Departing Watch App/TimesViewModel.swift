//
//  TimesViewModel.swift
//  Now Departing WatchOS App
//
//  Created by Jonathan Bobrow on 1/4/25.
//

import Foundation
import Combine

class TimesViewModel: ObservableObject {
    @Published var nextTrains: [Int] = [] {
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
    private var lastUpdateTime: Date = Date()
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
              let direction = currentDirection else {
            return
        }
        
        // Only cache if we have arrival times
        guard !arrivalTimes.isEmpty else {
            return
        }
        
        let metadata = CacheMetadata(
            station: station,
            line: line,
            direction: direction,
            timestamp: Date()
        )
        
        // Convert dates to ISO8601 strings for caching
        let timeStrings = arrivalTimes.map { date in
            ISO8601DateFormatter().string(from: date)
        }
        
        do {
            let encodedMetadata = try JSONEncoder().encode(metadata)
            UserDefaults.standard.set(encodedMetadata, forKey: cacheMetadataKey)
            UserDefaults.standard.set(timeStrings, forKey: cacheKey)
        } catch {
            print("Error caching arrival times: \(error)")
        }
    }
    
    private func loadCachedTimes(for station: String, line: String, direction: String) {
        guard let encodedMetadata = UserDefaults.standard.data(forKey: cacheMetadataKey),
              let timeStrings = UserDefaults.standard.stringArray(forKey: cacheKey) else {
            return
        }
        
        do {
            let metadata = try JSONDecoder().decode(CacheMetadata.self, from: encodedMetadata)
            
            // Only use cache if it's for the same station/line/direction
            guard metadata.station == station &&
                  metadata.line == line &&
                  metadata.direction == direction else {
                return
            }
            
            // Only use cache if it's less than 2 minutes old
            guard abs(metadata.timestamp.timeIntervalSinceNow) < 120 else {
                clearCache()
                return
            }
            
            let formatter = ISO8601DateFormatter()
            arrivalTimes = timeStrings.compactMap { formatter.date(from: $0) }
            updateDisplayTimes()
            
        } catch {
            print("Error loading cached arrival times: \(error)")
        }
    }
    
    private func clearCache() {
        UserDefaults.standard.removeObject(forKey: cacheKey)
        UserDefaults.standard.removeObject(forKey: cacheMetadataKey)
    }
    
    func startFetchingTimes(for line: SubwayLine, station: Station, direction: String) {
        print("Start Fetching Times")
        
        currentStation = station.name
        currentLine = line.id
        currentDirection = direction
        
        // Try to load cached times first
        loadCachedTimes(for: station.name, line: line.id, direction: direction)
        
        // Set loading only if we don't have any arrival times
        if arrivalTimes.isEmpty {
            loading = true
        }
        
        // Initial fetch
        fetchArrivalTimes(for: line, station: station, direction: direction)
        
        // Set up API timer to refresh data every 60 seconds
        apiTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.fetchArrivalTimes(for: line, station: station, direction: direction)
        }
        
        // Set up display timer based on active viewing state
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
        // Don't clear nextTrains when adjusting frequency
        if isActive {
            displayTimer?.invalidate()
            displayTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
                self?.updateDisplayTimes()
            }
        } else {
            displayTimer?.invalidate()
            displayTimer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { [weak self] _ in
                self?.updateDisplayTimes()
            }
        }
        // Force an immediate update of display times to ensure we show something
        updateDisplayTimes()
    }
    
    private func updateDisplayTimes() {
        let now = Date()
        
        print("Update Display Times")
        print(Calendar.current.dateComponents([.second], from: now))
        nextTrains = arrivalTimes.compactMap { arrivalTime in
            let minutes = Calendar.current.dateComponents([.minute], from: now, to: arrivalTime).minute ?? 0
            return minutes >= 0 ? minutes : nil  // Only show future times
        }.sorted()
        
        // Clean up past arrival times
        arrivalTimes = arrivalTimes.filter { arrivalTime in
            arrivalTime > now
        }
    }
    
    private func validateTimestamp(_ dateString: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        guard let date = formatter.date(from: dateString),
              date > Date().addingTimeInterval(-300) // Not more than 5 minutes in past
        else {
            return nil
        }
        return date
    }
    
    private func fetchArrivalTimes(for line: SubwayLine, station: Station, direction: String) {
        print("Fetch Arrival Times")
        guard !direction.isEmpty else {
            self.errorMessage = "Invalid terminal station"
            self.loading = false
            return
        }
        
        let apiURL = "https://api.wheresthefuckingtrain.com/by-route/\(line.id)"
        
        guard let url = URL(string: apiURL) else {
            self.errorMessage = "Invalid URL"
            self.loading = false
            return
        }
        
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 30
        let session = URLSession(configuration: config)

        let retryCount = 3
        func performRequest(attempts: Int) {
            session.dataTask(with: url) { [weak self] data, response, error in
                DispatchQueue.main.async {
                    if let error = error {
                        if attempts < retryCount {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                                performRequest(attempts: attempts + 1)
                            }
                            return
                        }
                        self?.errorMessage = ErrorMessages.networkError(error)
                        self?.loading = false
                        return
                    }

                    guard let httpResponse = response as? HTTPURLResponse else {
                        self?.errorMessage = "Invalid response"
                        self?.loading = false
                        return
                    }

                    guard (200...299).contains(httpResponse.statusCode) else {
                        self?.errorMessage = "Server error: \(httpResponse.statusCode)"
                        self?.loading = false
                        return
                    }

                    guard let data = data else {
                        self?.errorMessage = "No data received"
                        self?.loading = false
                        return
                    }

                    do {
                        let response = try JSONDecoder().decode(APIResponse.self, from: data)
                        if let stationData = response.data.first(where: { $0.name == station.name }) {
                            let arrivals = self?.extractArrivalDates(for: line, from: stationData, direction: direction) ?? []
                            if arrivals.isEmpty {
                                self?.errorMessage = "No times found"
                            } else {
                                self?.arrivalTimes = arrivals
                                self?.errorMessage = ""
                                self?.updateDisplayTimes()
                            }
                        } else {
                            self?.errorMessage = "No times found"
                        }
                        self?.loading = false
                    } catch {
                        self?.errorMessage = "Failed to decode data: \(error.localizedDescription)"
                        self?.loading = false
                    }
                }
            }.resume()
        }

        performRequest(attempts: 0)
    }
    
    private func extractArrivalDates(for line: SubwayLine, from stationData: StationData, direction: String) -> [Date] {
        let formatter = ISO8601DateFormatter()
        
        // Filter the train array based on the direction and line
        let trains: [Train]
        if direction == "N" {
            trains = stationData.N.filter { $0.route == line.id }
        } else {
            trains = stationData.S.filter { $0.route == line.id }
        }
        
        // Convert time strings to Date objects and validate timestamps
        return trains.compactMap { train in
            validateTimestamp(train.time)
        }.filter { $0 > Date() }  // Only keep future times
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

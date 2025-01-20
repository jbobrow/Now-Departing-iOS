//
//  TimesViewModel.swift
//  Now Departing WatchOS App
//
//  Created by Jonathan Bobrow on 1/4/25.
//


import Foundation
import Combine

class TimesViewModel: ObservableObject {
    @Published var nextTrains: [Int] = []
    @Published var loading: Bool = false
    @Published var errorMessage: String = ""
    
    private var apiTimer: Timer?
    private var displayTimer: Timer?
    private var arrivalTimes: [Date] = []  // Store actual arrival times
    
    func startFetchingTimes(for line: SubwayLine, station: Station, direction: String) {
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
        
        // Set up display timer to update times every second
        displayTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.updateDisplayTimes()
        }
    }
    
    func stopFetchingTimes() {
        apiTimer?.invalidate()
        apiTimer = nil
    }
    
    private func updateDisplayTimes() {
        let currentTime = Date()
        nextTrains = arrivalTimes.compactMap { arrivalTime in
            let minutes = Calendar.current.dateComponents([.minute], from: currentTime, to: arrivalTime).minute ?? 0
            return minutes >= 0 ? minutes : nil  // Only show future times
        }.sorted()
        
        // Clean up past arrival times
        arrivalTimes = arrivalTimes.filter { arrivalTime in
            arrivalTime > currentTime
        }
    }
    
    private func fetchArrivalTimes(for line: SubwayLine, station: Station, direction: String) {
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
        
        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    self?.errorMessage = "Error: \(error.localizedDescription)"
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
                            self?.updateDisplayTimes()  // Update display immediately after getting new data
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
    
    private func extractArrivalDates(for line: SubwayLine, from stationData: StationData, direction: String) -> [Date] {
        let formatter = ISO8601DateFormatter()
        
        // Filter the train array based on the direction and line
        let trains: [Train]
        if direction == "N" {
            trains = stationData.N.filter { $0.route == line.id }
        } else {
            trains = stationData.S.filter { $0.route == line.id }
        }
        
        // Convert time strings to Date objects
        return trains.compactMap { train in
            formatter.date(from: train.time)
        }.filter { $0 > Date() }  // Only keep future times
    }
}

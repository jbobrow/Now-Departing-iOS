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
    
    private var timer: Timer?
    
    func startFetchingTimes(for line: SubwayLine, station: Station, direction: String) {
        fetchArrivalTimes(for: line, station: station, direction: direction)
        
        // Set up a timer to refresh the data every 10 seconds
        timer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { [weak self] _ in
            self?.fetchArrivalTimes(for: line, station: station, direction: direction)
        }
    }
    
    func stopFetchingTimes() {
        timer?.invalidate()
        timer = nil
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
                        self?.nextTrains = self?.extractArrivalTimes(for: line, from: stationData, direction: direction) ?? []
                    } else {
                        self?.errorMessage = "Station data not found"
                    }
                    self?.loading = false
                } catch {
                    self?.errorMessage = "Failed to decode data: \(error.localizedDescription)"
                    self?.loading = false
                }
            }
        }.resume()
    }
    
    private func extractArrivalTimes(for line: SubwayLine, from stationData: StationData, direction: String) -> [Int] {
        let currentTime = Date()
        let formatter = ISO8601DateFormatter()
        
        // Filter the train array based on the direction and line
        let trains: [Train]
        if direction == "N" {
            trains = stationData.N.filter { $0.route == line.id }
        } else {
            trains = stationData.S.filter { $0.route == line.id }
        }
        
        // Convert `time` values to minutes from now
        return trains.compactMap { train in
            if let trainTime = formatter.date(from: train.time) {
                let minutes = Calendar.current.dateComponents([.minute], from: currentTime, to: trainTime).minute
                return minutes ?? 0
            }
            return nil
        }.sorted() // Sort the times in ascending order
    }
}

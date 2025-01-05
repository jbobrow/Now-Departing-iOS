import Foundation
import Combine

class TimesViewModel: ObservableObject {
    @Published var nextTrains: [Int] = []
    @Published var loading: Bool = false
    @Published var errorMessage: String = ""
    
    private var timer: Timer?
    
    func startFetchingTimes(for line: SubwayLine, station: Station, terminal: String) {
        fetchArrivalTimes(for: line, station: station, terminal: terminal)
        
        // Set up a timer to refresh the data every 30 seconds
        timer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { _ in
            self.fetchArrivalTimes(for: line, station: station, terminal: terminal)
        }
    }
    
    func stopFetchingTimes() {
        timer?.invalidate()
        timer = nil
    }
    
    private func fetchArrivalTimes(for line: SubwayLine, station: Station, terminal: String) {
        let direction = getDirection(for: terminal, line: line)
        guard !direction.isEmpty else {
            errorMessage = "Invalid terminal station"
            loading = false
            return
        }
        
        let apiURL = "https://api.wheresthefuckingtrain.com/by-route/\(line.id)"
        
        guard let url = URL(string: apiURL) else {
            errorMessage = "Invalid URL"
            loading = false
            return
        }
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    errorMessage = "Error: \(error.localizedDescription)"
                    loading = false
                    return
                }
                
                guard let data = data else {
                    errorMessage = "No data received"
                    loading = false
                    return
                }
                
                do {
                    let response = try JSONDecoder().decode(APIResponse.self, from: data)
                    if let stationData = response.data.first(where: { $0.name == station.name }) {
                        nextTrains = extractArrivalTimes(for: line, from: stationData, direction: direction)
                    } else {
                        errorMessage = "Station data not found"
                    }
                    loading = false
                } catch {
                    errorMessage = "Failed to decode data: \(error.localizedDescription)"
                    loading = false
                }
            }
        }.resume()
    }
    
    private func extractArrivalTimes(for line: SubwayLine, from stationData: StationData, direction: String) -> [Int] {
        let currentTime = Date()
        let formatter = ISO8601DateFormatter()
        
        // Combine and filter the train arrays (`N` and `S`) for the selected route
        let trains = (stationData.N + stationData.S).filter { $0.route == line.id }
        
        // Convert `time` values to minutes from now
        return trains.compactMap { train in
            if let trainTime = formatter.date(from: train.time) {
                let minutes = Calendar.current.dateComponents([.minute], from: currentTime, to: trainTime).minute
                return minutes ?? 0
            }
            return nil
        }.sorted() // Sort the times in ascending order
    }
    
    private func getDirection(for terminal: String, line: SubwayLine) -> String {
        return terminal == line.terminals.first ? "N" : "S"
    }
}
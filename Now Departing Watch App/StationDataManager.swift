import Foundation

class StationDataManager: ObservableObject {
    @Published var stationsByLine: [String: [Station]] = [:]

    init() {
        loadStations()
    }

    private func loadStations() {
        guard let url = Bundle.main.url(forResource: "stations", withExtension: "json") else {
            print("Stations JSON not found")
            return
        }

        do {
            let data = try Data(contentsOf: url)
            let decodedData = try JSONDecoder().decode([String: [Station]].self, from: data)
            DispatchQueue.main.async {
                self.stationsByLine = decodedData
            }
        } catch {
            print("Error decoding stations JSON: \(error)")
        }
    }
}
//
//  NearbyTrainsManager.swift
//  Now Departing
//
//  Created by Jonathan Bobrow on 6/4/25.
//

import Foundation
import CoreLocation
import Combine

// API Response models for /by-location endpoint
struct LocationAPIResponse: Codable {
    let data: [LocationStationData]
    let updated: String
}

struct LocationStationData: Codable {
    let id: String  // Changed from Int to String
    let name: String
    let location: [Double] // [latitude, longitude]
    let routes: [String]
    let N: [LocationTrain]
    let S: [LocationTrain]
    let stops: [String: [Double]]?
    
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: location[0], longitude: location[1])
    }
    
    var clLocation: CLLocation {
        CLLocation(latitude: location[0], longitude: location[1])
    }
}

struct LocationTrain: Codable {
    let route: String
    let time: String
}

class NearbyTrainsManager: ObservableObject {
    @Published var nearbyTrains: [NearbyTrain] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String = ""
    
    private var refreshTimer: Timer?
    private var currentLocation: CLLocation?
    private var apiTimeout: Timer?
    
    func startFetching(location: CLLocation) {
        currentLocation = location
        stopFetching()
        fetchNearbyTrains(location: location)
        
        // Refresh every 60 seconds
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.fetchNearbyTrains(location: location)
        }
    }
    
    func stopFetching() {
        refreshTimer?.invalidate()
        refreshTimer = nil
        apiTimeout?.invalidate()
        apiTimeout = nil
    }
    
    private func fetchNearbyTrains(location: CLLocation) {
        // Don't start a new request if one is already in progress
        guard !isLoading else { return }
        
        isLoading = true
        errorMessage = ""
        
        let lat = location.coordinate.latitude
        let lon = location.coordinate.longitude
        let apiURL = "https://api.wheresthefuckingtrain.com/by-location?lat=\(lat)&lon=\(lon)"
        
        print("DEBUG: Fetching from URL: \(apiURL)")
        
        guard let url = URL(string: apiURL) else {
            DispatchQueue.main.async {
                self.errorMessage = "Invalid URL"
                self.isLoading = false
            }
            return
        }
        
        // Set a timeout for the API request
        apiTimeout = Timer.scheduledTimer(withTimeInterval: 15.0, repeats: false) { [weak self] _ in
            DispatchQueue.main.async {
                if self?.isLoading == true {
                    self?.errorMessage = "Request timed out. Please try again."
                    self?.isLoading = false
                }
            }
        }
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 15.0
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                // Cancel the timeout timer
                self.apiTimeout?.invalidate()
                self.apiTimeout = nil
                
                // Check if we're still supposed to be loading
                guard self.isLoading else { return }
                
                if let error = error {
                    print("DEBUG: Network error: \(error)")
                    if let urlError = error as? URLError {
                        switch urlError.code {
                        case .notConnectedToInternet:
                            self.errorMessage = "No internet connection"
                        case .timedOut:
                            self.errorMessage = "Request timed out"
                        case .cannotFindHost, .cannotConnectToHost:
                            self.errorMessage = "Cannot connect to server"
                        default:
                            self.errorMessage = "Network error: \(error.localizedDescription)"
                        }
                    } else {
                        self.errorMessage = "Network error: \(error.localizedDescription)"
                    }
                    self.isLoading = false
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    self.errorMessage = "Invalid server response"
                    self.isLoading = false
                    return
                }
                
                print("DEBUG: HTTP Status Code: \(httpResponse.statusCode)")
                
                guard (200...299).contains(httpResponse.statusCode) else {
                    self.errorMessage = "Server error (\(httpResponse.statusCode))"
                    self.isLoading = false
                    return
                }
                
                guard let data = data else {
                    self.errorMessage = "No data received"
                    self.isLoading = false
                    return
                }
                
                print("DEBUG: Received data: \(data.count) bytes")
                
                do {
                    let apiResponse = try JSONDecoder().decode(LocationAPIResponse.self, from: data)
                    print("DEBUG: Decoded \(apiResponse.data.count) stations")
                    self.processLocationData(apiResponse.data, userLocation: location)
                } catch {
                    print("DEBUG: Decode error: \(error)")
                    
                    // Let's try to see what the raw JSON looks like
                    if let jsonString = String(data: data, encoding: .utf8) {
                        print("DEBUG: Raw JSON (first 500 chars): \(String(jsonString.prefix(500)))")
                    }
                    
                    self.errorMessage = "Failed to process data"
                    self.isLoading = false
                }
            }
        }.resume()
    }
    
    private func processLocationData(_ stations: [LocationStationData], userLocation: CLLocation) {
        print("DEBUG: Processing \(stations.count) stations")
        
        var allTrains: [NearbyTrain] = []
        
        for station in stations {
            let hasData = !station.N.isEmpty || !station.S.isEmpty
            print("DEBUG: Station \(station.name) - hasData: \(hasData), N: \(station.N.count), S: \(station.S.count)")
            
            guard hasData else {
                print("DEBUG: Skipping \(station.name) - no data")
                continue
            }
            
            let distance = userLocation.distance(from: station.clLocation)
            
            // Process northbound trains
            for train in station.N {
                // Only process routes that we have in our subway configuration
                guard isValidRoute(train.route) else {
                    print("DEBUG: Skipping unknown route: \(train.route)")
                    continue
                }
                
                if let arrivalTime = parseArrivalTime(train.time) {
                    let timeInterval = arrivalTime.timeIntervalSinceNow
                    let minutes = max(0, Int(timeInterval / 60))
                    
                    // Only include trains that haven't departed yet (timeInterval > 0) and arrive within 30 minutes
                    if timeInterval > 0 && minutes <= 30 {
                        let nearbyTrain = NearbyTrain(
                            lineId: train.route,
                            stationName: station.name,
                            stationDisplay: getStationDisplayName(station.name),
                            direction: "N",
                            destination: DirectionHelper.getDestination(for: train.route, direction: "N"),
                            arrivalTime: arrivalTime,  // Store the actual arrival time
                            distanceInMeters: distance
                        )
                        allTrains.append(nearbyTrain)
                        print("DEBUG: Added N train: \(train.route) at \(station.name) arriving at \(arrivalTime)")
                    } else if timeInterval <= 0 {
                        print("DEBUG: Skipping departed N train: \(train.route) at \(station.name) (departed \(Int(-timeInterval/60))m ago)")
                    }
                }
            }
            
            // Process southbound trains
            for train in station.S {
                // Only process routes that we have in our subway configuration
                guard isValidRoute(train.route) else {
                    print("DEBUG: Skipping unknown route: \(train.route)")
                    continue
                }
                
                if let arrivalTime = parseArrivalTime(train.time) {
                    let timeInterval = arrivalTime.timeIntervalSinceNow
                    let minutes = max(0, Int(timeInterval / 60))
                    
                    // Only include trains that haven't departed yet (timeInterval > 0) and arrive within 30 minutes
                    if timeInterval > 0 && minutes <= 30 {
                        let nearbyTrain = NearbyTrain(
                            lineId: train.route,
                            stationName: station.name,
                            stationDisplay: getStationDisplayName(station.name),
                            direction: "S",
                            destination: DirectionHelper.getDestination(for: train.route, direction: "S"),
                            arrivalTime: arrivalTime,  // Store the actual arrival time
                            distanceInMeters: distance
                        )
                        allTrains.append(nearbyTrain)
                        print("DEBUG: Added S train: \(train.route) at \(station.name) arriving at \(arrivalTime)")
                    } else if timeInterval <= 0 {
                        print("DEBUG: Skipping departed S train: \(train.route) at \(station.name) (departed \(Int(-timeInterval/60))m ago)")
                    }
                }
            }
        }
        
        print("DEBUG: Total trains found: \(allTrains.count)")
        
        // Sort by arrival time first, then by distance, and take the first 12
        let sortedTrains = allTrains.sorted { train1, train2 in
            let time1 = train1.arrivalTime.timeIntervalSinceNow
            let time2 = train2.arrivalTime.timeIntervalSinceNow
            
            if abs(time1 - time2) < 60 { // If within 1 minute, sort by distance
                return train1.distanceInMeters < train2.distanceInMeters
            }
            return time1 < time2
        }
        
        self.nearbyTrains = Array(sortedTrains)
        self.isLoading = false
        
        if self.nearbyTrains.isEmpty {
            self.errorMessage = "No trains found within 30 minutes"
        } else {
            self.errorMessage = ""
        }
        
        print("DEBUG: Final trains to display: \(self.nearbyTrains.count)")
    }
    
    private func isValidRoute(_ routeId: String) -> Bool {
        // Check if this route exists in our subway line configuration
        let validRoutes = ["1", "2", "3", "4", "5", "6", "7", "A", "B", "C", "D", "E", "F", "G", "J", "L", "M", "N", "Q", "R", "W", "Z"]
        return validRoutes.contains(routeId)
    }
    
    private func parseArrivalTime(_ timeString: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        return formatter.date(from: timeString)
    }
    
    private func getStationDisplayName(_ stationName: String) -> String {
        // Clean up station names for better display
        let cleanedName = stationName
            .replacingOccurrences(of: " / ", with: "/")
            .replacingOccurrences(of: "-", with: "–")
        
        // Common name simplifications for Apple Watch display
        let commonMappings: [String: String] = [
            "Broadway-Lafayette St/Bleecker St": "Broadway-Lafayette",
            "Times Sq-42 St": "Times Square",
            "14 St-Union Sq": "Union Square",
            "Grand Central-42 St": "Grand Central",
            "34 St-Penn Station": "Penn Station",
            "Brooklyn Bridge-City Hall/Chambers St": "Brooklyn Bridge",
            "Atlantic Av-Barclays Ctr": "Barclays Center",
            "59 St-Columbus Circle": "Columbus Circle",
            "34 St-Herald Sq": "Herald Square",
            "Court St/Borough Hall": "Borough Hall",
            "Roosevelt Av/74 St-Broadway": "Roosevelt Ave",
            "Spring St/Prince St": "Spring St",
            "Canal St": "Canal Street",
            "14 St/8 Av": "14th & 8th",
            "14 St/6 Av": "14th & 6th",
            "Lexington Av/59 St": "Lex & 59th",
            "Lexington Av/63 St": "Lex & 63rd"
        ]
        
        return commonMappings[stationName] ?? cleanedName
    }
}

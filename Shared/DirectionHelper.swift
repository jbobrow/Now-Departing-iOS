//
//  DirectionHelper.swift
//  Now Departing
//
//  Created by Jonathan Bobrow on 6/4/25.
//

import Foundation

struct DirectionHelper {
    
    /// Map of subway line destinations by direction
    private static let destinations: [String: (north: String, south: String)] = [
        "1": ("Uptown", "Downtown"),
        "2": ("Uptown", "Brooklyn"),
        "3": ("Uptown", "Brooklyn"),
        "4": ("Uptown", "Brooklyn"),
        "5": ("Uptown", "Brooklyn"),
        "6": ("Uptown", "Downtown"),
        "6X": ("Uptown Express", "Downtown Express"),
        "7": ("Queens", "Manhattan"),
        "7X": ("Queens Express", "Manhattan Express"),
        "A": ("Uptown", "Brooklyn/Queens"),
        "B": ("Uptown", "Brooklyn"),
        "C": ("Uptown", "Brooklyn"),
        "D": ("Uptown", "Brooklyn"),
        "E": ("Queens", "Downtown"),
        "F": ("Queens", "Brooklyn"),
        "G": ("Queens", "Brooklyn"),
        "J": ("Queens", "Manhattan"),
        "L": ("Brooklyn", "Manhattan"),
        "M": ("Queens", "Brooklyn"),
        "N": ("Queens", "Brooklyn"),
        "Q": ("Uptown", "Brooklyn"),
        "R": ("Queens", "Brooklyn"),
        "W": ("Queens", "Manhattan"),
        "Z": ("Queens", "Manhattan")
    ]
    
    /// Get the destination name for a given line and direction
    /// - Parameters:
    ///   - lineId: The subway line ID (e.g., "1", "A", "7X")
    ///   - direction: The direction ("N" for north, "S" for south)
    /// - Returns: The destination name (e.g., "Uptown", "Brooklyn", "Queens")
    static func getDestination(for lineId: String, direction: String) -> String {
        let dest = destinations[lineId] ?? (north: "Uptown", south: "Downtown")
        return direction == "N" ? dest.north : dest.south
    }
    
    /// Get both destinations for a given line
    /// - Parameter lineId: The subway line ID
    /// - Returns: A tuple with (north: String, south: String) destinations
    static func getDestinations(for lineId: String) -> (north: String, south: String) {
        return destinations[lineId] ?? (north: "Uptown", south: "Downtown")
    }
    
    /// Get a formatted direction string with destination
    /// - Parameters:
    ///   - lineId: The subway line ID
    ///   - direction: The direction ("N" for north, "S" for south)
    /// - Returns: Formatted string like "Uptown (N)" or "Brooklyn (S)"
    static func getFormattedDirection(for lineId: String, direction: String) -> String {
        let destination = getDestination(for: lineId, direction: direction)
        return "\(destination) (\(direction))"
    }
    
    /// Get a simple "to" prefixed destination string
    /// - Parameters:
    ///   - lineId: The subway line ID
    ///   - direction: The direction ("N" for north, "S" for south)
    /// - Returns: Formatted string like "to Uptown" or "to Brooklyn"
    static func getToDestination(for lineId: String, direction: String) -> String {
        let destination = getDestination(for: lineId, direction: direction)
        return "to \(destination)"
    }
    
    // MARK: - Terminal Station Functions
    
    /// Get the terminal station for a specific line and direction using station data
    /// - Parameters:
    ///   - lineId: The subway line ID
    ///   - direction: The direction ("N" for north, "S" for south)
    ///   - stationDataManager: The station data manager containing station information
    /// - Returns: The terminal station for the given line and direction, or nil if not found
    static func getTerminalStation(for lineId: String, direction: String, stationDataManager: StationDataManager) -> Station? {
        guard let stations = stationDataManager.stations(for: lineId), !stations.isEmpty else {
            return nil
        }
        
        // For northbound (N), return the first station (typically the northern terminus)
        // For southbound (S), return the last station (typically the southern terminus)
        return direction == "N" ? stations.first : stations.last
    }
    
    /// Get both terminal stations for a given line
    /// - Parameters:
    ///   - lineId: The subway line ID
    ///   - stationDataManager: The station data manager containing station information
    /// - Returns: A tuple with (north: Station?, south: Station?) terminals
    static func getTerminalStations(for lineId: String, stationDataManager: StationDataManager) -> (north: Station?, south: Station?) {
        guard let stations = stationDataManager.stations(for: lineId), !stations.isEmpty else {
            return (north: nil, south: nil)
        }
        
        return (north: stations.first, south: stations.last)
    }
    
    /// Get the terminal station name for a specific line and direction
    /// - Parameters:
    ///   - lineId: The subway line ID
    ///   - direction: The direction ("N" for north, "S" for south)
    ///   - stationDataManager: The station data manager containing station information
    /// - Returns: The display name of the terminal station, or nil if not found
    static func getTerminalStationName(for lineId: String, direction: String, stationDataManager: StationDataManager) -> String? {
        return getTerminalStation(for: lineId, direction: direction, stationDataManager: stationDataManager)?.display
    }
    
    /// Get both terminal station names for a given line
    /// - Parameters:
    ///   - lineId: The subway line ID
    ///   - stationDataManager: The station data manager containing station information
    /// - Returns: A tuple with (north: String?, south: String?) terminal station names
    static func getTerminalStationNames(for lineId: String, stationDataManager: StationDataManager) -> (north: String?, south: String?) {
        let terminals = getTerminalStations(for: lineId, stationDataManager: stationDataManager)
        return (north: terminals.north?.display, south: terminals.south?.display)
    }
    
    /// Get a formatted string showing the terminal station for a direction
    /// - Parameters:
    ///   - lineId: The subway line ID
    ///   - direction: The direction ("N" for north, "S" for south)
    ///   - stationDataManager: The station data manager containing station information
    /// - Returns: Formatted string like "to Van Cortlandt Park-242nd Street" or fallback to destination
    static func getToTerminalStation(for lineId: String, direction: String, stationDataManager: StationDataManager) -> String {
        if let terminalName = getTerminalStationName(for: lineId, direction: direction, stationDataManager: stationDataManager) {
            return "to \(terminalName)"
        } else {
            // Fallback to the destination-based approach
            return getToDestination(for: lineId, direction: direction)
        }
    }
}

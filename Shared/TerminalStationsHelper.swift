//
//  TerminalStationsHelper.swift
//  Now Departing
//
//  Lightweight terminal station helper for widgets and contexts
//  where StationDataManager is not available
//

import Foundation

struct TerminalStationsHelper {
    /// Static mapping of terminal stations by line and direction
    /// Used in widgets and other lightweight contexts
    private static let terminals: [String: (north: String, south: String)] = [
        "1": (north: "Van Cortlandt Park", south: "South Ferry"),
        "2": (north: "Wakefield", south: "Flatbush Av"),
        "3": (north: "Harlem", south: "New Lots Av"),
        "4": (north: "Woodlawn", south: "New Lots Av/Crown Hts"),
        "5": (north: "Eastchester", south: "Flatbush Av"),
        "6": (north: "Pelham Bay Park", south: "Brooklyn Bridge"),
        "7": (north: "Flushing", south: "Hudson Yards"),
        "A": (north: "Inwood", south: "Far Rockaway/Lefferts"),
        "C": (north: "Washington Heights", south: "Euclid Av"),
        "E": (north: "Jamaica Center", south: "World Trade Center"),
        "G": (north: "Court Sq", south: "Church Av"),
        "B": (north: "Bedford Park", south: "Brighton Beach"),
        "D": (north: "Norwood", south: "Coney Island"),
        "F": (north: "Jamaica", south: "Coney Island"),
        "M": (north: "Forest Hills", south: "Middle Village"),
        "N": (north: "Astoria", south: "Coney Island"),
        "Q": (north: "96 St", south: "Coney Island"),
        "R": (north: "Forest Hills", south: "Bay Ridge"),
        "W": (north: "Astoria", south: "Whitehall St"),
        "J": (north: "Jamaica Center", south: "Broad St"),
        "Z": (north: "Jamaica Center", south: "Broad St"),
        "L": (north: "8 Av", south: "Canarsie"),
        "X": (north: "Pelham Bay Park", south: "Brooklyn Bridge") // Same as 6 express
    ]

    /// Get the terminal station name for a given line and direction
    /// - Parameters:
    ///   - lineId: The subway line ID (e.g., "1", "A", "L")
    ///   - direction: The direction ("N" for north, "S" for south)
    /// - Returns: The terminal station name
    static func getTerminalStation(for lineId: String, direction: String) -> String {
        guard let terminal = terminals[lineId] else {
            return direction == "N" ? "Northbound" : "Southbound"
        }
        return direction == "N" ? terminal.north : terminal.south
    }

    /// Get formatted terminal station with "to" prefix
    /// - Parameters:
    ///   - lineId: The subway line ID
    ///   - direction: The direction ("N" for north, "S" for south)
    /// - Returns: Formatted string like "to Van Cortlandt Park"
    static func getToTerminalStation(for lineId: String, direction: String) -> String {
        return "to \(getTerminalStation(for: lineId, direction: direction))"
    }

    /// Get both terminal stations for a line
    /// - Parameter lineId: The subway line ID
    /// - Returns: Tuple of (north, south) terminal names
    static func getTerminals(for lineId: String) -> (north: String, south: String) {
        return terminals[lineId] ?? (north: "Northbound", south: "Southbound")
    }
}

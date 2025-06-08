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
}

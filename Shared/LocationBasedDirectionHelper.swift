//
//  LocationBasedDirectionHelper.swift
//  Now Departing
//
//  Created by Jonathan Bobrow on 8/20/25.
//

import Foundation
import CoreLocation

struct LocationBasedDirectionHelper {
    
    enum Borough {
        case manhattan
        case brooklyn
        case queens
        case bronx
        case statenIsland
        case unknown
    }
    
    /// Determine which borough a coordinate is in
    static func getBoroughForLocation(_ location: CLLocation) -> Borough {
        let lat = location.coordinate.latitude
        let lon = location.coordinate.longitude
        
        // Manhattan: longitude -74.02 to -73.93, latitude 40.70 to 40.88
        if lon >= -74.02 && lon <= -73.93 && lat >= 40.70 && lat <= 40.88 {
            return .manhattan
        }
        
        // Brooklyn: south of latitude 40.74, west of longitude -73.85
        if lat < 40.74 && lon < -73.85 {
            return .brooklyn
        }
        
        // Queens: east of longitude -73.95, north of latitude 40.67
        if lon > -73.95 && lat > 40.67 {
            return .queens
        }
        
        // Bronx: north of latitude 40.79
        if lat > 40.79 {
            return .bronx
        }
        
        // Staten Island: south of latitude 40.65, west of longitude -74.05
        if lat < 40.65 && lon > -74.05 {
            return .statenIsland
        }
        
        return .unknown
    }
    
    /// Get a contextual destination based on current location and train direction
    static func getContextualDestination(for lineId: String, direction: String, currentLocation: CLLocation?) -> String {
        // Fallback to original helper if no location
        guard let location = currentLocation else {
            return DirectionHelper.getDestination(for: lineId, direction: direction)
        }
        
        let currentBorough = getBoroughForLocation(location)
        
        // Get general line destinations to help determine where trains go
        let destinations = DirectionHelper.getDestinations(for: lineId)
        
        switch currentBorough {
        case .manhattan:
            // In Manhattan, use Uptown/Downtown for north-south lines
            if isNorthSouthLine(lineId) {
                let manhattanDirection = direction == "N" ? "Uptown" : "Downtown"
                if let ultimateDestination = getUltimateDestination(lineId, direction: direction) {
                    return "\(manhattanDirection) & \(ultimateDestination)"
                } else {
                    return manhattanDirection
                }
            } else {
                // For cross-borough lines, show the destination borough
                return direction == "N" ? destinations.north : destinations.south
            }
            
        case .brooklyn:
            // In Brooklyn, show direction relative to Manhattan or use existing logic
            if direction == "N" {
                // Most northbound trains from Brooklyn go to Manhattan, except G train
                if linesManhattanBound(lineId) {
                    return "Manhattan"
                } else {
                    // G train goes to Queens from Brooklyn
                    return lineId == "G" ? "Queens" : "Northbound"
                }
            } else {
                // Southbound in Brooklyn - keep it simple
                return "Southbound"
            }
            
        case .queens:
            // In Queens, show direction relative to Manhattan or use existing logic
            if direction == "S" {
                // Most southbound trains from Queens go to Manhattan, except G train
                if linesManhattanBound(lineId) {
                    return "Manhattan"
                } else {
                    // G train goes to Brooklyn from Queens
                    return lineId == "G" ? "Brooklyn" : "Southbound"
                }
            } else {
                // Northbound could be deeper into Queens or other boroughs
                return destinations.north
            }
            
        case .bronx:
            // In Bronx, southbound usually goes to Manhattan
            if direction == "S" {
                if linesManhattanBound(lineId) {
                    return "Manhattan"
                } else {
                    return "Southbound"
                }
            } else {
                return destinations.north
            }
            
        case .statenIsland:
            // Staten Island doesn't have subway, but just in case
            return direction == "N" ? destinations.north : destinations.south
            
        case .unknown:
            // Use original logic for unknown locations
            return DirectionHelper.getDestination(for: lineId, direction: direction)
        }
    }
    
    /// Get the ultimate destination borough for a line in a given direction
    private static func getUltimateDestination(_ lineId: String, direction: String) -> String? {
        let lineDestinations: [String: (north: String?, south: String?)] = [
            "1": (north: nil, south: nil), // Stays in Manhattan
            "2": (north: "Bronx", south: "Brooklyn"),
            "3": (north: "Bronx", south: "Brooklyn"),
            "4": (north: "Bronx", south: "Brooklyn"),
            "5": (north: "Bronx", south: "Brooklyn"),
            "6": (north: "Bronx", south: nil), // Stays in Manhattan
            "7": (north: "Queens", south: nil), // Stays in Manhattan
            "A": (north: nil, south: "Queens"), // A goes uptown to Harlem, downtown to Far Rockaway
            "B": (north: "Bronx", south: "Brooklyn"),
            "C": (north: nil, south: "Brooklyn"), // C goes to Brooklyn
            "D": (north: "Bronx", south: "Brooklyn"),
            "E": (north: "Queens", south: nil), // E goes to Queens
            "F": (north: "Queens", south: "Brooklyn"),
            "G": (north: "Queens", south: "Brooklyn"), // G only runs Brooklyn-Queens
            "J": (north: "Queens", south: nil),
            "L": (north: nil, south: "Brooklyn"), // L runs east-west
            "M": (north: "Queens", south: "Brooklyn"),
            "N": (north: "Queens", south: "Brooklyn"),
            "Q": (north: nil, south: "Brooklyn"), // Q goes to Brooklyn
            "R": (north: "Queens", south: "Brooklyn"),
            "W": (north: "Queens", south: nil),
            "Z": (north: "Queens", south: nil)
        ]
        
        let destinations = lineDestinations[lineId]
        return direction == "N" ? destinations?.north : destinations?.south
    }

    /// Check if a line primarily runs north-south through Manhattan
    private static func isNorthSouthLine(_ lineId: String) -> Bool {
        let northSouthLines = ["1", "2", "3", "4", "5", "6", "A", "B", "C", "D", "Q", "R", "W"]
        return northSouthLines.contains(lineId)
    }
    
    /// Check if a line connects to Manhattan
    private static func linesManhattanBound(_ lineId: String) -> Bool {
        // Lines that do NOT go to Manhattan
        let nonManhattanLines = ["G"] // G train only runs Brooklyn-Queens
        return !nonManhattanLines.contains(lineId)
    }
    
    /// Get a "to" prefixed contextual destination
    static func getToContextualDestination(for lineId: String, direction: String, currentLocation: CLLocation?) -> String {
        let destination = getContextualDestination(for: lineId, direction: direction, currentLocation: currentLocation)
        return "\(destination)"
    }
}

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
                return direction == "N" ? "Uptown" : "Downtown"
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

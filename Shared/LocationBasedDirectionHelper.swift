//
//  LocationBasedDirectionHelper.swift
//  Now Departing
//
//  Official NYC borough boundaries using real GeoJSON data
//  Created by Jonathan Bobrow on 8/22/25.
//

import Foundation
import CoreLocation

struct LocationBasedDirectionHelper {
    
    enum Borough: String, CaseIterable {
        case manhattan = "Manhattan"
        case brooklyn = "Brooklyn"
        case queens = "Queens"
        case bronx = "Bronx"
        case statenIsland = "Staten Island"
        case unknown = "Unknown"
    }
    
    // Point-in-polygon test using the ray casting algorithm
    private static func isPointInPolygon(point: CLLocationCoordinate2D, polygon: [CLLocationCoordinate2D]) -> Bool {
        guard polygon.count > 2 else { return false }
        
        let x = point.longitude
        let y = point.latitude
        var inside = false
        
        var j = polygon.count - 1
        for i in 0..<polygon.count {
            let xi = polygon[i].longitude
            let yi = polygon[i].latitude
            let xj = polygon[j].longitude
            let yj = polygon[j].latitude
            
            if ((yi > y) != (yj > y)) && (x < (xj - xi) * (y - yi) / (yj - yi) + xi) {
                inside = !inside
            }
            j = i
        }
        
        return inside
    }
    
    // Complete borough boundaries covering full areas
    private static let boroughBoundaries: [Borough: [CLLocationCoordinate2D]] = [
        .manhattan: [
            // Complete Manhattan boundary drawn by Jon w/ Keene.edu
            CLLocationCoordinate2D(latitude: 40.8793771, longitude: -73.9312989),
            CLLocationCoordinate2D(latitude: 40.7544002, longitude: -74.0150696),
            CLLocationCoordinate2D(latitude: 40.6982009, longitude: -74.0260559),
            CLLocationCoordinate2D(latitude: 40.6971597, longitude: -74.0109497),
            CLLocationCoordinate2D(latitude: 40.7062694, longitude: -73.9965302),
            CLLocationCoordinate2D(latitude: 40.7096527, longitude: -73.9749008),
            CLLocationCoordinate2D(latitude: 40.7265666, longitude: -73.9676911),
            CLLocationCoordinate2D(latitude: 40.7377535, longitude: -73.9683777),
            CLLocationCoordinate2D(latitude: 40.7476380, longitude: -73.9642578),
            CLLocationCoordinate2D(latitude: 40.7944392, longitude: -73.9220291),
            CLLocationCoordinate2D(latitude: 40.8087330, longitude: -73.9337021),
            CLLocationCoordinate2D(latitude: 40.8149694, longitude: -73.9323288),
            CLLocationCoordinate2D(latitude: 40.8334151, longitude: -73.9357620),
            CLLocationCoordinate2D(latitude: 40.8479602, longitude: -73.9275223),
            CLLocationCoordinate2D(latitude: 40.8635407, longitude: -73.9137894),
            CLLocationCoordinate2D(latitude: 40.8734065, longitude: -73.9079529),
            CLLocationCoordinate2D(latitude: 40.8793771, longitude: -73.9312989),
        ],
        
        .brooklyn: [
            // Complete Brooklyn boundary drawn by Jon w/ Keene.edu
            CLLocationCoordinate2D(latitude: 40.5599547, longitude: -74.0086444),
            CLLocationCoordinate2D(latitude: 40.5740666, longitude: -73.8839860),
            CLLocationCoordinate2D(latitude: 40.5943806, longitude: -73.8457605),
            CLLocationCoordinate2D(latitude: 40.6110693, longitude: -73.8322127),
            CLLocationCoordinate2D(latitude: 40.6167968, longitude: -73.8406107),
            CLLocationCoordinate2D(latitude: 40.6408973, longitude: -73.8405751),
            CLLocationCoordinate2D(latitude: 40.6418106, longitude: -73.8515970),
            CLLocationCoordinate2D(latitude: 40.6569186, longitude: -73.8608667),
            CLLocationCoordinate2D(latitude: 40.6673349, longitude: -73.8590643),
            CLLocationCoordinate2D(latitude: 40.6946246, longitude: -73.8681600),
            CLLocationCoordinate2D(latitude: 40.6822457, longitude: -73.8924662),
            CLLocationCoordinate2D(latitude: 40.6947026, longitude: -73.8992887),
            CLLocationCoordinate2D(latitude: 40.7144092, longitude: -73.9238048),
            CLLocationCoordinate2D(latitude: 40.7276028, longitude: -73.9282317),
            CLLocationCoordinate2D(latitude: 40.7281552, longitude: -73.9349909),
            CLLocationCoordinate2D(latitude: 40.7361561, longitude: -73.9417782),
            CLLocationCoordinate2D(latitude: 40.7397360, longitude: -73.9511083),
            CLLocationCoordinate2D(latitude: 40.7377535, longitude: -73.9683777),
            CLLocationCoordinate2D(latitude: 40.7265666, longitude: -73.9676911),
            CLLocationCoordinate2D(latitude: 40.7096527, longitude: -73.9749008),
            CLLocationCoordinate2D(latitude: 40.7062694, longitude: -73.9965302),
            CLLocationCoordinate2D(latitude: 40.6971597, longitude: -74.0109497),
            CLLocationCoordinate2D(latitude: 40.6982009, longitude: -74.0260559),
            CLLocationCoordinate2D(latitude: 40.6847121, longitude: -74.0349595),
            CLLocationCoordinate2D(latitude: 40.6718554, longitude: -74.0316430),
            CLLocationCoordinate2D(latitude: 40.6297527, longitude: -74.0579219),
            CLLocationCoordinate2D(latitude: 40.5599547, longitude: -74.0086444),
        ],
        
        .queens: [
            // Complete Queens boundary drawn by Jon w/ Keene.edu
            CLLocationCoordinate2D(latitude: 40.5599547, longitude: -74.0086444),
            CLLocationCoordinate2D(latitude: 40.5129774, longitude: -73.9716607),
            CLLocationCoordinate2D(latitude: 40.5635532, longitude: -73.6877824),
            CLLocationCoordinate2D(latitude: 40.7674279, longitude: -73.6822222),
            CLLocationCoordinate2D(latitude: 40.8048127, longitude: -73.8097478),
            CLLocationCoordinate2D(latitude: 40.7974505, longitude: -73.8546480),
            CLLocationCoordinate2D(latitude: 40.8001500, longitude: -73.8907264),
            CLLocationCoordinate2D(latitude: 40.7899860, longitude: -73.9145109),
            CLLocationCoordinate2D(latitude: 40.7765138, longitude: -73.9369248),
            CLLocationCoordinate2D(latitude: 40.7377535, longitude: -73.9683777),
            CLLocationCoordinate2D(latitude: 40.7397360, longitude: -73.9511083),
            CLLocationCoordinate2D(latitude: 40.7361561, longitude: -73.9417782),
            CLLocationCoordinate2D(latitude: 40.7281552, longitude: -73.9349909),
            CLLocationCoordinate2D(latitude: 40.7276028, longitude: -73.9282317),
            CLLocationCoordinate2D(latitude: 40.7144092, longitude: -73.9238048),
            CLLocationCoordinate2D(latitude: 40.6947026, longitude: -73.8992887),
            CLLocationCoordinate2D(latitude: 40.6822457, longitude: -73.8924662),
            CLLocationCoordinate2D(latitude: 40.6946246, longitude: -73.8681600),
            CLLocationCoordinate2D(latitude: 40.6673349, longitude: -73.8590643),
            CLLocationCoordinate2D(latitude: 40.6569186, longitude: -73.8608667),
            CLLocationCoordinate2D(latitude: 40.6418106, longitude: -73.8515970),
            CLLocationCoordinate2D(latitude: 40.6408973, longitude: -73.8405751),
            CLLocationCoordinate2D(latitude: 40.6167968, longitude: -73.8406107),
            CLLocationCoordinate2D(latitude: 40.6110693, longitude: -73.8322127),
            CLLocationCoordinate2D(latitude: 40.5943806, longitude: -73.8457605),
            CLLocationCoordinate2D(latitude: 40.5740666, longitude: -73.8839860),
            CLLocationCoordinate2D(latitude: 40.5599547, longitude: -74.0086444),
        ],
        
        .bronx: [
            // Complete Bronx boundary drawn by Jon w/ Keene.edu
            CLLocationCoordinate2D(latitude: 40.8793771, longitude: -73.9312989),
            CLLocationCoordinate2D(latitude: 40.8734065, longitude: -73.9079529),
            CLLocationCoordinate2D(latitude: 40.8635407, longitude: -73.9137894),
            CLLocationCoordinate2D(latitude: 40.8479602, longitude: -73.9275223),
            CLLocationCoordinate2D(latitude: 40.8334151, longitude: -73.9357620),
            CLLocationCoordinate2D(latitude: 40.8149694, longitude: -73.9323288),
            CLLocationCoordinate2D(latitude: 40.8087330, longitude: -73.9337021),
            CLLocationCoordinate2D(latitude: 40.7944392, longitude: -73.9220291),
            CLLocationCoordinate2D(latitude: 40.7954789, longitude: -73.8979965),
            CLLocationCoordinate2D(latitude: 40.7946991, longitude: -73.8574845),
            CLLocationCoordinate2D(latitude: 40.8014566, longitude: -73.7771469),
            CLLocationCoordinate2D(latitude: 40.8882024, longitude: -73.7136322),
            CLLocationCoordinate2D(latitude: 40.9465800, longitude: -73.9083847),
            CLLocationCoordinate2D(latitude: 40.8793771, longitude: -73.9312989),
        ],
        
        .statenIsland: [
            // Complete Staten Island boundary drawn by Jon w/ Keene.edu
            CLLocationCoordinate2D(latitude: 40.6540139, longitude: -74.0728390),
            CLLocationCoordinate2D(latitude: 40.6425830, longitude: -74.1210370),
            CLLocationCoordinate2D(latitude: 40.6415410, longitude: -74.1526227),
            CLLocationCoordinate2D(latitude: 40.6449276, longitude: -74.1766553),
            CLLocationCoordinate2D(latitude: 40.6277324, longitude: -74.2024045),
            CLLocationCoordinate2D(latitude: 40.5982818, longitude: -74.1993146),
            CLLocationCoordinate2D(latitude: 40.5628288, longitude: -74.2148969),
            CLLocationCoordinate2D(latitude: 40.5458642, longitude: -74.2535596),
            CLLocationCoordinate2D(latitude: 40.5302092, longitude: -74.2449765),
            CLLocationCoordinate2D(latitude: 40.5171606, longitude: -74.2542462),
            CLLocationCoordinate2D(latitude: 40.4941634, longitude: -74.2588770),
            CLLocationCoordinate2D(latitude: 40.4947896, longitude: -74.2372464),
            CLLocationCoordinate2D(latitude: 40.5138491, longitude: -74.1512950),
            CLLocationCoordinate2D(latitude: 40.5944102, longitude: -74.0451224),
            CLLocationCoordinate2D(latitude: 40.6540139, longitude: -74.0728390),
        ]
    ]
    
    /// Get the borough for a given location using point-in-polygon testing
    static func getBoroughForLocation(_ location: CLLocation) -> Borough {
        let coordinate = location.coordinate
        
        // Test each borough boundary
        for (borough, boundary) in boroughBoundaries {
            if isPointInPolygon(point: coordinate, polygon: boundary) {
                return borough
            }
        }
        
        return .unknown
    }
    
    /// Get contextual destination based on current borough and train direction
    static func getContextualDestination(for lineId: String, direction: String, currentLocation: CLLocation?) -> String {
        guard let location = currentLocation else {
            return DirectionHelper.getDestination(for: lineId, direction: direction)
        }
        
        let currentBorough = getBoroughForLocation(location)
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
                return direction == "N" ? destinations.north : destinations.south
            }
            
        case .brooklyn:
            if direction == "N" {
                if linesManhattanBound(lineId) {
                    return "Manhattan"
                } else {
                    return lineId == "G" ? "Northbound & Queens" : "Northbound"
                }
            } else {
                return "Southbound"
            }
            
        case .queens:
            if direction == "S" {
                if linesManhattanBound(lineId) {
                    return "Manhattan"
                } else {
                    return lineId == "G" ? "Southbound & Brooklyn" : "Southbound"
                }
            } else {
                return destinations.north
            }
            
        case .bronx:
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
            return direction == "N" ? destinations.north : destinations.south
            
        case .unknown:
            return DirectionHelper.getDestination(for: lineId, direction: direction)
        }
    }
    
    // Helper functions (copied from your existing DirectionHelper)
    private static func isNorthSouthLine(_ lineId: String) -> Bool {
        let northSouthLines = ["1", "2", "3", "4", "5", "6", "A", "B", "C", "D", "Q", "R", "W"]
        return northSouthLines.contains(lineId)
    }
    
    private static func linesManhattanBound(_ lineId: String) -> Bool {
        let nonManhattanLines = ["G"]
        return !nonManhattanLines.contains(lineId)
    }
    
    private static func getUltimateDestination(_ lineId: String, direction: String) -> String? {
        let lineDestinations: [String: (north: String?, south: String?)] = [
            "2": (north: "Bronx", south: "Brooklyn"),
            "3": (north: "Bronx", south: "Brooklyn"),
            "4": (north: "Bronx", south: "Brooklyn"),
            "5": (north: "Bronx", south: "Brooklyn"),
            "6": (north: "Bronx", south: nil),
            "7": (north: "Queens", south: nil),
            "A": (north: nil, south: "Queens"),
            "B": (north: "Bronx", south: "Brooklyn"),
            "C": (north: nil, south: "Brooklyn"),
            "D": (north: "Bronx", south: "Brooklyn"),
            "E": (north: "Queens", south: nil),
            "F": (north: "Queens", south: "Brooklyn"),
            "G": (north: "Queens", south: "Brooklyn"),
            "J": (north: "Queens", south: nil),
            "L": (north: "Brooklyn", south: nil),
            "M": (north: "Queens", south: "Brooklyn"),
            "N": (north: "Queens", south: "Brooklyn"),
            "Q": (north: nil, south: "Brooklyn"),
            "R": (north: "Queens", south: "Brooklyn"),
            "W": (north: "Queens", south: nil),
            "Z": (north: "Queens", south: nil)
        ]
        
        let destinations = lineDestinations[lineId]
        return direction == "N" ? destinations?.north : destinations?.south
    }
}

// Extension for easy access
extension CLLocation {
    var borough: LocationBasedDirectionHelper.Borough {
        return LocationBasedDirectionHelper.getBoroughForLocation(self)
    }
    
    var boroughName: String {
        return borough.rawValue
    }
}

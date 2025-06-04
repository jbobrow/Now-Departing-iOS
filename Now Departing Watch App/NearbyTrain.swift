//
//  NearbyTrain.swift
//  Now Departing
//
//  Created by Jonathan Bobrow on 6/4/25.
//

import Foundation
import SwiftUI

struct NearbyTrain: Identifiable, Equatable {
    let id = UUID()
    let lineId: String
    let stationName: String
    let stationDisplay: String
    let direction: String
    let destination: String
    let minutes: Int
    let distanceInMeters: Double
    
    // Helper computed properties
    var timeText: String {
        if minutes <= 0 {
            return "Now"
        } else {
            return "\(minutes)m"
        }
    }
    
    var distanceText: String {
        // Convert meters to feet
        let feet = distanceInMeters * 3.28084
        
        if feet < 1000 {
            return "\(Int(feet))ft"
        } else {
            // Convert to miles (5280 feet = 1 mile)
            let miles = feet / 5280
            if miles < 10 {
                return String(format: "%.1fmi", miles)
            } else {
                return "\(Int(miles))mi"
            }
        }
    }
    
    var directionText: String {
        return direction == "N" ? "Uptown" : "Downtown"
    }
}

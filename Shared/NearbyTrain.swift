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
    let stationId: String
    let stationName: String
    let stationDisplay: String
    let direction: String
    let destination: String
    let arrivalTime: Date  // Store actual arrival time instead of minutes
    let distanceInMeters: Double
    
    // Helper computed properties
    var minutes: Int {
        let timeInterval = arrivalTime.timeIntervalSinceNow
        return max(0, Int(timeInterval / 60))
    }
    
    var timeText: String {
        let timeInterval = arrivalTime.timeIntervalSinceNow
        let totalSeconds = max(0, Int(timeInterval))
        let minutes = totalSeconds / 60
        
        if totalSeconds <= 0 {
            return "Now"
        } else {
            return "\(minutes)m"
        }
    }
    
    // Get live time text with current time for precise countdown
    func getLiveTimeText(currentTime: Date, fullText: Bool = false) -> String {
        let timeInterval = arrivalTime.timeIntervalSince(currentTime)
        let totalSeconds = max(0, Int(timeInterval))
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        
        if totalSeconds <= 30 {
            return "Now"
        } else if totalSeconds < 60 {
            return "Soon"
        } else {
            if(fullText) {
                return "\(minutes) min"
            }
            else {
                return "\(minutes)m"
            }
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

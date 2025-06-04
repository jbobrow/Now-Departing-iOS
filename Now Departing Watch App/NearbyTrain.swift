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
        if distanceInMeters < 1000 {
            return "\(Int(distanceInMeters))m"
        } else {
            let kilometers = distanceInMeters / 1000
            return String(format: "%.1fkm", kilometers)
        }
    }
    
    var directionText: String {
        return direction == "N" ? "Uptown" : "Downtown"
    }
}

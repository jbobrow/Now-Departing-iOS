//
//  LiveActivityAttributes.swift
//  Now Departing
//
//  Shared attributes for Live Activities
//

#if os(iOS)
import ActivityKit
import SwiftUI

@available(iOS 16.2, *)
struct NowDepartingWidgetAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic train times
        var nextTrains: [TrainTime]
        var lastUpdated: Date

        struct TrainTime: Codable, Hashable {
            var minutes: Int
            var seconds: Int
        }
    }

    // Fixed train route properties
    var lineId: String
    var lineLabel: String
    var lineBgColorRed: Double
    var lineBgColorGreen: Double
    var lineBgColorBlue: Double
    var lineFgColorRed: Double
    var lineFgColorGreen: Double
    var lineFgColorBlue: Double
    var stationName: String
    var direction: String
    var destinationStation: String

    // Helper computed properties
    var lineBgColor: Color {
        Color(red: lineBgColorRed, green: lineBgColorGreen, blue: lineBgColorBlue)
    }

    var lineFgColor: Color {
        Color(red: lineFgColorRed, green: lineFgColorGreen, blue: lineFgColorBlue)
    }
}
#endif

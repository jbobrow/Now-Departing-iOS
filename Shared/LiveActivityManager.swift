//
//  LiveActivityManager.swift
//  Now Departing
//
//  Manages Live Activities for train departures
//

import ActivityKit
import SwiftUI

@available(iOS 16.2, *)
class LiveActivityManager {
    static let shared = LiveActivityManager()

    private var currentActivity: Activity<NowDepartingWidgetAttributes>?

    private init() {}

    // Start a Live Activity for a train route
    func startActivity(
        lineId: String,
        lineLabel: String,
        lineBgColor: Color,
        lineFgColor: Color,
        stationName: String,
        stationDisplay: String,
        direction: String,
        destinationStation: String,
        nextTrains: [(minutes: Int, seconds: Int)]
    ) {
        // End any existing activity first
        endActivity()

        // Extract RGB components from SwiftUI Color
        let bgComponents = UIColor(lineBgColor).cgColor.components ?? [0, 0, 0, 1]
        let fgComponents = UIColor(lineFgColor).cgColor.components ?? [1, 1, 1, 1]

        let attributes = NowDepartingWidgetAttributes(
            lineId: lineId,
            lineLabel: lineLabel,
            lineBgColorRed: Double(bgComponents[0]),
            lineBgColorGreen: Double(bgComponents[1]),
            lineBgColorBlue: Double(bgComponents[2]),
            lineFgColorRed: Double(fgComponents[0]),
            lineFgColorGreen: Double(fgComponents[1]),
            lineFgColorBlue: Double(fgComponents[2]),
            stationName: stationDisplay,
            direction: direction,
            destinationStation: destinationStation
        )

        let initialState = NowDepartingWidgetAttributes.ContentState(
            nextTrains: nextTrains.map {
                NowDepartingWidgetAttributes.ContentState.TrainTime(minutes: $0.minutes, seconds: $0.seconds)
            },
            lastUpdated: Date()
        )

        do {
            let activity = try Activity.request(
                attributes: attributes,
                content: .init(state: initialState, staleDate: nil),
                pushType: nil
            )
            currentActivity = activity
            print("✅ Live Activity started successfully")
        } catch {
            print("❌ Error starting Live Activity: \(error.localizedDescription)")
        }
    }

    // Update the current Live Activity with new train times
    func updateActivity(nextTrains: [(minutes: Int, seconds: Int)]) {
        guard let activity = currentActivity else {
            print("⚠️ No active Live Activity to update")
            return
        }

        let updatedState = NowDepartingWidgetAttributes.ContentState(
            nextTrains: nextTrains.map {
                NowDepartingWidgetAttributes.ContentState.TrainTime(minutes: $0.minutes, seconds: $0.seconds)
            },
            lastUpdated: Date()
        )

        Task {
            await activity.update(
                .init(state: updatedState, staleDate: nil)
            )
        }
    }

    // End the current Live Activity
    func endActivity() {
        guard let activity = currentActivity else { return }

        Task {
            await activity.end(nil, dismissalPolicy: .immediate)
            currentActivity = nil
            print("✅ Live Activity ended")
        }
    }

    // Check if Live Activities are supported
    static func isSupported() -> Bool {
        if #available(iOS 16.2, *) {
            return ActivityAuthorizationInfo().areActivitiesEnabled
        }
        return false
    }
}

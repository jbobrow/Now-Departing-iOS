//
//  LiveActivityManager.swift
//  Now Departing
//
//  Manages Live Activities for train departures
//

#if os(iOS)
import ActivityKit
import SwiftUI

@available(iOS 16.2, *)
class LiveActivityManager {
    static let shared = LiveActivityManager()

    private var currentActivity: Activity<NowDepartingWidgetAttributes>?

    // The UI counts down on its own via timer text; after this long without fresh
    // feed data the system marks the activity stale so the UI can show it as outdated.
    private static let staleInterval: TimeInterval = 30 * 60

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
        nextTrains: [Date]
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
                NowDepartingWidgetAttributes.ContentState.TrainTime(departureDate: $0)
            },
            lastUpdated: Date()
        )

        do {
            let activity = try Activity.request(
                attributes: attributes,
                content: ActivityContent(state: initialState, staleDate: Date().addingTimeInterval(Self.staleInterval)),
                pushType: nil
            )
            currentActivity = activity
            print("✅ Live Activity started successfully")
        } catch {
            print("❌ Error starting Live Activity: \(error.localizedDescription)")
        }
    }

    // Update the current Live Activity with new train departure dates
    func updateActivity(nextTrains: [Date]) {
        guard let activity = currentActivity else {
            print("⚠️ No active Live Activity to update")
            return
        }

        let updatedState = NowDepartingWidgetAttributes.ContentState(
            nextTrains: nextTrains.map {
                NowDepartingWidgetAttributes.ContentState.TrainTime(departureDate: $0)
            },
            lastUpdated: Date()
        )

        Task {
            await activity.update(
                ActivityContent(state: updatedState, staleDate: Date().addingTimeInterval(Self.staleInterval))
            )
        }
    }

    // End the current Live Activity — including any orphaned activities from a previous
    // app process, which `currentActivity` alone wouldn't know about.
    func endActivity() {
        currentActivity = nil  // nil synchronously so rapid re-calls and new starts are safe
        // Snapshot synchronously so an activity started right after this call is not ended.
        let activitiesToEnd = Activity<NowDepartingWidgetAttributes>.activities
        guard !activitiesToEnd.isEmpty else { return }
        Task {
            for activity in activitiesToEnd {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
            print("✅ Live Activity ended")
        }
    }

    // Check if Live Activities are supported
    static func isSupported() -> Bool {
        return ActivityAuthorizationInfo().areActivitiesEnabled
    }
}
#endif

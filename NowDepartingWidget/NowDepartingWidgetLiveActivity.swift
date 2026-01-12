//
//  NowDepartingWidgetLiveActivity.swift
//  NowDepartingWidget
//
//  Created by Jonathan Bobrow on 1/10/26.
//

import ActivityKit
import WidgetKit
import SwiftUI

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

struct NowDepartingWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: NowDepartingWidgetAttributes.self) { context in
            // Lock screen/banner UI and StandBy mode UI
            HStack(spacing: 16) {
                // Left side - Line badge and station info
                HStack(spacing: 12) {
                    Text(context.attributes.lineLabel)
                        .font(.custom("HelveticaNeue-Bold", size: 50))
                        .foregroundColor(context.attributes.lineFgColor)
                        .frame(width: 80, height: 80)
                        .background(Circle().fill(context.attributes.lineBgColor))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(context.attributes.stationName)
                            .font(.custom("HelveticaNeue-Bold", size: 28))
                            .foregroundColor(.white)
                            .lineLimit(2)
                        Text("to \(context.attributes.destinationStation)")
                            .font(.custom("HelveticaNeue", size: 16))
                            .foregroundColor(.white.opacity(0.7))
                            .lineLimit(1)
                    }
                }

                Spacer()

                // Right side - Train times
                VStack(alignment: .trailing, spacing: 4) {
                    if let primaryTrain = context.state.nextTrains.first {
                        Text(getTimeText(for: primaryTrain, currentTime: Date()))
                            .font(.custom("HelveticaNeue-Bold", size: 72))
                            .foregroundColor(.white)

                        if context.state.nextTrains.count > 1 {
                            Text(context.state.nextTrains.dropFirst().prefix(2).map { train in
                                getAdditionalTimeText(for: train, currentTime: Date())
                            }.joined(separator: ", "))
                            .font(.custom("HelveticaNeue", size: 22))
                            .foregroundColor(.white.opacity(0.7))
                        }
                    } else {
                        Text("--")
                            .font(.custom("HelveticaNeue-Bold", size: 72))
                            .foregroundColor(.white.opacity(0.5))
                    }
                }
            }
            .padding(24)
            .preferredColorScheme(.dark)
            .activityBackgroundTint(Color.black)
            .activitySystemActionForegroundColor(Color.white)

        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI for Dynamic Island
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 8) {
                        Text(context.attributes.lineLabel)
                            .font(.custom("HelveticaNeue-Bold", size: 20))
                            .foregroundColor(context.attributes.lineFgColor)
                            .frame(width: 32, height: 32)
                            .background(Circle().fill(context.attributes.lineBgColor))
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    if let primaryTrain = context.state.nextTrains.first {
                        Text(getTimeText(for: primaryTrain, currentTime: Date()))
                            .font(.custom("HelveticaNeue-Bold", size: 24))
                            .foregroundColor(.white)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(context.attributes.stationName)
                            .font(.custom("HelveticaNeue", size: 14))
                            .foregroundColor(.white)
                        if context.state.nextTrains.count > 1 {
                            Text("Also: \(context.state.nextTrains.dropFirst().prefix(2).map { train in
                                getAdditionalTimeText(for: train, currentTime: Date())
                            }.joined(separator: ", "))")
                            .font(.custom("HelveticaNeue", size: 12))
                            .foregroundColor(.white.opacity(0.7))
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            } compactLeading: {
                Text(context.attributes.lineLabel)
                    .font(.custom("HelveticaNeue-Bold", size: 16))
                    .foregroundColor(context.attributes.lineFgColor)
                    .frame(width: 20, height: 20)
                    .background(Circle().fill(context.attributes.lineBgColor))
            } compactTrailing: {
                if let primaryTrain = context.state.nextTrains.first {
                    Text(getCompactTimeText(for: primaryTrain, currentTime: Date()))
                        .font(.custom("HelveticaNeue-Bold", size: 14))
                        .foregroundColor(.white)
                }
            } minimal: {
                Text(context.attributes.lineLabel)
                    .font(.custom("HelveticaNeue-Bold", size: 12))
                    .foregroundColor(context.attributes.lineFgColor)
            }
            .keylineTint(context.attributes.lineBgColor)
        }
    }

    // Helper functions for time display
    private func getTimeText(for train: NowDepartingWidgetAttributes.ContentState.TrainTime, currentTime: Date) -> String {
        let totalSeconds = train.minutes * 60 + train.seconds

        if totalSeconds == 0 {
            return "Departing"
        } else if totalSeconds <= 30 {
            return "Departing"
        } else if totalSeconds < 60 {
            return "Arriving"
        } else {
            return "\(train.minutes) min"
        }
    }

    private func getAdditionalTimeText(for train: NowDepartingWidgetAttributes.ContentState.TrainTime, currentTime: Date) -> String {
        let totalSeconds = train.minutes * 60 + train.seconds

        if totalSeconds < 60 {
            return "Arriving"
        } else {
            return "\(train.minutes) min"
        }
    }

    private func getCompactTimeText(for train: NowDepartingWidgetAttributes.ContentState.TrainTime, currentTime: Date) -> String {
        let totalSeconds = train.minutes * 60 + train.seconds

        if totalSeconds < 60 {
            return "Now"
        } else {
            return "\(train.minutes)m"
        }
    }
}

extension NowDepartingWidgetAttributes {
    fileprivate static var preview: NowDepartingWidgetAttributes {
        // G train example (Classon Av. to Court Square)
        NowDepartingWidgetAttributes(
            lineId: "G",
            lineLabel: "G",
            lineBgColorRed: 0.44,
            lineBgColorGreen: 0.74,
            lineBgColorBlue: 0.30,
            lineFgColorRed: 1.0,
            lineFgColorGreen: 1.0,
            lineFgColorBlue: 1.0,
            stationName: "Classon Av.",
            direction: "N",
            destinationStation: "Court Square"
        )
    }
}

extension NowDepartingWidgetAttributes.ContentState {
    fileprivate static var arriving: NowDepartingWidgetAttributes.ContentState {
        NowDepartingWidgetAttributes.ContentState(
            nextTrains: [
                .init(minutes: 0, seconds: 45),
                .init(minutes: 12, seconds: 0),
                .init(minutes: 19, seconds: 0)
            ],
            lastUpdated: Date()
        )
    }

    fileprivate static var upcoming: NowDepartingWidgetAttributes.ContentState {
        NowDepartingWidgetAttributes.ContentState(
            nextTrains: [
                .init(minutes: 8, seconds: 30),
                .init(minutes: 12, seconds: 0),
                .init(minutes: 19, seconds: 0),
                .init(minutes: 28, seconds: 0)
            ],
            lastUpdated: Date()
        )
    }
}

#Preview("Notification", as: .content, using: NowDepartingWidgetAttributes.preview) {
   NowDepartingWidgetLiveActivity()
} contentStates: {
    NowDepartingWidgetAttributes.ContentState.arriving
    NowDepartingWidgetAttributes.ContentState.upcoming
}

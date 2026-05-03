//
//  NowDepartingWidgetLiveActivity.swift
//  NowDepartingWidget
//
//  Created by Jonathan Bobrow on 1/10/26.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct NowDepartingWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: NowDepartingWidgetAttributes.self) { context in
            // Lock screen/banner UI and StandBy mode UI
            VStack() {
                Spacer()
                
                // Left side - Line badge and station info
                HStack(alignment: .top, spacing: 16) {
                    Text(context.attributes.lineLabel)
                        .font(.system(size: 48, weight: .bold))
                        .foregroundColor(context.attributes.lineFgColor)
                        .frame(width: 64, height: 64)
                        .background(Circle().fill(context.attributes.lineBgColor))

                    VStack(alignment: .leading, spacing: 0) {
                        Text(context.attributes.stationName)
                            .font(.system(size: 36, weight: .bold))
                            .foregroundColor(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        Text(context.attributes.destinationStation)
                            .font(.system(size: 18, weight: .regular))
                            .foregroundColor(.white.opacity(0.7))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    
                    Spacer()
                }

                // Right side - Train times
                HStack(alignment:.bottom) {
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 0) {
                        if let primaryTrain = context.state.nextTrains.first {
                            Text(getTimeText(for: primaryTrain))
                                .font(.system(size: 48, weight: .bold))
                                .foregroundColor(.white)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                            
                            if context.state.nextTrains.count > 1 {
                                Text("next train \(getAdditionalTimeText(for: context.state.nextTrains[1]))")
                                    .font(.system(size: 12, weight: .regular))
                                    .foregroundColor(.white.opacity(0.7))
                                    .lineLimit(1)
                            }
                        } else {
                            Text("--")
                                .font(.system(size: 48, weight: .bold))
                                .foregroundColor(.white.opacity(0.5))
                        }
                    }
                }
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .activityBackgroundTint(Color.black)
            .activitySystemActionForegroundColor(Color.white)

        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI for Dynamic Island
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 8) {
                        Text(context.attributes.lineLabel)
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(context.attributes.lineFgColor)
                            .frame(width: 36, height: 36)
                            .background(Circle().fill(context.attributes.lineBgColor))

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Now Departing")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.white.opacity(0.8))
                            Text(context.attributes.stationName)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.white)
                                .lineLimit(1)
                        }
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 2) {
                        if let primaryTrain = context.state.nextTrains.first {
                            Text(getTimeText(for: primaryTrain))
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(.white)
                            if context.state.nextTrains.count > 1 {
                                let additionalTime = getAdditionalTimeText(for: context.state.nextTrains[1])
                                Text(additionalTime)
                                    .font(.system(size: 12, weight: .regular))
                                    .foregroundColor(.white.opacity(0.7))
                            }
                        }
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        Text(context.attributes.destinationStation)
                            .font(.system(size: 13, weight: .regular))
                            .foregroundColor(.white.opacity(0.7))
                            .lineLimit(1)
                        Spacer()
                        if context.state.nextTrains.count > 2 {
                            let moreTimes = context.state.nextTrains.dropFirst(2).prefix(2).map { train in
                                getAdditionalTimeText(for: train)
                            }.joined(separator: ", ")
                            Text(moreTimes)
                                .font(.system(size: 13, weight: .regular))
                                .foregroundColor(.white.opacity(0.6))
                        }
                    }
                    .padding(.horizontal, 4)
                }
            } compactLeading: {
                HStack(spacing: 6) {
                    Text(context.attributes.lineLabel)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(context.attributes.lineFgColor)
                        .frame(width: 18, height: 18)
                        .background(Circle().fill(context.attributes.lineBgColor))

                    Text("Now Departing")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white)
                }
            } compactTrailing: {
                if let primaryTrain = context.state.nextTrains.first {
                    Text(getCompactTimeText(for: primaryTrain))
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.white)
                }
            } minimal: {
                Text(context.attributes.lineLabel)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(context.attributes.lineFgColor)
                    .frame(width: 18, height: 18)
                    .background(Circle().fill(context.attributes.lineBgColor))
            }
            .keylineTint(context.attributes.lineBgColor)
        }
    }

    // Helper functions for time display
    private func getTimeText(for train: NowDepartingWidgetAttributes.ContentState.TrainTime) -> String {
        return TimeFormatter.formatArrivalTime(train.departureDate, fullText: true)
    }

    private func getAdditionalTimeText(for train: NowDepartingWidgetAttributes.ContentState.TrainTime) -> String {
        return TimeFormatter.formatAdditionalTime(train.departureDate)
    }

    private func getCompactTimeText(for train: NowDepartingWidgetAttributes.ContentState.TrainTime) -> String {
        return TimeFormatter.formatArrivalTime(train.departureDate)
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
        let now = Date()
        return NowDepartingWidgetAttributes.ContentState(
            nextTrains: [
                .init(departureDate: now.addingTimeInterval(45)),
                .init(departureDate: now.addingTimeInterval(12 * 60)),
                .init(departureDate: now.addingTimeInterval(19 * 60))
            ],
            lastUpdated: now
        )
    }

    fileprivate static var upcoming: NowDepartingWidgetAttributes.ContentState {
        let now = Date()
        return NowDepartingWidgetAttributes.ContentState(
            nextTrains: [
                .init(departureDate: now.addingTimeInterval(8 * 60 + 30)),
                .init(departureDate: now.addingTimeInterval(12 * 60)),
                .init(departureDate: now.addingTimeInterval(19 * 60)),
                .init(departureDate: now.addingTimeInterval(28 * 60))
            ],
            lastUpdated: now
        )
    }
}

#Preview("Notification", as: .content, using: NowDepartingWidgetAttributes.preview) {
   NowDepartingWidgetLiveActivity()
} contentStates: {
    NowDepartingWidgetAttributes.ContentState.arriving
    NowDepartingWidgetAttributes.ContentState.upcoming
}

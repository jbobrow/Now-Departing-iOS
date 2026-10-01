//
//  NowDepartingWidgetLiveActivity.swift
//  NowDepartingWidget
//
//  Created by Jonathan Bobrow on 1/10/26.
//

import ActivityKit
import WidgetKit
import SwiftUI

/// Self-updating countdown to a departure. Live Activity views render once per content
/// update — TimelineView never ticks here — so only system-driven date text keeps the
/// count accurate between refetches. And the archive is decoded in SpringBoard's
/// renderer, which only knows Apple's built-in live formats (a custom DiscreteFormatStyle
/// fails with `Errors.noType` and the whole activity renders as placeholder boxes).
/// `.reference` is the built-in closest to the app's minute-level design: "in 8 minutes",
/// "in 45 seconds", then "2 minutes ago" once the train has departed. (`.offset` looked
/// closer but counts time *since* the anchor — negative before arrival — and `.relative`
/// appends seconds; neither format offers abbreviated units.) iOS 17 lacks these and
/// falls back to a mm:ss countdown.
private func countdown(to date: Date) -> Text {
    if #available(iOS 18.0, *) {
        return Text(
            .currentDate,
            format: .reference(to: date, allowedFields: [.minute, .second], maxFieldCount: 1)
        )
    } else {
        return Text(timerInterval: Date.now...max(Date.now, date), countsDown: true, showsHours: false)
    }
}

/// `countdown(to:)` for a train, preceded by a diamond in the line's color when it's express.
private func countdown(
    to train: NowDepartingWidgetAttributes.ContentState.TrainTime,
    lineColor: Color,
    fontSize: CGFloat
) -> Text {
    guard train.isExpress == true else { return countdown(to: train.departureDate) }
    return ExpressMark.textDiamond(color: lineColor, fontSize: fontSize)
        + Text("\u{202F}")
        + countdown(to: train.departureDate)
}

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
                            countdown(to: primaryTrain, lineColor: context.attributes.lineBgColor, fontSize: 48)
                                .font(.system(size: 48, weight: .bold))
                                .foregroundColor(.white)
                                .monospacedDigit()
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                                .multilineTextAlignment(.trailing)
                                .opacity(context.isStale ? 0.5 : 1)

                            if context.state.nextTrains.count > 1 {
                                (Text("next train ") + countdown(to: context.state.nextTrains[1], lineColor: context.attributes.lineBgColor, fontSize: 12))
                                    .font(.system(size: 12, weight: .regular))
                                    .foregroundColor(.white.opacity(0.7))
                                    .lineLimit(1)
                                    .multilineTextAlignment(.trailing)
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

                        Text(context.attributes.stationName)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                            .lineLimit(1)
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 2) {
                        if let primaryTrain = context.state.nextTrains.first {
                            countdown(to: primaryTrain, lineColor: context.attributes.lineBgColor, fontSize: 28)
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(.white)
                                .monospacedDigit()
                                .multilineTextAlignment(.trailing)
                            if context.state.nextTrains.count > 1 {
                                countdown(to: context.state.nextTrains[1], lineColor: context.attributes.lineBgColor, fontSize: 12)
                                    .font(.system(size: 12, weight: .regular))
                                    .foregroundColor(.white.opacity(0.7))
                                    .multilineTextAlignment(.trailing)
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
                            let additionalTimes = Array(context.state.nextTrains.dropFirst(2).prefix(2))
                                .map { countdown(to: $0, lineColor: context.attributes.lineBgColor, fontSize: 13) }
                            additionalTimes.dropFirst()
                                .reduce(additionalTimes[0]) { $0 + Text(", ") + $1 }
                                .font(.system(size: 13, weight: .regular))
                                .foregroundColor(.white.opacity(0.6))
                                .monospacedDigit()
                        }
                    }
                    .padding(.horizontal, 4)
                }
            } compactLeading: {
                Text(context.attributes.lineLabel)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(context.attributes.lineFgColor)
                    .frame(width: 18, height: 18)
                    .background(Circle().fill(context.attributes.lineBgColor))
            } compactTrailing: {
                if let primaryTrain = context.state.nextTrains.first {
                    countdown(to: primaryTrain, lineColor: context.attributes.lineBgColor, fontSize: 15)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.white)
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
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

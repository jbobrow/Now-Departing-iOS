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
        // Dynamic stateful properties about your activity go here!
        var emoji: String
    }

    // Fixed non-changing properties about your activity go here!
    var name: String
}

struct NowDepartingWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: NowDepartingWidgetAttributes.self) { context in
            // Lock screen/banner UI goes here
            VStack {
                Text("Hello \(context.state.emoji)")
            }
            .preferredColorScheme(.dark)
            .activityBackgroundTint(Color.black)
            .activitySystemActionForegroundColor(Color.white)

        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI goes here.  Compose the expanded UI through
                // various regions, like leading/trailing/center/bottom
                DynamicIslandExpandedRegion(.leading) {
                    Text("Leading")
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("Trailing")
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("Bottom \(context.state.emoji)")
                    // more content
                }
            } compactLeading: {
                Text("L")
            } compactTrailing: {
                Text("T \(context.state.emoji)")
            } minimal: {
                Text(context.state.emoji)
            }
            .widgetURL(URL(string: "http://www.apple.com"))
            .keylineTint(Color.white)
        }
    }
}

extension NowDepartingWidgetAttributes {
    fileprivate static var preview: NowDepartingWidgetAttributes {
        NowDepartingWidgetAttributes(name: "World")
    }
}

extension NowDepartingWidgetAttributes.ContentState {
    fileprivate static var smiley: NowDepartingWidgetAttributes.ContentState {
        NowDepartingWidgetAttributes.ContentState(emoji: "😀")
     }
     
     fileprivate static var starEyes: NowDepartingWidgetAttributes.ContentState {
         NowDepartingWidgetAttributes.ContentState(emoji: "🤩")
     }
}

#Preview("Notification", as: .content, using: NowDepartingWidgetAttributes.preview) {
   NowDepartingWidgetLiveActivity()
} contentStates: {
    NowDepartingWidgetAttributes.ContentState.smiley
    NowDepartingWidgetAttributes.ContentState.starEyes
}

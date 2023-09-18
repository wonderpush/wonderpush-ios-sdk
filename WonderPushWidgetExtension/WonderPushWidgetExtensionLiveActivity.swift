//
//  WonderPushWidgetExtensionLiveActivity.swift
//  WonderPushWidgetExtension
//
//  Created by Stéphane JAIS on 08/11/2022.
//  Copyright © 2022 WonderPush. All rights reserved.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct WonderPushWidgetExtensionAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic stateful properties about your activity go here!
        var value: Int
        var name: String
    }

    // Fixed non-changing properties about your activity go here!
    var name: String
}

struct WonderPushWidgetExtensionLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: WonderPushWidgetExtensionAttributes.self) { context in
            // Lock screen/banner UI goes here
            VStack {
                Text("\(context.attributes.name): \(context.state.value) \(context.state.name)")
            }
            .activityBackgroundTint(Color.cyan)
            .activitySystemActionForegroundColor(Color.black)
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI goes here.  Compose the expanded UI through
                // various regions, like leading/trailing/center/bottom
                DynamicIslandExpandedRegion(.center) {
                    Text("\(context.attributes.name): \(context.state.value)")
                }
                DynamicIslandExpandedRegion(.leading) {
                    Text(context.attributes.name)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("\(context.state.value)")
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("Bottom")
                    // more content
                }
            } compactLeading: {
                Text("L")
            } compactTrailing: {
                Text("T")
            } minimal: {
                Text("\(context.state.value)")
            }
            .widgetURL(URL(string: "https://www.wonderpush.com"))
            .keylineTint(Color.red)
        }
    }
}

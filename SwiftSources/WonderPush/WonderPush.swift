//
//  WonderPush.swift
//  WonderPush
//
//  Created by Olivier Favre on 04/01/2023.
//  Copyright © 2023 WonderPush. All rights reserved.
//

import Foundation
import ActivityKit

extension Data {
    func hexEncodedString() -> String {
        return self.map { String(format: "%02hhx", $0) }.joined()
    }
}

extension WonderPush {
    @available(iOS 10.0, *)
    static let iso8601DateFormatter = ISO8601DateFormatter()

    @available(iOS 16.1, *)
    public class func upsertLiveActivity<Attributes : ActivityAttributes>(activity: Activity<Attributes>) -> Void {
        if let pushToken = activity.pushToken {
            WonderPush.trackEvent("NewLiveActivity", attributes: [
                "string_liveActivityId": activity.id,
                "ignore_liveActivityPushToken": pushToken.hexEncodedString(),
                "date_liveActivityExpiration": iso8601DateFormatter.string(from: Date().addingTimeInterval(3600 * 8)),
            ])
        }
        Task {
            for await pushTokenUpdate in activity.pushTokenUpdates {
                WonderPush.trackEvent("NewLiveActivity", attributes: [
                    "string_liveActivityId": activity.id,
                    "ignore_liveActivityPushToken": pushTokenUpdate.hexEncodedString(),
                    "date_liveActivityExpiration": iso8601DateFormatter.string(from: Date().addingTimeInterval(3600 * 8)),
                ])
            }
        }
    }

    @available(iOS 16.1, *)
    public class func stopLiveActivity<Attributes : ActivityAttributes>(activity: Activity<Attributes>) -> Void {
        WonderPush.trackEvent("NewLiveActivity", attributes: [
            "string_liveActivityId": activity.id,
            "ignore_liveActivityPushToken": NSNull(),
            "date_liveActivityExpiration": 0,
        ])
    }

}

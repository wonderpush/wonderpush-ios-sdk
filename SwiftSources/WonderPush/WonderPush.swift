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
    static var syncedActivityAttributesTypes: Array<any ActivityAttributes.Type> = []

    @available(iOS 16.1, *)
    public class func upsertLiveActivity<Attributes : ActivityAttributes>(activity: Activity<Attributes>) -> Void {
        if let pushToken = activity.pushToken {
            print("upsertLiveActivity got initial pushToken for \(liveActivityDescription(activity))")
            WonderPush.trackEvent("NewLiveActivity", attributes: [
                "string_liveActivityId": activity.id,
                "ignore_liveActivityPushToken": pushToken.hexEncodedString(),
                "date_liveActivityExpiration": iso8601DateFormatter.string(from: Date().addingTimeInterval(3600 * 8)),
            ])
        }
        Task {
            for await pushTokenUpdate in activity.pushTokenUpdates {
                print("upsertLiveActivity got pushToken update for \(liveActivityDescription(activity))")
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
        print("stopLiveActivity for \(liveActivityDescription(activity))")
        WonderPush.trackEvent("NewLiveActivity", attributes: [
            "string_liveActivityId": activity.id,
            "ignore_liveActivityPushToken": NSNull(),
            "date_liveActivityExpiration": 0,
        ])
    }

    @available(iOS 16.1, *)
    public class func syncLiveActivities<Attributes : ActivityAttributes>(attributes: Attributes.Type) -> Void {
        // Ensure we run once per type
        if syncedActivityAttributesTypes.contains(where: { elmt in
            return elmt == attributes
        }) {
            print("syncLiveActivities<\(String(describing: type(of: attributes)))>(\(String(describing: attributes))) ALREADY RUNNING!")
            return
        }
        syncedActivityAttributesTypes.append(attributes)

        print("syncLiveActivities<\(String(describing: type(of: attributes)))>(\(String(describing: attributes)))")
        print("syncLiveActivities: Current activities:")
        for activity in Activity<Attributes>.activities {
            print("syncLiveActivities: current activity: \(liveActivityDescription(activity))")
            //upsertLiveActivity(activity: activity);
            monitorLiveActivities(activity: activity)
        }
        print("syncLiveActivities: Current activities EOL")
        Task {
            for await updatedActivity in Activity<Attributes>.activityUpdates {
                print("syncLiveActivities: activityUpdates yielded \(liveActivityDescription(updatedActivity))")
                //upsertLiveActivity(activity: updatedActivity);
                monitorLiveActivities(activity: updatedActivity)
            }
            print("syncLiveActivities: activityUpdates EOS")
        }
    }
    
    @available(iOS 16.1, *)
    public class func monitorLiveActivities<Attributes : ActivityAttributes>(activity: Activity<Attributes>) -> Void {
        print("monitorLiveActivities for \(activity.id): Initial. Activity: \(liveActivityDescription(activity))")
        Task {
            for await activityState in activity.activityStateUpdates {
                print("monitorLiveActivities for \(activity.id): Activity state update. New: \(activityState). Activity: \(liveActivityDescription(activity))")
            }
            print("monitorLiveActivities for \(activity.id): Activity state update EOS")
        }
        Task {
            for await pushToken in activity.pushTokenUpdates {
                print("monitorLiveActivities for \(activity.id): Push token update. New: \(pushToken.hexEncodedString()). Activity: \(liveActivityDescription(activity))")
            }
            print("monitorLiveActivities for \(activity.id): Push token update EOS")
        }
        Task {
            let encoder = JSONEncoder()
            for await contentState in activity.contentStateUpdates {
                let contentStateJson = try? String(decoding: encoder.encode(contentState), as: UTF8.self)
                print("monitorLiveActivities for \(activity.id): Content state update. New: \(contentStateJson ?? "ERROR"). Activity: \(liveActivityDescription(activity))")
            }
            print("monitorLiveActivities for \(activity.id): Content state update EOS")
        }
    }
    
    @available(iOS 16.1, *)
    public class func liveActivityDescription<Attributes : ActivityAttributes>(_ activity: Activity<Attributes>) -> String {
        let encoder = JSONEncoder()
        let attributesJson = try? String(decoding: encoder.encode(activity.attributes), as: UTF8.self)
        let contentStateJson = try? String(decoding: encoder.encode(activity.contentState), as: UTF8.self)
        return "Activity<\(String(describing: type(of: Attributes.self)))>(id: \(activity.id), state: \(activity.activityState), attributes: \(attributesJson ?? "ERROR"), contentState: \(contentStateJson ?? "ERROR"), pushToken: \(String(describing: activity.pushToken?.hexEncodedString() ?? "None")))"
    }

}

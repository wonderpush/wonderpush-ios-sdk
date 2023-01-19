//
//  ViewController.swift
//  WonderPushExample
//
//  Created by Stéphane JAIS on 08/11/2022.
//  Copyright © 2022 WonderPush. All rights reserved.
//

import UIKit
import WonderPushWidgetExtensionExtension
import ActivityKit
import WonderPush

class ViewController: UIViewController {
    var activity: Activity<WonderPushWidgetExtensionAttributes>?
    let formatter = ISO8601DateFormatter()

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
    }

    @IBAction func touchStartLiveActivity(_ sender: Any) {
        let initialContentState = WonderPushWidgetExtensionAttributes.ContentState(value:123, name:"started")
        let activityAttributes = WonderPushWidgetExtensionAttributes(name:"some name")
        do {
            activity = try Activity.request(attributes: activityAttributes, contentState: initialContentState, pushType: .token)
            if let activity = activity {
                print("Requested a Live Activity \(String(describing: activity.id)).")
            }
        } catch (let error) {
            print("Error requesting Live Activity \(error.localizedDescription).")
        }
    }
    
    @IBAction func touchUpdateLiveActivity(_ sender: Any) {
        Task {
            if let activity = activity {
                let value = Int.random(in: 100..<1000)
                let updatedContentState = WonderPushWidgetExtensionAttributes.ContentState(value: value, name: "updated")
                let alertConfiguration = AlertConfiguration(title: "Activity Update", body: "Value has been updated to \(value)", sound: .default)
                
                print("Updating a Live Activity \(activity.id).")
                await activity.update(using: updatedContentState, alertConfiguration: alertConfiguration)
            }
        }
    }
    
    @IBAction func touchStopLiveActivity(_ sender: Any) {
        let finalContentState = WonderPushWidgetExtensionAttributes.ContentState(value: 789, name: "ended")

        Task {
            if let activity = activity {
                print("Stopping a Live Activity \(String(describing: activity.id)).")
                await activity.end(using:finalContentState, dismissalPolicy: .default)
            }
        }
    }

    @IBAction func touchSyncLiveActivities(_ sender: Any) {
        WonderPush.registerActivityAttributes(WonderPushWidgetExtensionAttributes.self,
                                              type: "WonderPushWidget")
        WonderPush.registerActivityAttributes(WonderPushWidgetExtensionAttributes.self,
                                              type: "WonderPushWidget",
                                              properties: ["string_foo": "constant"])
        WonderPush.registerActivityAttributes(WonderPushWidgetExtensionAttributes.self,
                                              type: "WonderPushWidget",
                                              properties: { activity in ["string_foo": activity.attributes.name] })
        WonderPush.registerActivityAttributes(WonderPushWidgetExtensionAttributes.self,
                                              type: { activity in "WonderPushWidget-\(activity.attributes.name)"})
        WonderPush.registerActivityAttributes(WonderPushWidgetExtensionAttributes.self,
                                              type: { activity in "WonderPushWidget-\(activity.attributes.name)"},
                                              properties: ["string_foo": "constant"])
        WonderPush.registerActivityAttributes(WonderPushWidgetExtensionAttributes.self,
                                              type: { activity in "WonderPushWidget-\(activity.attributes.name)"},
                                              properties: { activity in ["string_foo": activity.attributes.name] })
        WonderPush.registerActivityAttributes(WonderPushWidgetExtensionAttributes.self,
                                              typeAndProperties: { activity in
            ("WonderPushWidget-\(activity.attributes.name)", ["string_foo": "constant"])
        })
    }

    @IBAction func touchTrackEventFoo(_ sender: Any) {
        WonderPush.trackEvent("foo")
    }

}

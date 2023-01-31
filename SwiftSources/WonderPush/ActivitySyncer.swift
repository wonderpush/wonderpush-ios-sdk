//
//  ActivitySyncer.swift
//  WonderPush
//
//  Created by Olivier Favre on 31/01/2023.
//  Copyright © 2023 WonderPush. All rights reserved.
//

import Foundation
import ActivityKit

extension Data {
    func hexEncodedString() -> String {
        return self.map { String(format: "%02hhx", $0) }.joined()
    }
}

extension NSLocking {
    func withCriticalSection<T>(block: () throws -> T) rethrows -> T {
        lock()
        defer { unlock() }
        return try block()
    }
}

let activitySyncersLock = NSLock()
var activitySyncers: [ObjectIdentifier: Any] = [:] // any ActivityAttributes.Type to ActivitySyncer<?>

@available(iOS 16.1, *)
class ActivitySyncer<Attributes : ActivityAttributes> {
    
    let attributesType: Attributes.Type
    let attributesTypeIdentifier: ObjectIdentifier
    let attributesTypeName: String
    let propertiesExtractor: ActivityPropertiesExtractor<Attributes>
    var persistedActivityStates: [String: PersistedActivityState] = [:]
    var monitoredActivities: [Activity<Attributes>] = []
    
    static func createIfNotExists(attributesType: Attributes.Type, propertiesExtractor: ActivityPropertiesExtractor<Attributes>) {
        let persistedActivityStates = Configuration.getPersistedActivityStates()
        if let syncer = activitySyncersLock.withCriticalSection(block: {
            var rtn: ActivitySyncer<Attributes>?
            if activitySyncers[ObjectIdentifier(attributesType)] == nil {
                let syncer = ActivitySyncer(attributesType: attributesType, propertiesExtractor: propertiesExtractor, persistedActivityStates: persistedActivityStates)
                activitySyncers[ObjectIdentifier(attributesType)] = syncer
                rtn = syncer
            }
            return rtn
        }) {
            syncer.start()
        }
    }

    init(attributesType: Attributes.Type, propertiesExtractor: ActivityPropertiesExtractor<Attributes>, persistedActivityStates: [String : PersistedActivityState]) {
        self.attributesType = attributesType
        self.attributesTypeIdentifier = ObjectIdentifier(attributesType)
        self.attributesTypeName = String(describing: attributesType)
        self.propertiesExtractor = propertiesExtractor
        for (id, persistedActivityState) in persistedActivityStates {
            if persistedActivityState.attributesTypeName == self.attributesTypeName {
                self.persistedActivityStates[id] = persistedActivityState
            }
        }
    }
    
    private func start() -> Void {
        // Caller should call only once per Attributes
        print("ActivitySyncer<\(self.attributesTypeName)> starting()")
        var unseenActivityIds = Set(persistedActivityStates.keys)
        print("ActivitySyncer<\(self.attributesTypeName)>: Current activities:")
        for activity in Activity<Attributes>.activities {
            print("ActivitySyncer<\(self.attributesTypeName)>: current activity: \(self.liveActivityDescription(activity))")
            unseenActivityIds.remove(activity.id)
            self.monitorLiveActivity(activity: activity)
        }
        print("ActivitySyncer<\(self.attributesTypeName)>: Current activities EOL")
        
        // Remove persisted but no longer present Live Activities
        for unseenActivityId in unseenActivityIds {
            if let persistedActivityState = persistedActivityStates[unseenActivityId] {
                ActivitySyncer.removeLiveActivity(unseenActivityId, topic: persistedActivityState.topic, custom: persistedActivityState.custom)
                persistedActivityStates.removeValue(forKey: unseenActivityId)
            }
        }
        
        // Monitor for newly created activities
        Task {
            for await updatedActivity in Activity<Attributes>.activityUpdates {
                print("ActivitySyncer<\(self.attributesTypeName)>: activityUpdates yielded \(self.liveActivityDescription(updatedActivity))")
                self.monitorLiveActivity(activity: updatedActivity)
            }
            print("ActivitySyncer<\(self.attributesTypeName)>: activityUpdates EOS")
        }
    }
    
    private func monitorLiveActivity(activity: Activity<Attributes>) -> Void {
        print("monitorLiveActivities for \(activity.id): Initial. Activity: \(self.liveActivityDescription(activity))")
        self.refreshActivity(activity)
        Task {
            for await activityState in activity.activityStateUpdates {
                print("monitorLiveActivities for \(activity.id): Activity state update. New: \(activityState). Activity: \(self.liveActivityDescription(activity))")
                self.refreshActivity(activity)
            }
            print("monitorLiveActivities for \(activity.id): Activity state update EOS")
        }
        Task {
            for await pushToken in activity.pushTokenUpdates {
                print("monitorLiveActivities for \(activity.id): Push token update. New: \(pushToken.hexEncodedString()). Activity: \(self.liveActivityDescription(activity))")
                self.refreshActivity(activity)
            }
            print("monitorLiveActivities for \(activity.id): Push token update EOS")
        }
        Task {
            let encoder = JSONEncoder()
            for await contentState in activity.contentStateUpdates {
                let contentStateJson = try? String(decoding: encoder.encode(contentState), as: UTF8.self)
                print("monitorLiveActivities for \(activity.id): Content state update. New: \(contentStateJson ?? "ERROR"). Activity: \(self.liveActivityDescription(activity))")
                self.refreshActivity(activity)
            }
            print("monitorLiveActivities for \(activity.id): Content state update EOS")
        }
    }
    
    private func refreshActivity(_ activity: Activity<Attributes>) -> Void {
        let previousPersistedState = self.persistedActivityStates[activity.id]
        let (topic, custom) = propertiesExtractor.extractTopicAndProperties(activity: activity)
        
        let newPersistedState = ActivitySyncer.updateLiveActivity(activity, topic: topic, custom: custom, previousPersistedState: previousPersistedState)
        persistedActivityStates[activity.id] = newPersistedState
    }
    
    private func liveActivityDescription<Attributes : ActivityAttributes>(_ activity: Activity<Attributes>) -> String {
        return "Activity<\(String(describing: type(of: Attributes.self)))>(id: \(activity.id), state: \(activity.activityState), attributes:…, contentState: …, pushToken: \(activity.pushToken == nil ? "None" : "PRESENT")))"
        //        let encoder = JSONEncoder()
        //        let attributesJson = try? String(decoding: encoder.encode(activity.attributes), as: UTF8.self)
        //        let contentStateJson = try? String(decoding: encoder.encode(activity.contentState), as: UTF8.self)
        //        return "Activity<\(String(describing: type(of: Attributes.self)))>(id: \(activity.id), state: \(activity.activityState), attributes: \(attributesJson ?? "ERROR"), contentState: \(contentStateJson ?? "ERROR"), pushToken: \(String(describing: activity.pushToken?.hexEncodedString() ?? "None")))"
    }
    
    @available(iOS 16.1, *)
    private class func removeLiveActivity(_ id: String, topic: String?, custom: Properties?) {
        Configuration.updatePersistedActivityStates { persistedActivtyStates in
            persistedActivtyStates.removeValue(forKey: id)
        }
        let eventAttributes = (custom ?? [:]).merging([
            "string_liveActivityId": id,
            "string_liveActivityTopic": topic ?? NSNull(),
            "ignore_liveActivityPushToken": NSNull(),
            "date_liveActivityExpiration": 0,
        ]) { _, new in
            new
        }
        print("WonderPush.trackEvent(\"NewLiveActivity\", attributes: \(eventAttributes))")
        WonderPush.trackEvent("NewLiveActivity", attributes: eventAttributes)
    }
    
    @available(iOS 16.1, *)
    private class func updateLiveActivity<Attributes : ActivityAttributes>(_ activity: Activity<Attributes>, topic: String, custom: Properties?, previousPersistedState: PersistedActivityState?) -> PersistedActivityState? {
        let interesting = activity.activityState == .active && activity.pushToken != nil
        if !interesting {
            if previousPersistedState != nil {
                print("updateLiveActivity(\(activity.id)) needs to be removed")
                removeLiveActivity(activity.id, topic: topic, custom: custom)
            } else {
                print("updateLiveActivity(\(activity.id)) will simply ignore")
            }
            return nil
        }
        
        var userId = WonderPush.userId()
        var creationDate = Date()
        print("updateLiveActivity(\(activity.id)) new custom: \(String(describing: custom))")
        if let previousPersistedState = previousPersistedState {
            print("updateLiveActivity(\(activity.id)) may need to be updated from \(previousPersistedState)")
            creationDate = previousPersistedState.creationDate
            userId = previousPersistedState.userId
        } else {
            print("updateLiveActivity(\(activity.id)) needs to be created")
        }
        let newPersistedState = PersistedActivityState(attributesTypeName: String(describing: Attributes.self), id: activity.id, creationDate: creationDate, activityState: activity.activityState, pushToken: activity.pushToken, userId: userId, topic: topic, custom: custom)
        if let previousPersistedState = previousPersistedState {
            // Check for any change
            if newPersistedState == previousPersistedState {
                print("updateLiveActivity(\(activity.id)) did not change")
                return newPersistedState
            }
        }
        print("updateLiveActivity(\(activity.id)) upserting \(String(describing: newPersistedState))")
        Configuration.updatePersistedActivityStates { persistedActivtyStates in
            persistedActivtyStates[activity.id] = newPersistedState
        }
        let eventAttributes = (custom ?? [:]).merging([
            "string_liveActivityId": activity.id,
            "string_liveActivityTopic": topic,
            "ignore_liveActivityPushToken": activity.pushToken!.hexEncodedString(),
            "date_liveActivityExpiration": ISO8601DateFormatter().string(from: creationDate.addingTimeInterval(3600 * 8)),
        ]) { _, new in
            new
        }
        print("WonderPush.trackEvent(\"NewLiveActivity\", attributes: \(eventAttributes))")
        WonderPush.trackEvent("NewLiveActivity", attributes: eventAttributes)
        return newPersistedState
    }
    
}

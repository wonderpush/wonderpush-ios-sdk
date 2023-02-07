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
    var liveActivitySyncs: [String: WPJsonSyncLiveActivity] = [:]
    var monitoredActivities: [Activity<Attributes>] = []
    
    static func createIfNotExists(attributesType: Attributes.Type, propertiesExtractor: ActivityPropertiesExtractor<Attributes>) {
        let liveActivityIdsPerAttributesTypeName = WonderPushObjCInterop.WonderPushPrivate.liveActivityIdsPerAttributesTypeName()
        if let syncer = activitySyncersLock.withCriticalSection(block: {
            var rtn: ActivitySyncer<Attributes>?
            if activitySyncers[ObjectIdentifier(attributesType)] == nil {
                let knownActivityIds = liveActivityIdsPerAttributesTypeName[String(describing: attributesType)];
                let syncer = ActivitySyncer(attributesType: attributesType, propertiesExtractor: propertiesExtractor, knownActivityIds: knownActivityIds)
                activitySyncers[ObjectIdentifier(attributesType)] = syncer
                rtn = syncer
            }
            return rtn
        }) {
            syncer.start()
        }
    }

    init(attributesType: Attributes.Type, propertiesExtractor: ActivityPropertiesExtractor<Attributes>, knownActivityIds: [String]?) {
        self.attributesType = attributesType
        self.attributesTypeIdentifier = ObjectIdentifier(attributesType)
        self.attributesTypeName = String(describing: attributesType)
        self.propertiesExtractor = propertiesExtractor
        for id in knownActivityIds ?? [] {
            self.liveActivitySyncs[id] = WonderPushObjCInterop.initWPJsonSyncLiveActivityFromSavedStateForActivityId(id)
        }
    }
    
    private func start() -> Void {
        // Caller should call only once per Attributes
        WPLogDebug("ActivitySyncer<\(self.attributesTypeName)> starting()")
        var unseenActivityIds = Set(liveActivitySyncs.keys)
        WPLogDebug("ActivitySyncer<\(self.attributesTypeName)>: Current activities:")
        for activity in Activity<Attributes>.activities {
            WPLogDebug("ActivitySyncer<\(self.attributesTypeName)>: current activity: \(self.liveActivityDescription(activity))")
            unseenActivityIds.remove(activity.id)
            self.monitorLiveActivity(activity: activity)
        }
        WPLogDebug("ActivitySyncer<\(self.attributesTypeName)>: Current activities EOL")
        
        // Remove persisted but no longer present Live Activities
        for unseenActivityId in unseenActivityIds {
            if let liveActivitySync = liveActivitySyncs[unseenActivityId] {
                liveActivitySync.activityChangedWithAttributesType(nil, creationDate: nil, activityState: ActivitySyncer.activityStateToString(.ended), pushToken: nil, staleDate: nil, relevanceScore: nil, topic: nil, custom: nil)
                liveActivitySyncs.removeValue(forKey: unseenActivityId)
            }
        }
        
        // Monitor for newly created activities
        Task {
            for await updatedActivity in Activity<Attributes>.activityUpdates {
                WPLogDebug("ActivitySyncer<\(self.attributesTypeName)>: activityUpdates yielded \(self.liveActivityDescription(updatedActivity))")
                self.monitorLiveActivity(activity: updatedActivity)
            }
            WPLogDebug("ActivitySyncer<\(self.attributesTypeName)>: activityUpdates EOS")
        }
    }
    
    private func monitorLiveActivity(activity: Activity<Attributes>) -> Void {
        WPLogDebug("monitorLiveActivities for \(activity.id): Initial. Activity: \(self.liveActivityDescription(activity))")
        self.refreshActivity(activity)
        Task {
            for await activityState in activity.activityStateUpdates {
                WPLogDebug("monitorLiveActivities for \(activity.id): Activity state update. New: \(activityState). Activity: \(self.liveActivityDescription(activity))")
                self.refreshActivity(activity)
            }
            WPLogDebug("monitorLiveActivities for \(activity.id): Activity state update EOS")
        }
        Task {
            for await pushToken in activity.pushTokenUpdates {
                WPLogDebug("monitorLiveActivities for \(activity.id): Push token update. New: \(pushToken.hexEncodedString()). Activity: \(self.liveActivityDescription(activity))")
                self.refreshActivity(activity)
            }
            WPLogDebug("monitorLiveActivities for \(activity.id): Push token update EOS")
        }
        Task {
            let encoder = JSONEncoder()
            for await contentState in activity.contentStateUpdates {
                let contentStateJson = try? String(decoding: encoder.encode(contentState), as: UTF8.self)
                WPLogDebug("monitorLiveActivities for \(activity.id): Content state update. New: \(contentStateJson ?? "ERROR"). Activity: \(self.liveActivityDescription(activity))")
                self.refreshActivity(activity)
            }
            WPLogDebug("monitorLiveActivities for \(activity.id): Content state update EOS")
        }
    }
    
    private func refreshActivity(_ activity: Activity<Attributes>) -> Void {
        var liveActivitySync = self.liveActivitySyncs[activity.id]
        if liveActivitySync == nil {
            liveActivitySync = WonderPushObjCInterop.initWPJsonSyncLiveActivityWithActivityId(activity.id, userId: WonderPush.userId(), attributesTypeName: self.attributesTypeName)
            self.liveActivitySyncs[activity.id] = liveActivitySync
        }
        let (topic, custom) = propertiesExtractor.extractTopicAndProperties(activity: activity)
        var staleDate: Date?
        var relevanceScore: Double?
        if #available(iOS 16.2, *) {
            staleDate = activity.content.staleDate
            relevanceScore = activity.content.relevanceScore
        }
        liveActivitySync?.activityChangedWithAttributesType(self.attributesTypeName, creationDate: nil, activityState: ActivitySyncer.activityStateToString(activity.activityState), pushToken: activity.pushToken, staleDate: staleDate, relevanceScore: relevanceScore as NSNumber?, topic: topic, custom: custom.map({ custom in NSDictionary(dictionary: custom) }))
    }
    
    private func liveActivityDescription<Attributes : ActivityAttributes>(_ activity: Activity<Attributes>) -> String {
        var staleDate: Date?
        var relevanceScore: Double?
        if #available(iOS 16.2, *) {
            staleDate = activity.content.staleDate
            relevanceScore = activity.content.relevanceScore
        }
        return "Activity<\(String(describing: type(of: Attributes.self)))>(id: \(activity.id), state: \(activity.activityState), attributes:…, contentState: …, staleDate: \(String(describing: staleDate)), relevanceScore: \(String(describing: relevanceScore)), pushToken: \(activity.pushToken == nil ? "None" : "PRESENT")))"
        //        let encoder = JSONEncoder()
        //        let attributesJson = try? String(decoding: encoder.encode(activity.attributes), as: UTF8.self)
        //        let contentStateJson = try? String(decoding: encoder.encode(activity.contentState), as: UTF8.self)
        //        return "Activity<\(String(describing: type(of: Attributes.self)))>(id: \(activity.id), state: \(activity.activityState), attributes: \(attributesJson ?? "ERROR"), contentState: \(contentStateJson ?? "ERROR"), pushToken: \(String(describing: activity.pushToken?.hexEncodedString() ?? "None")))"
    }
    
    private class func activityStateToString(_ activityState: ActivityState) -> String {
        switch activityState {
        case .active:
            return "active"
        case .dismissed:
            return "dismissed"
        case .ended:
            return "ended"
        case .stale:
            return "stale"
        default:
            return String(describing: activityState)
        }
    }
    
}

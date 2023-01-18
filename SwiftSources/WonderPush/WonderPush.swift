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

public typealias Properties = [AnyHashable : Any]

@available(iOS 16.1, *)
public class PropertiesExtractor<Attributes : ActivityAttributes> {

    private let extractor: (Activity<Attributes>) -> (String, Properties?)

    public init(type: String, properties: Properties? = nil) {
        extractor = { _ in (type, properties) }
    }

    public init(type: @escaping (Activity<Attributes>) -> String, properties: Properties? = nil) {
        extractor = { activity in (type(activity), properties) }
    }

    public init(type: String, properties: @escaping (Activity<Attributes>) -> Properties?) {
        extractor = { activity in (type, properties(activity)) }
    }

    public init(type: @escaping (Activity<Attributes>) -> String, properties: @escaping (Activity<Attributes>) -> Properties?) {
        extractor = { activity in (type(activity), properties(activity)) }
    }
    
    public init(typeAndProperties: @escaping (Activity<Attributes>) -> (String, Properties?)) {
        extractor = typeAndProperties
    }
    
    func extractTypeAndProperties(activity: Activity<Attributes>) -> (String, Properties?) {
        return extractor(activity)
    }

}

@available(iOS 16.1, *)
class ActivitySyncer<Attributes : ActivityAttributes> {
    
    let attributesType: Attributes.Type
    let attributesTypeIdentifier: ObjectIdentifier
    let attributesTypeName: String
    let propertiesExtractor: PropertiesExtractor<Attributes>
    var persistedActivityStates: [String: PersistedActivityState] = [:]
    var monitoredActivities: [Activity<Attributes>] = []
    
    init(attributesType: Attributes.Type, propertiesExtractor: PropertiesExtractor<Attributes>, persistedActivityStates: [String : PersistedActivityState]) {
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
    
    func start() -> Void {
        // Caller should call only once per Attributes
        print("ActivitySyncer<\(self.attributesTypeName)> starting()")
        print("ActivitySyncer<\(self.attributesTypeName)>: Current activities:")
        for activity in Activity<Attributes>.activities {
            print("ActivitySyncer<\(self.attributesTypeName)>: current activity: \(self.liveActivityDescription(activity))")
            self.monitorLiveActivity(activity: activity)
        }
        print("ActivitySyncer<\(self.attributesTypeName)>: Current activities EOL")
        Task {
            for await updatedActivity in Activity<Attributes>.activityUpdates {
                print("ActivitySyncer<\(self.attributesTypeName)>: activityUpdates yielded \(self.liveActivityDescription(updatedActivity))")
                self.monitorLiveActivity(activity: updatedActivity)
            }
            print("ActivitySyncer<\(self.attributesTypeName)>: activityUpdates EOS")
        }
    }
    
    func monitorLiveActivity(activity: Activity<Attributes>) -> Void {
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
    
    func refreshActivity(_ activity: Activity<Attributes>) -> Void {
        let previousPersistedState = self.persistedActivityStates[activity.id]
        let (type, custom) = propertiesExtractor.extractTypeAndProperties(activity: activity)
        
        let newPersistedState = WonderPush.updateLiveActivity(activity, type: type, custom: custom, previousPersistedState: previousPersistedState)
        persistedActivityStates[activity.id] = newPersistedState
    }
    
    public func liveActivityDescription<Attributes : ActivityAttributes>(_ activity: Activity<Attributes>) -> String {
        return "Activity<\(String(describing: type(of: Attributes.self)))>(id: \(activity.id), state: \(activity.activityState), attributes:…, contentState: …, pushToken: \(activity.pushToken == nil ? "None" : "PRESENT")))"
//        let encoder = JSONEncoder()
//        let attributesJson = try? String(decoding: encoder.encode(activity.attributes), as: UTF8.self)
//        let contentStateJson = try? String(decoding: encoder.encode(activity.contentState), as: UTF8.self)
//        return "Activity<\(String(describing: type(of: Attributes.self)))>(id: \(activity.id), state: \(activity.activityState), attributes: \(attributesJson ?? "ERROR"), contentState: \(contentStateJson ?? "ERROR"), pushToken: \(String(describing: activity.pushToken?.hexEncodedString() ?? "None")))"
    }
    
}

@available(iOS 16.1, *)
struct PersistedActivityState: Equatable & Codable {
    let attributesTypeName: String
    let id: String
    let creationDate: Date
    let activityState: ActivityState
    let pushToken: Data?
    let userId: String? // WonderPush userId used during Live Activity creation
    let type: String // WonderPush type field
    let custom: Properties? // WonderPush custom properties

    enum CodingKeys: String, CodingKey {
        case attributesTypeName
        case id
        case creationDate
        case activityState
        case pushToken
        case userId
        case type
        case customJson
    }
    
    init(attributesTypeName: String, id: String, creationDate: Date, activityState: ActivityState, pushToken: Data?, userId: String?, type: String, custom: Properties?) {
        self.attributesTypeName = attributesTypeName
        self.id = id
        self.creationDate = creationDate
        self.activityState = activityState
        self.pushToken = pushToken
        self.userId = userId
        self.type = type
        self.custom = custom
    }
    
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        attributesTypeName = try values.decode(String.self, forKey: .attributesTypeName)
        id = try values.decode(String.self, forKey: .id)
        creationDate = try values.decode(Date.self, forKey: .creationDate)
        activityState = try values.decode(ActivityState.self, forKey: .activityState)
        pushToken = try values.decodeIfPresent(Data.self, forKey: .pushToken)
        userId = try values.decodeIfPresent(String.self, forKey: .userId)
        type = try values.decode(String.self, forKey: .type)
        let customData = try values.decodeIfPresent(Data.self, forKey: .customJson)
        if let customData = customData {
            let customDataDecoded = try JSONSerialization.jsonObject(with: customData)
            self.custom = customDataDecoded as? Properties
        } else {
            self.custom = nil
        }
    }

    static func == (lhs: PersistedActivityState, rhs: PersistedActivityState) -> Bool {
        return lhs.attributesTypeName == rhs.attributesTypeName &&
            lhs.id == rhs.id &&
            lhs.creationDate == rhs.creationDate &&
            lhs.activityState == rhs.activityState &&
            lhs.pushToken == rhs.pushToken &&
            lhs.userId == rhs.userId &&
            lhs.type == rhs.type &&
            NSDictionary(dictionary: lhs.custom ?? [:] as Properties).isEqual(to: rhs.custom ?? [:] as Properties)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.attributesTypeName, forKey: .attributesTypeName)
        try container.encode(self.id, forKey: .id)
        try container.encode(self.creationDate, forKey: .creationDate)
        try container.encode(self.activityState, forKey: .activityState)
        try container.encodeIfPresent(self.pushToken, forKey: .pushToken)
        try container.encodeIfPresent(self.userId, forKey: .userId)
        try container.encode(self.type, forKey: .type)
        if let custom = custom {
            let data = try? JSONSerialization.data(withJSONObject: custom)
            if let data = data {
                try container.encode(data, forKey: .customJson)
            }
        }
    }
    
}

class WPConfiguration {
    
    class func getDecodedFromJSON<T: Decodable>(_ type: T.Type, key: String) throws -> T? {
        let data = UserDefaults.standard.data(forKey: key)
        if data == nil {
            return nil
        }
        return try JSONDecoder().decode(type, from: data!)
    }
    
    class func setEncodedToJSON<T: Encodable>(_ value: T, key: String) -> Void {
        let data = try? JSONEncoder().encode(value)
        if data == nil {
            UserDefaults.standard.removeObject(forKey: key)
        } else {
            UserDefaults.standard.set(data, forKey:key)
        }
    }
    
    @available(iOS 16.1, *)
    class func getPersistedActivityStates() -> [String: PersistedActivityState] {
        return (try? self.getDecodedFromJSON([String: PersistedActivityState].self, key: "__wonderpush_persistedActivityStates")) ?? ([:] as [String: PersistedActivityState])
    }
    
    @available(iOS 16.1, *)
    class func setPersistedActivityStates(_ value: [String: PersistedActivityState]) -> Void {
        self.setEncodedToJSON(value, key: "__wonderpush_persistedActivityStates")
    }

    @available(iOS 16.1, *)
    class func updatePersistedActivityStates(_ callback: (inout [String: PersistedActivityState]) -> Void) -> Void {
        var persistedActivityStates = self.getPersistedActivityStates()
        callback(&persistedActivityStates)
        self.setPersistedActivityStates(persistedActivityStates)
    }

}

extension WonderPush {
    @available(iOS 16.1, *)
    static var activitySyncers: [ObjectIdentifier: Any] = [:] // any ActivityAttributes.Type to ActivitySyncer<?>

    @available(iOS 16.1, *)
    public class func syncLiveActivities<Attributes : ActivityAttributes>(attributesType: Attributes.Type, propertiesExtractor: PropertiesExtractor<Attributes>) -> Void {
        if self.activitySyncers[ObjectIdentifier(attributesType)] != nil {
            return
        }
        let persistedActivityStates = WPConfiguration.getPersistedActivityStates()
        let syncer = ActivitySyncer(attributesType: attributesType, propertiesExtractor: propertiesExtractor, persistedActivityStates: persistedActivityStates)
        activitySyncers[ObjectIdentifier(attributesType)] = syncer
        syncer.start()
    }

    @available(iOS 16.1, *)
    public class func registerLiveActivity<Attributes : ActivityAttributes>(_ activity: Activity<Attributes>, type: String, custom: Properties?) -> Void {
        if activitySyncers[ObjectIdentifier(Attributes.self)] != nil {
            // Already synced
            return
        }
        let asyncStream = AsyncStream<Activity<Attributes>> { cont in
            cont.yield(activity)
            Task {
                for await _ in activity.pushTokenUpdates {
                    cont.yield(activity)
                }
            }
            Task {
                for await _ in activity.activityStateUpdates {
                    cont.yield(activity)
                }
            }
        }
        Task {
            var persistedActivityState = WPConfiguration.getPersistedActivityStates()[activity.id]
            for await _ in asyncStream {
                persistedActivityState = updateLiveActivity(activity, type: type, custom: custom, previousPersistedState: persistedActivityState)
            }
        }
    }

    @available(iOS 16.1, *)
    fileprivate class func updateLiveActivity<Attributes : ActivityAttributes>(_ activity: Activity<Attributes>, type: String, custom: Properties?, previousPersistedState: PersistedActivityState?) -> PersistedActivityState? {
        let interesting = activity.activityState == .active && activity.pushToken != nil
        if !interesting {
            if previousPersistedState != nil {
                print("updateLiveActivity(\(activity.id)) needs to be removed")
                WPConfiguration.updatePersistedActivityStates { persistedActivtyStates in
                    persistedActivtyStates.removeValue(forKey: activity.id)
                }
                let eventAttributes = (custom ?? [:]).merging([
                    "string_liveActivityId": activity.id,
                    "string_liveActivityType": type,
                    "ignore_liveActivityPushToken": NSNull(),
                    "date_liveActivityExpiration": 0,
                ]) { _, new in
                    new
                }
                print("WonderPush.trackEvent(\"NewLiveActivity\", attributes: \(eventAttributes))")
                WonderPush.trackEvent("NewLiveActivity", attributes: eventAttributes)
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
        let newPersistedState = PersistedActivityState(attributesTypeName: String(describing: Attributes.self), id: activity.id, creationDate: creationDate, activityState: activity.activityState, pushToken: activity.pushToken, userId: userId, type: type, custom: custom)
        if let previousPersistedState = previousPersistedState {
            // Check for any change
            if newPersistedState == previousPersistedState {
                print("updateLiveActivity(\(activity.id)) did not change")
                return newPersistedState
            }
        }
        print("updateLiveActivity(\(activity.id)) upserting \(String(describing: newPersistedState))")
        WPConfiguration.updatePersistedActivityStates { persistedActivtyStates in
            persistedActivtyStates[activity.id] = newPersistedState
        }
        let eventAttributes = (custom ?? [:]).merging([
            "string_liveActivityId": activity.id,
            "string_liveActivityType": type,
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

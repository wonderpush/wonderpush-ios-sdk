//
//  PersistedActivityState.swift
//  WonderPush
//
//  Created by Olivier Favre on 31/01/2023.
//  Copyright © 2023 WonderPush. All rights reserved.
//

import Foundation
import ActivityKit

@available(iOS 16.1, *)
struct PersistedActivityState: Equatable & Codable {
    let attributesTypeName: String
    let id: String
    let creationDate: Date
    let activityState: ActivityState
    let pushToken: Data?
    let userId: String? // WonderPush userId used during Live Activity creation
    let topic: String // WonderPush topic field
    let custom: Properties? // WonderPush custom properties

    enum CodingKeys: String, CodingKey {
        case attributesTypeName
        case id
        case creationDate
        case activityState
        case pushToken
        case userId
        case topic
        case customJson
    }
    
    init(attributesTypeName: String, id: String, creationDate: Date, activityState: ActivityState, pushToken: Data?, userId: String?, topic: String, custom: Properties?) {
        self.attributesTypeName = attributesTypeName
        self.id = id
        self.creationDate = creationDate
        self.activityState = activityState
        self.pushToken = pushToken
        self.userId = userId
        self.topic = topic
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
        topic = try values.decode(String.self, forKey: .topic)
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
            lhs.topic == rhs.topic &&
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
        try container.encode(self.topic, forKey: .topic)
        if let custom = custom {
            let data = try? JSONSerialization.data(withJSONObject: custom)
            if let data = data {
                try container.encode(data, forKey: .customJson)
            }
        }
    }
    
}

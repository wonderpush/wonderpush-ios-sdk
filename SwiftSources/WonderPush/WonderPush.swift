//
//  WonderPush.swift
//  WonderPush
//
//  Created by Olivier Favre on 04/01/2023.
//  Copyright © 2023 WonderPush. All rights reserved.
//

import Foundation
import ActivityKit

extension WonderPush {
    
    @available(iOS 16.1, *)
    public class func registerActivityAttributes<Attributes : ActivityAttributes>(_ activityAttributes: Attributes.Type, topic: String, properties: [AnyHashable : Any]? = nil) -> Void {
        ActivitySyncer.createIfNotExists(attributesType: activityAttributes, propertiesExtractor: ActivityPropertiesExtractor<Attributes>(topic: topic, properties: properties))
    }

    @available(iOS 16.1, *)
    public class func registerActivityAttributes<Attributes : ActivityAttributes>(_ activityAttributes: Attributes.Type, topic: @escaping (Activity<Attributes>) -> String, properties: [AnyHashable : Any]? = nil) -> Void {
        ActivitySyncer.createIfNotExists(attributesType: activityAttributes, propertiesExtractor: ActivityPropertiesExtractor<Attributes>(topic: topic, properties: properties))
    }

    @available(iOS 16.1, *)
    public class func registerActivityAttributes<Attributes : ActivityAttributes>(_ activityAttributes: Attributes.Type, topic: String, properties: @escaping (Activity<Attributes>) -> [AnyHashable : Any]?) -> Void {
        ActivitySyncer.createIfNotExists(attributesType: activityAttributes, propertiesExtractor: ActivityPropertiesExtractor<Attributes>(topic: topic, properties: properties))
    }

    @available(iOS 16.1, *)
    public class func registerActivityAttributes<Attributes : ActivityAttributes>(_ activityAttributes: Attributes.Type, topic: @escaping (Activity<Attributes>) -> String, properties: @escaping (Activity<Attributes>) -> [AnyHashable : Any]?) -> Void {
        ActivitySyncer.createIfNotExists(attributesType: activityAttributes, propertiesExtractor: ActivityPropertiesExtractor<Attributes>(topic: topic, properties: properties))
    }

    @available(iOS 16.1, *)
    public class func registerActivityAttributes<Attributes : ActivityAttributes>(_ activityAttributes: Attributes.Type, topicAndProperties: @escaping (Activity<Attributes>) -> (String, [AnyHashable : Any]?)) -> Void {
        ActivitySyncer.createIfNotExists(attributesType: activityAttributes, propertiesExtractor: ActivityPropertiesExtractor<Attributes>(topicAndProperties: topicAndProperties))
    }

}

//
//  WonderPush.swift
//  WonderPush
//
//  Created by Olivier Favre on 04/01/2023.
//  Copyright © 2023 WonderPush. All rights reserved.
//

import Foundation
import ActivityKit

public typealias Properties = [AnyHashable : Any]

extension WonderPush {
    
    public class func testObjCInterop() -> Void {
        print("Will call ObjC private interop")
        ObjCInterop.WonderPushPrivate.doSomethingInternal(withSecretAttribute: 42)
    }

    @available(iOS 16.1, *)
    public class func registerActivityAttributes<Attributes : ActivityAttributes>(_ activityAttributes: Attributes.Type, topic: String, properties: Properties? = nil) -> Void {
        ActivitySyncer.createIfNotExists(attributesType: activityAttributes, propertiesExtractor: ActivityPropertiesExtractor<Attributes>(topic: topic, properties: properties))
    }

    @available(iOS 16.1, *)
    public class func registerActivityAttributes<Attributes : ActivityAttributes>(_ activityAttributes: Attributes.Type, topic: @escaping (Activity<Attributes>) -> String, properties: Properties? = nil) -> Void {
        ActivitySyncer.createIfNotExists(attributesType: activityAttributes, propertiesExtractor: ActivityPropertiesExtractor<Attributes>(topic: topic, properties: properties))
    }

    @available(iOS 16.1, *)
    public class func registerActivityAttributes<Attributes : ActivityAttributes>(_ activityAttributes: Attributes.Type, topic: String, properties: @escaping (Activity<Attributes>) -> Properties?) -> Void {
        ActivitySyncer.createIfNotExists(attributesType: activityAttributes, propertiesExtractor: ActivityPropertiesExtractor<Attributes>(topic: topic, properties: properties))
    }

    @available(iOS 16.1, *)
    public class func registerActivityAttributes<Attributes : ActivityAttributes>(_ activityAttributes: Attributes.Type, topic: @escaping (Activity<Attributes>) -> String, properties: @escaping (Activity<Attributes>) -> Properties?) -> Void {
        ActivitySyncer.createIfNotExists(attributesType: activityAttributes, propertiesExtractor: ActivityPropertiesExtractor<Attributes>(topic: topic, properties: properties))
    }

    @available(iOS 16.1, *)
    public class func registerActivityAttributes<Attributes : ActivityAttributes>(_ activityAttributes: Attributes.Type, topicAndProperties: @escaping (Activity<Attributes>) -> (String, Properties?)) -> Void {
        ActivitySyncer.createIfNotExists(attributesType: activityAttributes, propertiesExtractor: ActivityPropertiesExtractor<Attributes>(topicAndProperties: topicAndProperties))
    }

}

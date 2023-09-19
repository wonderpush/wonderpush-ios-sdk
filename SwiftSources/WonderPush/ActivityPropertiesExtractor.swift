//
//  ActivityPropertiesExtractor.swift
//  WonderPush
//
//  Created by Olivier Favre on 31/01/2023.
//  Copyright © 2023 WonderPush. All rights reserved.
//

import Foundation
import ActivityKit

@available(iOS 16.1, *)
class ActivityPropertiesExtractor<Attributes : ActivityAttributes> {

    private let extractor: (Activity<Attributes>) -> (String, [AnyHashable : Any]?)

    public init(topic: String, properties: [AnyHashable : Any]? = nil) {
        extractor = { _ in (topic, properties) }
    }

    public init(topic: @escaping (Activity<Attributes>) -> String, properties: [AnyHashable : Any]? = nil) {
        extractor = { activity in (topic(activity), properties) }
    }

    public init(topic: String, properties: @escaping (Activity<Attributes>) -> [AnyHashable : Any]?) {
        extractor = { activity in (topic, properties(activity)) }
    }

    public init(topic: @escaping (Activity<Attributes>) -> String, properties: @escaping (Activity<Attributes>) -> [AnyHashable : Any]?) {
        extractor = { activity in (topic(activity), properties(activity)) }
    }

    public init(topicAndProperties: @escaping (Activity<Attributes>) -> (String, [AnyHashable : Any]?)) {
        extractor = topicAndProperties
    }

    func extractTopicAndProperties(activity: Activity<Attributes>) -> (String, [AnyHashable : Any]?) {
        return extractor(activity)
    }

}

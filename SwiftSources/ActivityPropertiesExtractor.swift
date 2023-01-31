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

    private let extractor: (Activity<Attributes>) -> (String, Properties?)

    public init(topic: String, properties: Properties? = nil) {
        extractor = { _ in (topic, properties) }
    }

    public init(topic: @escaping (Activity<Attributes>) -> String, properties: Properties? = nil) {
        extractor = { activity in (topic(activity), properties) }
    }

    public init(topic: String, properties: @escaping (Activity<Attributes>) -> Properties?) {
        extractor = { activity in (topic, properties(activity)) }
    }

    public init(topic: @escaping (Activity<Attributes>) -> String, properties: @escaping (Activity<Attributes>) -> Properties?) {
        extractor = { activity in (topic(activity), properties(activity)) }
    }
    
    public init(topicAndProperties: @escaping (Activity<Attributes>) -> (String, Properties?)) {
        extractor = topicAndProperties
    }
    
    func extractTopicAndProperties(activity: Activity<Attributes>) -> (String, Properties?) {
        return extractor(activity)
    }

}

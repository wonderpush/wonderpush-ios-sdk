/*
 * Copyright 2017 Google
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#import "WPIAMMessageDefinition.h"

@implementation WPIAMMessageRenderData

- (instancetype)initWithReportingData:(WPReportingData *)reportingData
                          contentData:(id<WPIAMMessageContentData>)contentData
                      renderingEffect:(WPIAMRenderingEffectSetting *)renderEffect {
    if (self = [super init]) {
        _contentData = contentData;
        _renderingEffectSettings = renderEffect;
        _reportingData = reportingData;
    }
    return self;
}
@end

@implementation WPIAMMessageDefinition
- (instancetype)initWithRenderData:(WPIAMMessageRenderData *)renderData
                           payload:(NSDictionary *)payload
                         startTime:(NSTimeInterval)startTime
                           endTime:(NSTimeInterval)endTime
                 triggerDefinition:(NSArray<WPIAMDisplayTriggerDefinition *> *)renderTriggers
                           capping:(WPIAMCappingDefinition *)capping
                 segmentDefinition:(NSDictionary *)segmentDefinition {
    if (self = [super init]) {
        _renderData = renderData;
        _renderTriggers = renderTriggers;
        _startTime = startTime;
        _endTime = endTime;
        _isTestMessage = NO;
        _segmentDefinition = segmentDefinition;
        _capping = capping;
        _payload = [payload isKindOfClass:NSDictionary.class] ? payload : [NSDictionary new];
    }
    return self;
}

- (instancetype)initTestMessageWithRenderData:(WPIAMMessageRenderData *)renderData {
    if (self = [super init]) {
        _renderData = renderData;
        _isTestMessage = YES;
    }
    return self;
}

- (BOOL)messageHasExpired {
    return self.endTime && self.endTime < [[NSDate date] timeIntervalSince1970];
}

- (BOOL)messageRenderedOnTrigger:(WPIAMRenderTrigger)trigger {
    for (WPIAMDisplayTriggerDefinition *nextTrigger in self.renderTriggers) {
        if (nextTrigger.triggerType == trigger) {
            // Note: we're ignoring minOccurrences for system events
            return YES;
        }
    }
    return NO;
}

- (BOOL)messageRenderedOnWonderPushEvent:(NSString *)eventName allTimeOccurrences:(NSInteger)allTimeOccurrences {
    for (WPIAMDisplayTriggerDefinition *nextTrigger in self.renderTriggers) {
        if (nextTrigger.triggerType == WPIAMRenderTriggerOnWonderPushEvent &&
            [nextTrigger.eventName isEqualToString:eventName]) {
            // Is there a minOccurrences criteria?
            if (nextTrigger.minOccurrences.integerValue > allTimeOccurrences) {
                // minOccurrences criteria not met, skip to next trigger definition
                continue;
            }
            return YES;
        }
    }
    return NO;
}

- (BOOL)messageHasStarted {
    return self.startTime < [[NSDate date] timeIntervalSince1970];
}

- (NSTimeInterval)delayForTrigger:(WPIAMRenderTrigger)trigger {
    for (WPIAMDisplayTriggerDefinition *definition in self.renderTriggers) {
        if (definition.triggerType == trigger) return definition.delay;
    }
    return 0;
}

@end

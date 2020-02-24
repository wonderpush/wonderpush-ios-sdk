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

#import "WPCore+InAppMessaging.h"
#import "WPIAMDisplayTriggerDefinition.h"
#import "WPIAMFetchResponseParser.h"
#import "WPIAMMessageContentData.h"
#import "WPIAMMessageContentDataWithImageURL.h"
#import "WPIAMMessageDefinition.h"
#import "WPIAMTimeFetcher.h"
#import "UIColor+WPIAMHexString.h"
#import "WPReportingData.h"
#import "WPAction_private.h"

@interface WPIAMFetchResponseParser ()
@property(nonatomic) id<WPIAMTimeFetcher> timeFetcher;
@end

@implementation WPIAMFetchResponseParser

- (instancetype)initWithTimeFetcher:(id<WPIAMTimeFetcher>)timeFetcher {
    if (self = [super init]) {
        _timeFetcher = timeFetcher;
    }
    return self;
}

- (NSArray<WPIAMMessageDefinition *> *)parseAPIResponseDictionary:(NSDictionary *)responseDict
                                                discardedMsgCount:(NSInteger *)discardCount
                                           fetchWaitTimeInSeconds:(NSNumber **)fetchWaitTime {
    if (fetchWaitTime != nil) {
        *fetchWaitTime = nil;  // It would be set to non nil value if it's detected in responseDict
        if ([responseDict[@"expirationEpochTimestampMillis"] isKindOfClass:NSString.class]) {
            NSTimeInterval nextFetchTimeInResponse =
            [responseDict[@"expirationEpochTimestampMillis"] doubleValue] / 1000;
            NSTimeInterval fetchWaitTimeInSeconds =
            nextFetchTimeInResponse - [self.timeFetcher currentTimestampInSeconds];
            
            WPLogDebug(
                       @"Detected next fetch epoch time in API response as %f seconds and wait for %f "
                       "seconds before next fetch.",
                       nextFetchTimeInResponse, fetchWaitTimeInSeconds);
            
            if (fetchWaitTimeInSeconds > 0.01) {
                *fetchWaitTime = @(fetchWaitTimeInSeconds);
                WPLogDebug(
                           @"Fetch wait time calculated from server response is negative. Discard it.");
            }
        } else {
            WPLogDebug(
                       @"No fetch epoch time detected in API response.");
        }
    }
    
    NSArray<NSDictionary *> *messageArray = responseDict[@"campaigns"];
    NSInteger discarded = 0;
    
    NSMutableArray<WPIAMMessageDefinition *> *definitions = [[NSMutableArray alloc] init];
    for (NSDictionary *nextMsg in messageArray) {
        WPIAMMessageDefinition *nextDefinition =
        [self convertToMessageDefinitionWithMessageDict:nextMsg];
        if (nextDefinition) {
            [definitions addObject:nextDefinition];
        } else {
            WPLog(
                  @"No definition generated for message node %@", nextMsg);
            discarded++;
        }
    }
    WPLogDebug(@"%lu message definitions were parsed out successfully and %lu messages are discarded",
               (unsigned long)definitions.count, (unsigned long)discarded);
    
    if (discardCount) {
        *discardCount = discarded;
    }
    return [definitions copy];
}

// Return nil if no valid triggering condition can be detected
- (NSArray<WPIAMDisplayTriggerDefinition *> *)parseTriggeringCondition:
    (NSArray<NSDictionary *> *)triggerConditions {
    if (triggerConditions == nil || triggerConditions.count == 0) {
        return nil;
    }
    
    NSMutableArray<WPIAMDisplayTriggerDefinition *> *triggers = [[NSMutableArray alloc] init];
    
    for (NSDictionary *nextTriggerCondition in triggerConditions) {
        // Parse delay
        NSTimeInterval delay = 0;
        if ([nextTriggerCondition[@"delay"] isKindOfClass:NSNumber.class]) {
            delay = [nextTriggerCondition[@"delay"] doubleValue] / 1000;
        }

        // Handle app_launch and on_foreground cases.
        if (nextTriggerCondition[@"systemEvent"]) {
            if ([nextTriggerCondition[@"systemEvent"] isEqualToString:@"ON_FOREGROUND"]) {
                [triggers addObject:[[WPIAMDisplayTriggerDefinition alloc] initForAppForegroundTriggerDelay:delay]];
            } else if ([nextTriggerCondition[@"systemEvent"] isEqualToString:@"APP_LAUNCH"]) {
                [triggers addObject:[[WPIAMDisplayTriggerDefinition alloc] initForAppLaunchTriggerDelay:delay]];
            }
        } else if ([nextTriggerCondition[@"event"] isKindOfClass:[NSDictionary class]]) {
            NSDictionary *triggeringEvent = (NSDictionary *)nextTriggerCondition[@"event"];
            if (triggeringEvent[@"name"]) {
                [triggers addObject:[[WPIAMDisplayTriggerDefinition alloc]
                                     initWithEvent:triggeringEvent[@"name"] delay:delay]];
            }
        }
    }
    
    return [triggers copy];
}

// For one element in the restful API response's messages array, convert into
// a WPIAMMessageDefinition object. If the conversion fails, a nil is returned.
- (WPIAMMessageDefinition *)convertToMessageDefinitionWithMessageDict:(NSDictionary *)campaignNode {
    @try {
        BOOL isTestMessage = NO;
        
        id isTestCampaignNode = campaignNode[@"isTestCampaign"];
        if ([isTestCampaignNode isKindOfClass:[NSNumber class]]) {
            isTestMessage = [isTestCampaignNode boolValue];
        }
        
        id schedulingNode = campaignNode[@"scheduling"];
        if (![schedulingNode isKindOfClass:[NSDictionary class]]) {
            WPLog(
                  @"scheduling does not exist or does not represent a dictionary in "
                  "message node %@",
                  campaignNode);
            return nil;
        }
        id notificationsNode = campaignNode[@"notifications"];
        if (![notificationsNode isKindOfClass:[NSArray class]] || [notificationsNode count] <= 0) {
            WPLog(
                  @"notifications does not exist or is empty or does not represent an array in "
                  "message node %@",
                  campaignNode);
            return nil;
        }
        // For now we take the first notification. Later we'll do A/B tests.
        id messageNode = [notificationsNode objectAtIndex:0];
        if (![messageNode isKindOfClass:[NSDictionary class]]) {
            WPLog(
                  @"notification does not exist or does not represent a dictionary in "
                  "campaign node %@",
                  campaignNode);
            return nil;
        }

        id payload = messageNode[@"payload"];
        id reportingNode = messageNode[@"reporting"];
        if (![reportingNode isKindOfClass:[NSDictionary class]]) {
            WPLog(
                  @"reporting does not exist or does not represent a dictionary in "
                  "message node %@",
                  messageNode);
            return nil;
        }
        NSString *campaignId = reportingNode[@"campaignId"];
        NSString *notificationId = reportingNode[@"notificationId"];
        if (!campaignId || !notificationId || ![campaignId isKindOfClass:[NSString class]] || ![notificationId isKindOfClass:[NSString class]]) {
            WPLog(
                  @"campaign or notification id is missing in message node %@", messageNode);
            return nil;
        }
        WPReportingData *reportingData = [[WPReportingData alloc] initWithDictionary:reportingNode];
        
        NSTimeInterval startTimeInSeconds = 0;
        NSTimeInterval endTimeInSeconds = 0;
        if (!isTestMessage) {
            // Parsing start/end times out of non-test messages. They are strings in the
            // json response.
            id startTimeNode = schedulingNode[@"startDate"];
            if ([startTimeNode isKindOfClass:[NSString class]] || [startTimeNode isKindOfClass:[NSNumber class]]) {
                startTimeInSeconds = [startTimeNode doubleValue] / 1000.0;
            }
            
            id endTimeNode = schedulingNode[@"endDate"];
            if ([endTimeNode isKindOfClass:[NSString class]] || [endTimeNode isKindOfClass:[NSNumber class]]) {
                endTimeInSeconds = [endTimeNode doubleValue] / 1000.0;
            }
        }
        
        id contentNode = messageNode[@"content"];
        if (![contentNode isKindOfClass:[NSDictionary class]]) {
            WPLog(
                  @"content node does not exist or does not represent a dictionary in "
                  "message node %@",
                  messageNode);
            return nil;
        }
        
        NSDictionary *content = (NSDictionary *)contentNode;
        WPIAMRenderingMode mode;
        UIColor *viewCardBackgroundColor, *btnBgColor, *btnTxtColor, *secondaryBtnTxtColor,
        *titleTextColor;
        viewCardBackgroundColor = btnBgColor = btnTxtColor = titleTextColor = nil;
        
        NSString *title, *body, *imageURLStr, *landscapeImageURLStr,
        *actionButtonText, *secondaryActionButtonText;
        title = body = imageURLStr = landscapeImageURLStr = actionButtonText =
        secondaryActionButtonText = nil;
        WPAction *action = nil, *secondaryAction = nil;
        
        // TODO: Refactor this giant if-else block into separate parsing methods per message type.
        if ([content[@"banner"] isKindOfClass:[NSDictionary class]]) {
            NSDictionary *bannerNode = (NSDictionary *)contentNode[@"banner"];
            mode = WPIAMRenderAsBannerView;
            
            title = bannerNode[@"title"][@"text"];
            titleTextColor = [UIColor firiam_colorWithHexString:bannerNode[@"title"][@"hexColor"]];
            
            body = bannerNode[@"body"][@"text"];
            
            imageURLStr = bannerNode[@"imageUrl"];
            action = [WPAction actionWithDictionaries:bannerNode[@"actions"]];
            viewCardBackgroundColor =
            [UIColor firiam_colorWithHexString:bannerNode[@"backgroundHexColor"]];
            
        } else if ([content[@"modal"] isKindOfClass:[NSDictionary class]]) {
            mode = WPIAMRenderAsModalView;
            
            NSDictionary *modalNode = (NSDictionary *)contentNode[@"modal"];
            title = modalNode[@"title"][@"text"];
            titleTextColor = [UIColor firiam_colorWithHexString:modalNode[@"title"][@"hexColor"]];
            
            body = modalNode[@"body"][@"text"];
            
            imageURLStr = modalNode[@"imageUrl"];
            actionButtonText = modalNode[@"actionButton"][@"text"][@"text"];
            btnBgColor =
            [UIColor firiam_colorWithHexString:modalNode[@"actionButton"][@"buttonHexColor"]];
            
            action = [WPAction actionWithDictionaries:modalNode[@"actions"]];
            viewCardBackgroundColor =
            [UIColor firiam_colorWithHexString:modalNode[@"backgroundHexColor"]];
        } else if ([content[@"imageOnly"] isKindOfClass:[NSDictionary class]]) {
            mode = WPIAMRenderAsImageOnlyView;
            NSDictionary *imageOnlyNode = (NSDictionary *)contentNode[@"imageOnly"];
            
            imageURLStr = imageOnlyNode[@"imageUrl"];
            
            if (!imageURLStr) {
                WPLog(
                      @"Image url is missing for image-only message %@", messageNode);
                return nil;
            }
            action = [WPAction actionWithDictionaries:imageOnlyNode[@"actions"]];
        } else if ([content[@"card"] isKindOfClass:[NSDictionary class]]) {
            mode = WPIAMRenderAsCardView;
            NSDictionary *cardNode = (NSDictionary *)contentNode[@"card"];
            title = cardNode[@"title"][@"text"];
            titleTextColor = [UIColor firiam_colorWithHexString:cardNode[@"title"][@"hexColor"]];
            
            body = cardNode[@"body"][@"text"];
            
            imageURLStr = cardNode[@"portraitImageUrl"];
            landscapeImageURLStr = cardNode[@"landscapeImageUrl"];
            
            viewCardBackgroundColor = [UIColor firiam_colorWithHexString:cardNode[@"backgroundHexColor"]];
            
            actionButtonText = cardNode[@"primaryActionButton"][@"text"][@"text"];
            btnTxtColor = [UIColor
                           firiam_colorWithHexString:cardNode[@"primaryActionButton"][@"text"][@"hexColor"]];
            
            secondaryActionButtonText = cardNode[@"secondaryActionButton"][@"text"][@"text"];
            secondaryBtnTxtColor = [UIColor
                                    firiam_colorWithHexString:cardNode[@"secondaryActionButton"][@"text"][@"hexColor"]];
            
            action = [WPAction actionWithDictionaries:cardNode[@"primaryActions"]];
            secondaryAction = [WPAction actionWithDictionaries:cardNode[@"secondaryActions"]];
            
        } else {
            // Unknown message type
            WPLog(
                  @"Unknown message type in message node %@", messageNode);
            return nil;
        }
        
        if (title == nil && mode != WPIAMRenderAsImageOnlyView) {
            WPLog(
                  @"Title text is missing in message node %@", messageNode);
            return nil;
        }
        
        NSURL *imageURL = (imageURLStr.length == 0) ? nil : [NSURL URLWithString:imageURLStr];
        NSURL *landscapeImageURL =
        (landscapeImageURLStr.length == 0) ? nil : [NSURL URLWithString:landscapeImageURLStr];
        WPIAMRenderingEffectSetting *renderEffect =
        [WPIAMRenderingEffectSetting getDefaultRenderingEffectSetting];
        renderEffect.viewMode = mode;
        
        if (viewCardBackgroundColor) {
            renderEffect.displayBGColor = viewCardBackgroundColor;
        }
        
        if (btnBgColor) {
            renderEffect.btnBGColor = btnBgColor;
        }
        
        if (btnTxtColor) {
            renderEffect.btnTextColor = btnTxtColor;
        }
        
        if (secondaryBtnTxtColor) {
            renderEffect.secondaryActionBtnTextColor = secondaryBtnTxtColor;
        }
        
        if (titleTextColor) {
            renderEffect.textColor = titleTextColor;
        }
        
        NSArray<WPIAMDisplayTriggerDefinition *> *triggersDefinition =
        [self parseTriggeringCondition:campaignNode[@"triggers"]];
        
        if (isTestMessage) {
            WPLog(
                  @"A test message with campaign id %@, notification id %@ was parsed successfully.", reportingData.campaignId, reportingData.notificationId);
            renderEffect.isTestMessage = YES;
        } else {
            // Triggering definitions should always be present for a non-test message.
            if (!triggersDefinition || triggersDefinition.count == 0) {
                WPLog(
                      @"No valid triggering condition is detected in message definition"
                      " with campaign id %@, notification id %@",
                      reportingData.campaignId, reportingData.notificationId);
                return nil;
            }
        }
        
        WPIAMMessageContentDataWithImageURL *msgData =
        [[WPIAMMessageContentDataWithImageURL alloc] initWithMessageTitle:title
                                                              messageBody:body
                                                         actionButtonText:actionButtonText
                                                secondaryActionButtonText:secondaryActionButtonText
                                                                   action:action
                                                          secondaryAction:secondaryAction
                                                                 imageURL:imageURL
                                                        landscapeImageURL:landscapeImageURL
                                                          usingURLSession:nil];
        
        WPIAMMessageRenderData *renderData =
        [[WPIAMMessageRenderData alloc] initWithReportingData:reportingData
                                                  contentData:msgData
                                              renderingEffect:renderEffect];
        
        if (isTestMessage) {
            return [[WPIAMMessageDefinition alloc] initTestMessageWithRenderData:renderData];
        } else {
            return [[WPIAMMessageDefinition alloc] initWithRenderData:renderData
                                                              payload:([payload isKindOfClass:NSDictionary.class] ? payload : [NSDictionary new])
                                                            startTime:startTimeInSeconds
                                                              endTime:endTimeInSeconds
                                                    triggerDefinition:triggersDefinition];
        }
    } @catch (NSException *e) {
        WPLog(
              @"Error in parsing message node %@ "
              "with error %@",
              campaignNode, e);
        return nil;
    }
}
@end

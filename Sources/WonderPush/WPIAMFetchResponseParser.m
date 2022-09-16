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
#import "WPIAMMessageContentDataWithMedia.h"
#import "WPIAMMessageDefinition.h"
#import "UIColor+WPIAMHexString.h"
#import <WonderPushCommon/WPReportingData.h>
#import "WPAction_private.h"
#import <WonderPushCommon/WPNSUtil.h>

@implementation WPIAMFetchResponseParser

+ (NSArray<WPIAMMessageDefinition *> *)parseAPIResponseDictionary:(NSDictionary *)responseDict
                                                discardedMsgCount:(NSInteger *)discardCount {
    NSArray<NSDictionary *> *messageArray = [WPNSUtil arrayForKey:@"campaigns" inDictionary:responseDict];
    if (!messageArray) return @[];
    NSInteger discarded = 0;
    
    NSMutableArray<WPIAMMessageDefinition *> *definitions = [[NSMutableArray alloc] init];
    for (NSDictionary *nextMsg in messageArray) {
        WPIAMMessageDefinition *nextDefinition = [self convertToMessageDefinitionWithCampaignDict:nextMsg];
        if (nextDefinition) {
            [definitions addObject:nextDefinition];
        } else {
            WPLog(
                  @"No definition generated for message node %@", nextMsg);
            discarded++;
        }
    }
    WPLogDebug(@"%lu in-app message definitions were parsed out successfully, %lu were discarded",
               (unsigned long)definitions.count, (unsigned long)discarded);
    
    if (discardCount) {
        *discardCount = discarded;
    }
    return [definitions copy];
}

// Always returns a valid WPIAMCappingDefinition
+ (WPIAMCappingDefinition *)parseCapping:(id)capping {
    if (![capping isKindOfClass:NSDictionary.class]) return [WPIAMCappingDefinition defaultCapping];
    NSInteger maxImpressions = [([WPNSUtil numberForKey:@"maxImpressions" inDictionary:capping] ?: @1) integerValue];
    NSTimeInterval snoozeTime = [([WPNSUtil numberForKey:@"snoozeTime" inDictionary:capping] ?: @0) doubleValue] / 1000;
    return [[WPIAMCappingDefinition alloc] initWithMaxImpressions:maxImpressions snoozeTime:snoozeTime];
}

// Return nil if no valid triggering condition can be detected
+ (NSArray<WPIAMDisplayTriggerDefinition *> *)parseTriggeringCondition:
    (NSArray<NSDictionary *> *)triggerConditions {
    if (triggerConditions == nil || triggerConditions.count == 0) {
        return nil;
    }
    
    NSMutableArray<WPIAMDisplayTriggerDefinition *> *triggers = [[NSMutableArray alloc] init];
    
    for (NSDictionary *nextTriggerCondition in triggerConditions) {
        // Parse delay
        NSTimeInterval delay = [([WPNSUtil numberForKey:@"delay" inDictionary:nextTriggerCondition] ?: @0) doubleValue] / 1000;

        // Count
        NSNumber *minOccurrences = [WPNSUtil numberForKey:@"minOccurrences" inDictionary:nextTriggerCondition];

        NSString *systemEvent = [WPNSUtil stringForKey:@"systemEvent" inDictionary:nextTriggerCondition];
        NSDictionary *triggeringEvent = [WPNSUtil dictionaryForKey:@"event" inDictionary:nextTriggerCondition];
        // Handle app_launch and on_foreground cases.
        if (systemEvent) {
            if ([systemEvent isEqualToString:@"ON_FOREGROUND"]) {
                [triggers addObject:[[WPIAMDisplayTriggerDefinition alloc] initForAppForegroundTriggerDelay:delay]];
            } else if ([systemEvent isEqualToString:@"APP_LAUNCH"]) {
                [triggers addObject:[[WPIAMDisplayTriggerDefinition alloc] initForAppLaunchTriggerDelay:delay]];
            }
        } else if (nextTriggerCondition) {
            NSString *type = [WPNSUtil stringForKey:@"type" inDictionary:triggeringEvent];
            if (type) {
                [triggers addObject:[[WPIAMDisplayTriggerDefinition alloc]
                                     initWithEvent:type minOccurrences:minOccurrences delay:delay]];
            }
        }
    }
    
    return [triggers copy];
}

// For one element in the restful API response's messages array, convert into
// a WPIAMMessageDefinition object. If the conversion fails, a nil is returned.
+ (WPIAMMessageDefinition *)convertToMessageDefinitionWithCampaignDict:(NSDictionary *)campaignDict {
    @try {
        BOOL isTestMessage = NO;
        
        id isTestCampaignNode = campaignDict[@"isTestCampaign"];
        if ([isTestCampaignNode isKindOfClass:[NSNumber class]]) {
            isTestMessage = [isTestCampaignNode boolValue];
        }
        
        id schedulingNode = campaignDict[@"scheduling"];
        if (![schedulingNode isKindOfClass:[NSDictionary class]]) {
            WPLog(
                  @"scheduling does not exist or does not represent a dictionary in "
                  "message node %@",
                  campaignDict);
            return nil;
        }
        id segmentNode = campaignDict[@"segment"];
        if (segmentNode && ![segmentNode isKindOfClass:NSDictionary.class]) {
            WPLog(@"Invalid segment %@", segmentNode);
            return nil;
        }
        
        id notificationsNode = campaignDict[@"notifications"];
        if (![notificationsNode isKindOfClass:[NSArray class]] || [notificationsNode count] <= 0) {
            WPLog(
                  @"notifications does not exist or is empty or does not represent an array in "
                  "message node %@",
                  campaignDict);
            return nil;
        }
        // For now we take the first notification. Later we'll do A/B tests.
        id notificationNode = [notificationsNode objectAtIndex:0];
        if (![notificationNode isKindOfClass:[NSDictionary class]]) {
            WPLog(
                  @"notification does not exist or does not represent a dictionary in "
                  "campaign node %@",
                  campaignDict);
            return nil;
        }
        WPIAMMessageRenderData *renderData = [self renderDataFromNotificationDict:notificationNode isTestMessage:isTestMessage];
        if (!renderData) return nil;

        NSArray<WPIAMDisplayTriggerDefinition *> *triggersDefinition =
        [self parseTriggeringCondition:campaignDict[@"triggers"]];

        WPIAMCappingDefinition *capping = [self parseCapping:campaignDict[@"capping"]];

        if (!isTestMessage) {
            // Triggering definitions should always be present for a non-test message.
            if (!triggersDefinition || triggersDefinition.count == 0) {
                WPLog(
                      @"No valid triggering condition is detected in message definition"
                      " with campaign id %@, notification id %@",
                      renderData.reportingData.campaignId, renderData.reportingData.notificationId);
                return nil;
            }
        }
        
        id payload = notificationNode[@"payload"];
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
        

        if (isTestMessage) {
            return [[WPIAMMessageDefinition alloc] initTestMessageWithRenderData:renderData];
        } else {
            return [[WPIAMMessageDefinition alloc] initWithRenderData:renderData
                                                              payload:([payload isKindOfClass:NSDictionary.class] ? payload : [NSDictionary new])
                                                            startTime:startTimeInSeconds
                                                              endTime:endTimeInSeconds
                                                    triggerDefinition:triggersDefinition
                                                              capping:capping
                                                    segmentDefinition:segmentNode];
        }
    } @catch (NSException *e) {
        WPLog(
              @"Error in parsing message node %@ "
              "with error %@",
              campaignDict, e);
        return nil;
    }
}
+ (WPIAMMessageRenderData * _Nullable) renderDataFromNotificationDict:(NSDictionary *)notificationDict isTestMessage:(BOOL)isTestMessage {
    @try {
        WPReportingData *reportingData = [WPReportingData extract:notificationDict];

        id contentNode = notificationDict[@"content"];
        if (![contentNode isKindOfClass:[NSDictionary class]]) {
            WPLog(
                  @"content node does not exist or does not represent a dictionary in "
                  "message node %@",
                  notificationDict);
            return nil;
        }
        
        NSDictionary *content = (NSDictionary *)contentNode;
        WPIAMRenderingMode mode;
        UIColor *viewCardBackgroundColor, *btnBgColor, *btnTxtColor, *secondaryBtnTxtColor,
        *titleTextColor, *secondaryBtnBgColor;
        viewCardBackgroundColor = btnBgColor = btnTxtColor = titleTextColor = nil;
        
        NSString *title, *body, *imageURLStr, *landscapeImageURLStr,
        *actionButtonText, *secondaryActionButtonText, *webUrlStr;
        WPIAMCloseButtonPosition closeButtonPosition = WPIAMCloseButtonPositionOutside;
        WPIAMEntryAnimation entryAnimation = WPIAMEntryAnimationFadeIn;
        WPIAMExitAnimation exitAnimation = WPIAMExitAnimationFadeOut;
        WPIAMBannerPosition bannerPosition = WPIAMBannerPositionTop;
        title = body = imageURLStr = landscapeImageURLStr = actionButtonText =
        secondaryActionButtonText = nil;
        WPAction *action = nil, *secondaryAction = nil;
        
        WPIAMEntryAnimation(^parseEntryAnimation)(NSDictionary *) = ^(id input) {
            if ([input[@"entryAnimation"] isEqualToString:@"fadeIn"]) return WPIAMEntryAnimationFadeIn;
            if ([input[@"entryAnimation"] isEqualToString:@"slideInFromRight"]) return WPIAMEntryAnimationSlideInFromRight;
            if ([input[@"entryAnimation"] isEqualToString:@"slideInFromLeft"]) return WPIAMEntryAnimationSlideInFromLeft;
            if ([input[@"entryAnimation"] isEqualToString:@"slideInFromTop"]) return WPIAMEntryAnimationSlideInFromTop;
            if ([input[@"entryAnimation"] isEqualToString:@"slideInFromBottom"]) return WPIAMEntryAnimationSlideInFromBottom;
            return WPIAMEntryAnimationFadeIn;
        };
        WPIAMExitAnimation(^parseExitAnimation)(NSDictionary *) = ^(id input) {
            if ([input[@"exitAnimation"] isEqualToString:@"fadeOut"]) return WPIAMExitAnimationFadeOut;
            if ([input[@"exitAnimation"] isEqualToString:@"slideOutRight"]) return WPIAMExitAnimationSlideOutRight;
            if ([input[@"exitAnimation"] isEqualToString:@"slideOutLeft"]) return WPIAMExitAnimationSlideOutLeft;
            if ([input[@"exitAnimation"] isEqualToString:@"slideOutUp"]) return WPIAMExitAnimationSlideOutUp;
            if ([input[@"exitAnimation"] isEqualToString:@"slideOutDown"]) return WPIAMExitAnimationSlideOutDown;
            return WPIAMExitAnimationFadeOut;
        };
        // TODO: Refactor this giant if-else block into separate parsing methods per message type.
        if ([content[@"banner"] isKindOfClass:[NSDictionary class]]) {
            NSDictionary *bannerNode = (NSDictionary *)contentNode[@"banner"];
            mode = WPIAMRenderAsBannerView;
            
            title = bannerNode[@"title"][@"text"];
            titleTextColor = [UIColor firiam_colorWithHexString:bannerNode[@"title"][@"hexColor"]];
            
            if (bannerNode[@"body"] && bannerNode[@"body"] != NSNull.null) {
                body = bannerNode[@"body"][@"text"];
            }
            
            imageURLStr = bannerNode[@"imageUrl"];
            action = [WPAction actionWithDictionaries:bannerNode[@"actions"]];
            viewCardBackgroundColor =
            [UIColor firiam_colorWithHexString:bannerNode[@"backgroundHexColor"]];
            if ([bannerNode[@"bannerPosition"] isEqualToString:@"bottom"]) {
                bannerPosition = WPIAMBannerPositionBottom;
            }
        } else if ([content[@"modal"] isKindOfClass:[NSDictionary class]]) {
            mode = WPIAMRenderAsModalView;
            NSDictionary *modalNode = (NSDictionary *)contentNode[@"modal"];
            entryAnimation = parseEntryAnimation(modalNode);
            exitAnimation = parseExitAnimation(modalNode);
            title = modalNode[@"title"][@"text"];
            titleTextColor = [UIColor firiam_colorWithHexString:modalNode[@"title"][@"hexColor"]];
            
            if (modalNode[@"body"] && modalNode[@"body"] != NSNull.null) {
                body = modalNode[@"body"][@"text"];
            }
            
            imageURLStr = modalNode[@"imageUrl"];
            if (modalNode[@"actionButton"] && modalNode[@"actionButton"] != NSNull.null) {
                btnBgColor =
                [UIColor firiam_colorWithHexString:modalNode[@"actionButton"][@"buttonHexColor"]];
                if (modalNode[@"actionButton"][@"text"] && modalNode[@"actionButton"][@"text"] != NSNull.null) {
                    actionButtonText = modalNode[@"actionButton"][@"text"][@"text"];
                    btnTxtColor = [UIColor
                                   firiam_colorWithHexString:modalNode[@"actionButton"][@"text"][@"hexColor"]];
                }
            }
            
            action = [WPAction actionWithDictionaries:modalNode[@"actions"]];
            viewCardBackgroundColor =
            [UIColor firiam_colorWithHexString:modalNode[@"backgroundHexColor"]];
            if ([modalNode[@"closeButtonPosition"] isEqualToString:@"outside"]) closeButtonPosition = WPIAMCloseButtonPositionOutside;
            if ([modalNode[@"closeButtonPosition"] isEqualToString:@"inside"]) closeButtonPosition = WPIAMCloseButtonPositionInside;
            if ([modalNode[@"closeButtonPosition"] isEqualToString:@"none"]) closeButtonPosition = WPIAMCloseButtonPositionNone;

        } else if ([content[@"imageOnly"] isKindOfClass:[NSDictionary class]]) {
            mode = WPIAMRenderAsImageOnlyView;
            NSDictionary *imageOnlyNode = (NSDictionary *)contentNode[@"imageOnly"];
            entryAnimation = parseEntryAnimation(imageOnlyNode);
            exitAnimation = parseExitAnimation(imageOnlyNode);

            imageURLStr = imageOnlyNode[@"imageUrl"];
            
            if (!imageURLStr) {
                WPLog(
                      @"Image url is missing for image-only message %@", notificationDict);
                return nil;
            }
            action = [WPAction actionWithDictionaries:imageOnlyNode[@"actions"]];
            if ([imageOnlyNode[@"closeButtonPosition"] isEqualToString:@"outside"]) closeButtonPosition = WPIAMCloseButtonPositionOutside;
            if ([imageOnlyNode[@"closeButtonPosition"] isEqualToString:@"inside"]) closeButtonPosition = WPIAMCloseButtonPositionInside;
            if ([imageOnlyNode[@"closeButtonPosition"] isEqualToString:@"none"]) closeButtonPosition = WPIAMCloseButtonPositionNone;
        } else if ([content[@"webView"] isKindOfClass:[NSDictionary class]]) {
            mode = WPIAMRenderAsWebView;
            NSDictionary *webViewNode = (NSDictionary *)contentNode[@"webView"];
            entryAnimation = parseEntryAnimation(webViewNode);
            exitAnimation = parseExitAnimation(webViewNode);

            webUrlStr = webViewNode[@"url"];
            if (!webUrlStr) {
                WPLog(@"web url is missing for webView message %@", notificationDict);
                return nil;
            }
            action = [WPAction actionWithDictionaries:webViewNode[@"actions"]];
            if ([@"none" isEqualToString:webViewNode[@"closeButtonPosition"]]) {
                closeButtonPosition = WPIAMCloseButtonPositionNone;
            } else {
                closeButtonPosition = WPIAMCloseButtonPositionInside;
            }
        } else if ([content[@"card"] isKindOfClass:[NSDictionary class]]) {
            mode = WPIAMRenderAsCardView;
            NSDictionary *cardNode = (NSDictionary *)contentNode[@"card"];
            entryAnimation = parseEntryAnimation(cardNode);
            exitAnimation = parseExitAnimation(cardNode);
            title = cardNode[@"title"][@"text"];
            titleTextColor = [UIColor firiam_colorWithHexString:cardNode[@"title"][@"hexColor"]];
            
            if (cardNode[@"body"] && cardNode[@"body"] != NSNull.null) {
                body = cardNode[@"body"][@"text"];
            }
            
            imageURLStr = cardNode[@"portraitImageUrl"];
            landscapeImageURLStr = cardNode[@"landscapeImageUrl"];
            
            viewCardBackgroundColor = [UIColor firiam_colorWithHexString:cardNode[@"backgroundHexColor"]];
            
            if (cardNode[@"primaryActionButton"] && cardNode[@"primaryActionButton"] != NSNull.null) {
                if (cardNode[@"primaryActionButton"][@"text"] && cardNode[@"primaryActionButton"][@"text"] != NSNull.null) {
                    actionButtonText = cardNode[@"primaryActionButton"][@"text"][@"text"];
                    btnTxtColor = [UIColor
                                   firiam_colorWithHexString:cardNode[@"primaryActionButton"][@"text"][@"hexColor"]];
                }
                btnBgColor = [UIColor firiam_colorWithHexString:cardNode[@"primaryActionButton"][@"buttonHexColor"]];
            }
            
            if (cardNode[@"secondaryActionButton"] && cardNode[@"secondaryActionButton"] != NSNull.null) {
                if (cardNode[@"secondaryActionButton"][@"text"] && cardNode[@"secondaryActionButton"][@"text"] != NSNull.null) {
                    secondaryActionButtonText = cardNode[@"secondaryActionButton"][@"text"][@"text"];
                    secondaryBtnTxtColor = [UIColor
                                            firiam_colorWithHexString:cardNode[@"secondaryActionButton"][@"text"][@"hexColor"]];
                }
                secondaryBtnBgColor = [UIColor firiam_colorWithHexString:cardNode[@"secondaryActionButton"][@"buttonHexColor"]];
            }

            action = [WPAction actionWithDictionaries:cardNode[@"primaryActions"]];
            secondaryAction = [WPAction actionWithDictionaries:cardNode[@"secondaryActions"]];
            
        } else {
            // Unknown message type
            WPLog(
                  @"Unknown message type in message node %@", notificationDict);
            return nil;
        }
        
        if ((title == nil || (id)title == NSNull.null) && mode != WPIAMRenderAsImageOnlyView && mode != WPIAMRenderAsWebView) {
            WPLog(
                  @"Title text is missing in message node %@", notificationDict);
            return nil;
        }
        
        NSURL *webURL = nil;
        if ([webUrlStr isKindOfClass:NSString.class] && webUrlStr.length > 0){
            webURL = [NSURL URLWithString:webUrlStr];
            if (!webURL) {
                WPLog(@"Invalid url specified for in-app message: %@", webUrlStr);
            }
        }

        NSURL *imageURL = ((id)imageURLStr == NSNull.null || imageURLStr.length == 0) ? nil : [NSURL URLWithString:imageURLStr];
        NSURL *landscapeImageURL =
        ((id)landscapeImageURLStr == NSNull.null || landscapeImageURLStr.length == 0) ? nil : [NSURL URLWithString:landscapeImageURLStr];
        WPIAMRenderingEffectSetting *renderEffect =
        [WPIAMRenderingEffectSetting getDefaultRenderingEffectSetting];
        renderEffect.viewMode = mode;
        
        if (viewCardBackgroundColor) {
            renderEffect.displayBGColor = viewCardBackgroundColor;
        }
        
        if (btnBgColor) {
            renderEffect.btnBGColor = btnBgColor;
        }
        
        if (secondaryBtnBgColor) {
            renderEffect.secondaryActionBtnBGColor = secondaryBtnBgColor;
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
        
        if (isTestMessage) {
            WPLog(
                  @"A test message with campaign id %@, notification id %@ was parsed successfully.", reportingData.campaignId, reportingData.notificationId);
            renderEffect.isTestMessage = YES;
        }
        
        // Remove NSNulls
        if ((id)body == NSNull.null) body = nil;
        if ((id)actionButtonText == NSNull.null) actionButtonText = nil;
        if ((id)secondaryActionButtonText == NSNull.null) secondaryActionButtonText = nil;

        WPIAMMessageContentDataWithMedia *msgData =
        [[WPIAMMessageContentDataWithMedia alloc] initWithMessageTitle:title
                                                           messageBody:body
                                                      actionButtonText:actionButtonText
                                             secondaryActionButtonText:secondaryActionButtonText
                                                                action:action
                                                       secondaryAction:secondaryAction
                                                              imageURL:imageURL
                                                     landscapeImageURL:landscapeImageURL
                                                                webURL:webURL
                                                   closeButtonPosition:closeButtonPosition
                                                        bannerPosition:bannerPosition
                                                        entryAnimation:entryAnimation
                                                         exitAnimation:exitAnimation
                                                       usingURLSession:nil];
        
        WPIAMMessageRenderData *renderData =
        [[WPIAMMessageRenderData alloc] initWithReportingData:reportingData
                                                  contentData:msgData
                                              renderingEffect:renderEffect];

        return renderData;
    } @catch (NSException *exception) {
        WPLog(
              @"Error in parsing message node %@ "
              "with error %@",
              notificationDict, exception);
        return nil;
    }
}
@end

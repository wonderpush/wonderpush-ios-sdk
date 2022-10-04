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

#import <UIKit/UIKit.h>
#import "WPCore+InAppMessaging.h"
#import "WPIAMDisplayExecutor.h"
#import "WPIAMMessageContentData.h"
#import "WPIAMMessageDefinition.h"
#import "WPIAMSDKRuntimeErrorCodes.h"
#import <WonderPush/WPInAppMessaging.h>
#import "WPInAppMessagingRenderingPrivate.h"
#import "WonderPush_private.h"
#import "WPAction_private.h"
#import "WPIAMTimeFetcher.h"
#import "WPIAMDefaultDisplayImpl.h"

@implementation WPIAMDisplaySetting
@end

@interface WPIAMDisplayExecutor () <WPInAppMessagingControllerDelegate>
@property(nonatomic) id<WPIAMTimeFetcher> timeFetcher;

// YES if a message is being rendered at this time
@property(nonatomic) BOOL isMsgBeingDisplayed;
@property(nonatomic) NSTimeInterval lastRateLimitedInAppDisplayTime;
@property(nonatomic) NSTimeInterval lastInAppDisplayTime;
@property(nonatomic, nonnull, readonly) WPInAppMessaging *inAppMessaging;
@property(nonatomic, nonnull, readonly) WPIAMDisplaySetting *setting;
@property(nonatomic, nonnull, readonly) WPIAMMessageClientCache *messageCache;
@property(nonatomic, nonnull, readonly) id<WPIAMBookKeeper> displayBookKeeper;
@property(nonatomic) BOOL impressionRecorded;
@property(nonatomic, strong) NSMutableSet<NSString *> *campaignIdsImpressedWithoutClick;
// Used for displaying the test on device message error alert.
@property(nonatomic, strong) UIWindow *alertWindow;
@end

@implementation WPIAMDisplayExecutor {
    WPIAMMessageDefinition *_currentMsgBeingDisplayed;
}

+ (WPInAppMessagingEntryAnimation)convertEntryAnimation:(WPIAMEntryAnimation)entryAnimation {
    switch (entryAnimation) {
        case WPIAMEntryAnimationFadeIn: return WPInAppMessagingEntryAnimationFadeIn;
        case WPIAMEntryAnimationSlideInFromTop: return WPInAppMessagingEntryAnimationSlideInFromTop;
        case WPIAMEntryAnimationSlideInFromRight: return WPInAppMessagingEntryAnimationSlideInFromRight;
        case WPIAMEntryAnimationSlideInFromBottom: return WPInAppMessagingEntryAnimationSlideInFromBottom;
        case WPIAMEntryAnimationSlideInFromLeft: return WPInAppMessagingEntryAnimationSlideInFromLeft;
    }
}
+ (WPInAppMessagingExitAnimation)convertExitAnimation:(WPIAMExitAnimation)exitAnimation {
    switch (exitAnimation) {
        case WPIAMExitAnimationFadeOut: return WPInAppMessagingExitAnimationFadeOut;
        case WPIAMExitAnimationSlideOutDown: return WPInAppMessagingExitAnimationSlideOutDown;
        case WPIAMExitAnimationSlideOutUp: return WPInAppMessagingExitAnimationSlideOutUp;
        case WPIAMExitAnimationSlideOutLeft: return WPInAppMessagingExitAnimationSlideOutLeft;
        case WPIAMExitAnimationSlideOutRight: return WPInAppMessagingExitAnimationSlideOutRight;
    }
}
#pragma mark - WPInAppMessagingDisplayDelegate methods

- (void)trackClickWithMessage:(WPInAppMessagingDisplayMessage *)inAppMessage
       buttonLabel:(NSString *)buttonLabel {
    if (!_currentMsgBeingDisplayed.renderData.reportingData.campaignId) {
        WPLog(@"messageClicked called but there is no current message ID.");
        return;
    }
    if (_currentMsgBeingDisplayed.isTestMessage) {
        WPLogDebug(@"A test message clicked. Do test event impression/click analytics logging");
    } else {
        // Logging the impression
        [self recordValidImpression:_currentMsgBeingDisplayed.renderData.reportingData];
    }
    
    // Send an event to log click
    NSMutableDictionary *eventData = [NSMutableDictionary new];
    [_currentMsgBeingDisplayed.renderData.reportingData fillEventDataInto:eventData attributionReason:WPReportingAttributionReasonInAppViewed];
    eventData[@"actionDate"] = [NSNumber numberWithLongLong:(long long)([self.timeFetcher currentTimestampInSeconds] * 1000)];
    if (buttonLabel) eventData[@"buttonLabel"] = buttonLabel;
    BOOL trackInAppClicked = NO;
    NSString *campaignId = _currentMsgBeingDisplayed.renderData.reportingData.campaignId;
    if (campaignId && [self.campaignIdsImpressedWithoutClick containsObject:campaignId]) {
        trackInAppClicked = YES;
        [self.campaignIdsImpressedWithoutClick removeObject:campaignId];
    }

    if ([WonderPush subscriptionStatusIsOptIn]) {
        if (trackInAppClicked) {
            [WonderPush trackInternalEvent:@"@INAPP_CLICKED" eventData:[NSDictionary dictionaryWithDictionary:eventData] customData:nil];
        }
        [WonderPush trackInternalEvent:@"@INAPP_ITEM_CLICKED" eventData:[NSDictionary dictionaryWithDictionary:eventData] customData:nil];
    } else {
        if (trackInAppClicked) {
            [WonderPush countInternalEvent:@"@INAPP_CLICKED" eventData:[NSDictionary dictionaryWithDictionary:eventData] customData:nil];
        }
        [WonderPush countInternalEvent:@"@INAPP_ITEM_CLICKED" eventData:[NSDictionary dictionaryWithDictionary:eventData] customData:nil];
    }
}

- (void)messageClicked:(WPInAppMessagingDisplayMessage *)inAppMessage
            withAction:(WPAction *)action {
    // Call through to app-side delegate.
    __weak id<WPInAppMessagingDisplayDelegate> appSideDelegate = self.inAppMessaging.delegate;
    if ([appSideDelegate respondsToSelector:@selector(messageClicked:withAction:)]) {
        [appSideDelegate messageClicked:inAppMessage withAction:action];
    }
    self.isMsgBeingDisplayed = NO;
    NSString *buttonLabel = nil;
    if (action.targetUrl || action.followUps.count) {
        if ([inAppMessage respondsToSelector:@selector(action)]) {
            buttonLabel = [inAppMessage performSelector:@selector(action)] == (id)action ? @"primary" : nil;
        } else if ([inAppMessage respondsToSelector:@selector(primaryAction)]) {
            buttonLabel = [inAppMessage performSelector:@selector(primaryAction)] == (id)action ? @"primary" : nil;
        }
        if (!buttonLabel && [inAppMessage respondsToSelector:@selector(secondaryAction)]) {
            buttonLabel = [inAppMessage performSelector:@selector(secondaryAction)] == (id)action ? @"secondary" : nil;
        }
    }
    if (action) {
        // Record @INAPP_CLICKED
        [self trackClickWithMessage:inAppMessage buttonLabel:buttonLabel];
        // Exec action
        [WonderPush executeAction:action withReportingData:_currentMsgBeingDisplayed.renderData.reportingData attributionReason:WPReportingAttributionReasonInAppViewed];
    }
}

- (void)messageDismissed:(WPInAppMessagingDisplayMessage *)inAppMessage
             dismissType:(WPInAppMessagingDismissType)dismissType {
    // Call through to app-side delegate.
    __weak id<WPInAppMessagingDisplayDelegate> appSideDelegate = self.inAppMessaging.delegate;
    if ([appSideDelegate respondsToSelector:@selector(messageDismissed:dismissType:)]) {
        [appSideDelegate messageDismissed:inAppMessage dismissType:dismissType];
    }
    
    self.isMsgBeingDisplayed = NO;
    if (!_currentMsgBeingDisplayed.renderData.reportingData.campaignId) {
        WPLog(@"messageDismissedWithType called but there is no current message ID.");
        return;
    }
    
    if (_currentMsgBeingDisplayed.isTestMessage) {
        WPLogDebug(@"A test message dismissed. Record the impression event.");
        return;
    }
    
    // Logging the impression
    [self recordValidImpression:_currentMsgBeingDisplayed.renderData.reportingData];
    
    if (_currentMsgBeingDisplayed.renderData.reportingData.campaignId) {
        [self.campaignIdsImpressedWithoutClick removeObject:_currentMsgBeingDisplayed.renderData.reportingData.campaignId];
    }

}

- (void)impressionDetectedForMessage:(WPInAppMessagingDisplayMessage *)inAppMessage {
    __weak id<WPInAppMessagingDisplayDelegate> appSideDelegate = self.inAppMessaging.delegate;
    if ([appSideDelegate respondsToSelector:@selector(impressionDetectedForMessage:)]) {
        [appSideDelegate impressionDetectedForMessage:inAppMessage];
    }
    
    if (!_currentMsgBeingDisplayed.renderData.reportingData.campaignId) {
        WPLog(
                      @"impressionDetected called but "
                      "there is no current message ID.");
        return;
    }
    
    if (!_currentMsgBeingDisplayed.isTestMessage) {
        // Displayed long enough to be a valid impression.
        [self recordValidImpression:_currentMsgBeingDisplayed.renderData.reportingData];
    } else {
        WPLogDebug(
                    @"A test message. Record the test message impression event.");
        return;
    }
}

- (void)displayErrorForMessage:(WPInAppMessagingDisplayMessage *)inAppMessage
                         error:(NSError *)error {
    __weak id<WPInAppMessagingDisplayDelegate> appSideDelegate = self.inAppMessaging.delegate;
    if ([appSideDelegate respondsToSelector:@selector(displayErrorForMessage:error:)]) {
        [appSideDelegate displayErrorForMessage:inAppMessage error:error];
    }
    
    self.isMsgBeingDisplayed = NO;
    
    if (!_currentMsgBeingDisplayed.renderData.reportingData.campaignId) {
        WPLog(
                      @"displayErrorEncountered called but "
                      "there is no current message ID.");
        return;
    }
    
    NSString *campaignId = _currentMsgBeingDisplayed.renderData.reportingData.campaignId;
    
    WPLogDebug(@"Display ran into error for message %@: %@", campaignId, error);
    
    if (_currentMsgBeingDisplayed.isTestMessage) {
        [self displayMessageLoadError:error];
        WPLogDebug(
                    @"A test message. No analytics tracking "
                    "from image data loading failure");
        return;
    }
    
    if (campaignId) {
        [self.campaignIdsImpressedWithoutClick removeObject:campaignId];
    }

    // we remove the message from the client side cache so that it won't be retried until next time
    // it's fetched again from server.
    [self.messageCache removeMessagesWithCampaignId:campaignId];
}

- (void)recordValidImpression:(WPReportingData *)reportingData {
    if (!self.impressionRecorded) {
        self.displayBookKeeper.lastRateLimitedInAppDisplayTime = self.lastRateLimitedInAppDisplayTime;
        [self.displayBookKeeper recordNewImpressionForReportingData:reportingData
                                        withStartTimestampInSeconds:self.lastInAppDisplayTime];
        self.impressionRecorded = YES;
        if (reportingData.campaignId) {
            [self.campaignIdsImpressedWithoutClick addObject:reportingData.campaignId];
        }
    }
}

- (void)displayMessageLoadError:(NSError *)error {
    NSString *errorMsg = error.userInfo[NSLocalizedDescriptionKey]
    ? error.userInfo[NSLocalizedDescriptionKey]
    : @"Message loading failed";
    UIAlertController *alert = [UIAlertController
                                alertControllerWithTitle:@"InAppMessaging fail to load a test message"
                                message:errorMsg
                                preferredStyle:UIAlertControllerStyleAlert];
    
    UIAlertAction *defaultAction = [UIAlertAction actionWithTitle:@"OK"
                                                            style:UIAlertActionStyleDefault
                                                          handler:^(UIAlertAction *action) {
        self.alertWindow.hidden = NO;
        self.alertWindow = nil;
    }];
    
    [alert addAction:defaultAction];
    
    dispatch_async(dispatch_get_main_queue(), ^{
#if defined(__IPHONE_13_0) && __IPHONE_OS_VERSION_MAX_ALLOWED >= 130000
        if (@available(iOS 13.0, *)) {
            UIWindowScene *foregroundedScene = nil;
            for (UIWindowScene *connectedScene in [UIApplication sharedApplication].connectedScenes) {
                if (connectedScene.activationState == UISceneActivationStateForegroundActive) {
                    foregroundedScene = connectedScene;
                    break;
                }
            }
            
            if (foregroundedScene == nil) {
                return;
            }
            self.alertWindow = [[UIWindow alloc] initWithWindowScene:foregroundedScene];
        }
#else  // defined(__IPHONE_13_0) && __IPHONE_OS_VERSION_MAX_ALLOWED >= 130000
        self.alertWindow = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
#endif
        UIViewController *alertViewController = [[UIViewController alloc] init];
        self.alertWindow.rootViewController = alertViewController;
        self.alertWindow.hidden = NO;
        [alertViewController presentViewController:alert animated:YES completion:nil];
    });
}

- (void)trackEvent:(NSString *)type attributes:(NSDictionary *)attributes {
    WPReportingData *reportingData = _currentMsgBeingDisplayed.renderData.reportingData;
    [WonderPush trackInAppEvent:type eventData:[reportingData filledEventData:@{} attributionReason:WPReportingAttributionReasonInAppViewed] customData:attributes];
}

- (instancetype)initWithInAppMessaging:(WPInAppMessaging *)inAppMessaging
                               setting:(WPIAMDisplaySetting *)setting
                          messageCache:(WPIAMMessageClientCache *)cache
                           timeFetcher:(id<WPIAMTimeFetcher>)timeFetcher
                            bookKeeper:(id<WPIAMBookKeeper>)displayBookKeeper {
    if (self = [super init]) {
        _inAppMessaging = inAppMessaging;
        _timeFetcher = timeFetcher;
        _lastRateLimitedInAppDisplayTime = displayBookKeeper.lastRateLimitedInAppDisplayTime;
        _lastInAppDisplayTime = 0;
        _setting = setting;
        _messageCache = cache;
        _displayBookKeeper = displayBookKeeper;
        _isMsgBeingDisplayed = NO;
        _suppressMessageDisplay = NO;  // always allow message display on startup
        _campaignIdsImpressedWithoutClick = [NSMutableSet new];
    }
    return self;
}

- (void)checkAndDisplayNextContextualMessageForWonderPushEvent:(NSString *)eventName allTimeOccurrences:(NSInteger)allTimeOccurrences {
    // synchronizing on self so that we won't potentially enter the render flow from two
    // threads: example like showing analytics triggered message and a regular app open
    // triggered message
    @synchronized(self) {
        if (self.suppressMessageDisplay) {
            WPLogDebug(
                        @"Message display is being suppressed. No contextual message rendering.");
            return;
        }
        
        if (!self.messageDisplayComponent) {
            WPLogDebug(
                        @"Message display component is not present yet. No display should happen.");
            return;
        }
        
        if (self.isMsgBeingDisplayed) {
//            WPLogDebug(@"An in-app message display is in progress, do not check analytics event based message for now.");
            return;
        }
        
        // Pop up next analytics event based message to be displayed
        WPIAMMessageDefinition *nextAnalyticsBasedMessage =
        [self.messageCache nextOnEventDisplayMsg:eventName allTimeOccurrences:allTimeOccurrences];
        
        if (nextAnalyticsBasedMessage) {
            NSTimeInterval now = [self.timeFetcher currentTimestampInSeconds];
            self.lastInAppDisplayTime = now;
            [self displayMessage:nextAnalyticsBasedMessage
                        triggerType:WPInAppMessagingDisplayTriggerTypeOnWonderPushEvent
                              delay:[nextAnalyticsBasedMessage delayForTrigger:WPIAMRenderTriggerOnWonderPushEvent]];
        }
    }
}

- (WPInAppMessagingCardDisplay *)
    cardDisplayMessageWithMessageDefinition:(WPIAMMessageDefinition *)definition
                          portraitImageData:(nonnull WPInAppMessagingImageData *)portraitImageData
                         landscapeImageData:(nullable WPInAppMessagingImageData *)landscapeImageData
                                triggerType:(WPInAppMessagingDisplayTriggerType)triggerType {
    // For easier reference in this method.
    WPIAMMessageRenderData *renderData = definition.renderData;
    
    NSString *title = renderData.contentData.titleText;
    NSString *body = renderData.contentData.bodyText;
    WPInAppMessagingEntryAnimation entryAnimation = [self.class convertEntryAnimation:definition.renderData.contentData.entryAnimation];
    WPInAppMessagingExitAnimation exitAnimation = [self.class convertExitAnimation:definition.renderData.contentData.exitAnimation];

    // Action button data is never nil for a card message.
    WPInAppMessagingActionButton *primaryActionButton = [[WPInAppMessagingActionButton alloc]
                                                          initWithButtonText:renderData.contentData.actionButtonText
                                                          buttonTextColor:renderData.renderingEffectSettings.btnTextColor
                                                          backgroundColor:renderData.renderingEffectSettings.btnBGColor];
    
    
    WPInAppMessagingActionButton *secondaryActionButton = nil;
    if (definition.renderData.contentData.secondaryActionButtonText) {
        secondaryActionButton = [[WPInAppMessagingActionButton alloc]
                                 initWithButtonText:renderData.contentData.secondaryActionButtonText
                                 buttonTextColor:renderData.renderingEffectSettings.secondaryActionBtnTextColor
                                 backgroundColor:renderData.renderingEffectSettings.secondaryActionBtnBGColor];
    }
    
    WPInAppMessagingCardDisplay *cardMessage = [[WPInAppMessagingCardDisplay alloc]
                                                initWithTriggerType:triggerType
                                                payload:definition.payload
                                                titleText:title
                                                textColor:renderData.renderingEffectSettings.textColor
                                                portraitImageData:portraitImageData
                                                backgroundColor:renderData.renderingEffectSettings.displayBGColor
                                                entryAnimation:entryAnimation
                                                exitAnimation:exitAnimation
                                                primaryActionButton:primaryActionButton
                                                primaryAction:definition.renderData.contentData.action];
    
    cardMessage.body = body;
    cardMessage.landscapeImageData = landscapeImageData;
    cardMessage.secondaryActionButton = secondaryActionButton;
    cardMessage.secondaryAction = definition.renderData.contentData.secondaryAction;
    
    return cardMessage;
}

- (WPInAppMessagingBannerDisplay *)
    bannerDisplayMessageWithMessageDefinition:(WPIAMMessageDefinition *)definition
                                    imageData:(WPInAppMessagingImageData *)imageData
                                  triggerType:(WPInAppMessagingDisplayTriggerType)triggerType {
    NSString *title = definition.renderData.contentData.titleText;
    NSString *body = definition.renderData.contentData.bodyText;
    WPInAppMessagingBannerPosition bannerPosition;
    switch (definition.renderData.contentData.bannerPosition) {
        case WPIAMBannerPositionTop:
            bannerPosition = WPInAppMessagingBannerPositionTop;
            break;
        case WPIAMBannerPositionBottom:
            bannerPosition = WPInAppMessagingBannerPositionBottom;
            break;
    }
    WPInAppMessagingEntryAnimation entryAnimation = [self.class convertEntryAnimation:definition.renderData.contentData.entryAnimation];
    WPInAppMessagingExitAnimation exitAnimation = [self.class convertExitAnimation:definition.renderData.contentData.exitAnimation];

    WPInAppMessagingBannerDisplay *bannerMessage = [[WPInAppMessagingBannerDisplay alloc]
                                                    initWithTriggerType:triggerType
                                                    payload:definition.payload
                                                    titleText:title
                                                    bodyText:body
                                                    textColor:definition.renderData.renderingEffectSettings.textColor
                                                    backgroundColor:definition.renderData.renderingEffectSettings.displayBGColor
                                                    imageData:imageData
                                                    bannerPosition:bannerPosition
                                                    entryAnimation:entryAnimation
                                                     exitAnimation:exitAnimation
                                                    action:definition.renderData.contentData.action];
    
    return bannerMessage;
}

- (WPInAppMessagingImageOnlyDisplay *)
    imageOnlyDisplayMessageWithMessageDefinition:(WPIAMMessageDefinition *)definition
                                       imageData:(WPInAppMessagingImageData *)imageData
                                     triggerType:(WPInAppMessagingDisplayTriggerType)triggerType {
    WPInAppMessagingCloseButtonPosition closeButtonPosition;
    switch (definition.renderData.contentData.closeButtonPosition) {
        case WPInAppMessagingCloseButtonPositionOutside:
            closeButtonPosition = WPInAppMessagingCloseButtonPositionOutside;
            break;
        case WPInAppMessagingCloseButtonPositionInside:
            closeButtonPosition = WPInAppMessagingCloseButtonPositionInside;
            break;
        case WPInAppMessagingCloseButtonPositionNone:
            closeButtonPosition = WPInAppMessagingCloseButtonPositionNone;
            break;
    }
    WPInAppMessagingEntryAnimation entryAnimation = [self.class convertEntryAnimation:definition.renderData.contentData.entryAnimation];
    WPInAppMessagingExitAnimation exitAnimation = [self.class convertExitAnimation:definition.renderData.contentData.exitAnimation];

    WPInAppMessagingImageOnlyDisplay *imageOnlyMessage = [[WPInAppMessagingImageOnlyDisplay alloc]
                                                          initWithTriggerType:triggerType
                                                          payload:definition.payload
                                                          imageData:imageData
                                                          entryAnimation:entryAnimation
                                                          exitAnimation:exitAnimation
                                                          action:definition.renderData.contentData.action
                                                          closeButtonPosition:closeButtonPosition];
    
    return imageOnlyMessage;
}

- (WPInAppMessagingWebViewDisplay *)
    webViewDisplayMessageWithMessageDefinition:(WPIAMMessageDefinition *)definition
                                       webView:(WKWebView *)webView
                                     triggerType:(WPInAppMessagingDisplayTriggerType)triggerType {
    WPInAppMessagingCloseButtonPosition closeButtonPosition;
    switch (definition.renderData.contentData.closeButtonPosition) {
        case WPInAppMessagingCloseButtonPositionNone:
            closeButtonPosition = WPInAppMessagingCloseButtonPositionNone;
            break;
        case WPInAppMessagingCloseButtonPositionInside:
        default:
            closeButtonPosition = WPInAppMessagingCloseButtonPositionInside;
            break;
    }
    WPInAppMessagingEntryAnimation entryAnimation = [self.class convertEntryAnimation:definition.renderData.contentData.entryAnimation];
    WPInAppMessagingExitAnimation exitAnimation = [self.class convertExitAnimation:definition.renderData.contentData.exitAnimation];

    WPInAppMessagingWebViewDisplay *webViewMessage = [[WPInAppMessagingWebViewDisplay alloc]
                                                          initWithTriggerType:triggerType
                                                          payload:definition.payload
                                                          webView:webView
                                                          entryAnimation:entryAnimation
                                                          exitAnimation:exitAnimation
                                                          action:definition.renderData.contentData.action
                                                          closeButtonPosition:closeButtonPosition];
    return webViewMessage;
}

- (WPInAppMessagingModalDisplay *)
    modalDisplayMessageWithMessageDefinition:(WPIAMMessageDefinition *)definition
                                   imageData:(WPInAppMessagingImageData *)imageData
                                 triggerType:(WPInAppMessagingDisplayTriggerType)triggerType {
    // For easier reference in this method.
    WPIAMMessageRenderData *renderData = definition.renderData;
    
    NSString *title = renderData.contentData.titleText;
    NSString *body = renderData.contentData.bodyText;
    WPInAppMessagingEntryAnimation entryAnimation = [self.class convertEntryAnimation:definition.renderData.contentData.entryAnimation];
    WPInAppMessagingExitAnimation exitAnimation = [self.class convertExitAnimation:definition.renderData.contentData.exitAnimation];

    WPInAppMessagingActionButton *actionButton = nil;
    
    if (definition.renderData.contentData.actionButtonText) {
        actionButton = [[WPInAppMessagingActionButton alloc]
                        initWithButtonText:renderData.contentData.actionButtonText
                        buttonTextColor:renderData.renderingEffectSettings.btnTextColor
                        backgroundColor:renderData.renderingEffectSettings.btnBGColor];
    }
    
    WPInAppMessagingCloseButtonPosition closeButtonPosition;
    switch (definition.renderData.contentData.closeButtonPosition) {
        case WPInAppMessagingCloseButtonPositionOutside:
            closeButtonPosition = WPInAppMessagingCloseButtonPositionOutside;
            break;
        case WPInAppMessagingCloseButtonPositionInside:
            closeButtonPosition = WPInAppMessagingCloseButtonPositionInside;
            break;
        case WPInAppMessagingCloseButtonPositionNone:
            closeButtonPosition = WPInAppMessagingCloseButtonPositionNone;
            break;
    }

    WPInAppMessagingModalDisplay *modalViewMessage = [[WPInAppMessagingModalDisplay alloc]
                                                      initWithTriggerType:triggerType
                                                      payload:definition.payload
                                                      titleText:title
                                                      bodyText:body
                                                      textColor:renderData.renderingEffectSettings.textColor
                                                      backgroundColor:renderData.renderingEffectSettings.displayBGColor
                                                      imageData:imageData
                                                      entryAnimation:entryAnimation
                                                      exitAnimation:exitAnimation
                                                      actionButton:actionButton
                                                      action:definition.renderData.contentData.action
                                                      closeButtonPosition:closeButtonPosition];
    
    return modalViewMessage;
}

- (WPInAppMessagingDisplayMessage *)
    displayMessageWithMessageDefinition:(WPIAMMessageDefinition *)definition
                              imageData:(nullable WPInAppMessagingImageData *)imageData
                     landscapeImageData:(nullable WPInAppMessagingImageData *)landscapeImageData
                                webView:(nullable WKWebView *)webView
                            triggerType:(WPInAppMessagingDisplayTriggerType)triggerType {
    switch (definition.renderData.renderingEffectSettings.viewMode) {
        case WPIAMRenderAsCardView:
            // Image data should never nil for a valid card message.
            if (imageData == nil) {
                return nil;
            }
            return [self cardDisplayMessageWithMessageDefinition:definition
                                               portraitImageData:imageData
                                              landscapeImageData:landscapeImageData
                                                     triggerType:triggerType];
        case WPIAMRenderAsBannerView:
            return [self bannerDisplayMessageWithMessageDefinition:definition
                                                         imageData:imageData
                                                       triggerType:triggerType];
        case WPIAMRenderAsModalView:
            return [self modalDisplayMessageWithMessageDefinition:definition
                                                        imageData:imageData
                                                      triggerType:triggerType];
        case WPIAMRenderAsImageOnlyView:
            return [self imageOnlyDisplayMessageWithMessageDefinition:definition
                                                            imageData:imageData
                                                          triggerType:triggerType];
        case WPIAMRenderAsWebView:
            return [self webViewDisplayMessageWithMessageDefinition:definition
                                                            webView:webView
                                                        triggerType:triggerType];
        default:
            return nil;
    }
}

- (void)displayMessage:(WPIAMMessageDefinition *)message
              triggerType:(WPInAppMessagingDisplayTriggerType)triggerType
                    delay:(NSTimeInterval)delay {
    _currentMsgBeingDisplayed = message;
    self.isMsgBeingDisplayed = YES;
    WPIAMTimerWithNSDate *timeProvider = [WPIAMTimerWithNSDate new];
    NSTimeInterval originalDisplayTime = [timeProvider currentTimestampInSeconds];
    [message.renderData.contentData
     loadMedia:^(NSData *_Nullable standardImageRawData,
                 NSData *_Nullable landscapeImageRawData,
                 WKWebView *_Nullable webView,
                 NSError *_Nullable error) {
        WPInAppMessagingImageData *imageData = nil;
        WPInAppMessagingImageData *landscapeImageData = nil;
        
        if (error) {
            WPLogDebug(
                        @"Error in loading media for the message.");
            
            WPInAppMessagingDisplayMessage *erroredMessage =
            [self displayMessageWithMessageDefinition:message
                                            imageData:imageData
                                   landscapeImageData:landscapeImageData
                                               webView:webView
                                          triggerType:triggerType];
            // short-circuit to display error handling
            [self displayErrorForMessage:erroredMessage error:error];
            return;
        } else {
            if (standardImageRawData) {
                imageData = [[WPInAppMessagingImageData alloc]
                             initWithImageURL:message.renderData.contentData.imageURL.absoluteString
                             imageData:standardImageRawData];
            }
            if (landscapeImageRawData) {
                landscapeImageData = [[WPInAppMessagingImageData alloc]
                                      initWithImageURL:message.renderData.contentData.landscapeImageURL.absoluteString
                                      imageData:landscapeImageRawData];
            }
        }
        
        self.impressionRecorded = NO;
        
        WPInAppMessagingDisplayMessage *displayMessage =
        [self displayMessageWithMessageDefinition:message
                                        imageData:imageData
                               landscapeImageData:landscapeImageData
                                           webView:webView
                                      triggerType:triggerType];
        NSTimeInterval delayLeft = delay + originalDisplayTime - [timeProvider currentTimestampInSeconds];
        if (delayLeft > 0) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayLeft * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                BOOL handled = [self.messageDisplayComponent displayMessage:displayMessage displayDelegate:self];
                if (!handled) {
                    [WPIAMDefaultDisplayImpl.instance displayMessage:displayMessage displayDelegate:self];
                }
            });
        } else {
            BOOL handled = [self.messageDisplayComponent displayMessage:displayMessage displayDelegate:self];
            if (!handled) {
                [WPIAMDefaultDisplayImpl.instance displayMessage:displayMessage displayDelegate:self];
            }
        }
    }];
}

- (BOOL)enoughIntervalFromLastDisplay {
    NSTimeInterval intervalFromLastDisplayInSeconds =
    [self.timeFetcher currentTimestampInSeconds] - self.lastRateLimitedInAppDisplayTime;
    
    WPLogDebug(
                @"Interval time from last display is %lf seconds", intervalFromLastDisplayInSeconds);
    
    return intervalFromLastDisplayInSeconds >= self.setting.displayMinIntervalInMinutes * 60.0;
}

- (void)checkAndDisplayNextAppLaunchMessage {
    // synchronizing on self so that we won't potentially enter the render flow from two
    // threads.
    @synchronized(self) {
        if (!self.messageDisplayComponent) {
            WPLogDebug(
                        @"Message display component is not present yet. No display should happen.");
            return;
        }
        
        if (self.suppressMessageDisplay) {
            WPLogDebug(
                        @"Message display is being suppressed. No regular message rendering.");
            return;
        }
        
        if (self.isMsgBeingDisplayed) {
            WPLogDebug(
                        @"An in-app message display is in progress, do not over-display on top of it.");
            return;
        }
        
        if ([self.messageCache hasTestMessage] || [self enoughIntervalFromLastDisplay]) {
            // We can display test messages anytime or display regular messages when
            // the display time interval has been reached
            WPIAMMessageDefinition *nextAppLaunchMessage = [self.messageCache nextOnAppLaunchDisplayMsg];
            
            if (nextAppLaunchMessage) {
                NSTimeInterval now = [self.timeFetcher currentTimestampInSeconds];
                self.lastInAppDisplayTime = now;
                self.lastRateLimitedInAppDisplayTime = now;
                [self displayMessage:nextAppLaunchMessage
                            triggerType:WPInAppMessagingDisplayTriggerTypeOnAppForeground
                                  delay:[nextAppLaunchMessage delayForTrigger:WPIAMRenderTriggerOnAppLaunch]];
            } else {
                WPLogDebug(
                            @"No appropriate in-app message detected for display.");
            }
        } else {
            WPLogDebug(
                        @"Minimal display interval of %lf seconds has not been reached yet.",
                        self.setting.displayMinIntervalInMinutes * 60.0);
        }
    }
}

- (void)checkAndDisplayNextAppForegroundMessage {
    // synchronizing on self so that we won't potentially enter the render flow from two
    // threads: example like showing analytics triggered message and a regular app open
    // triggered message concurrently
    @synchronized(self) {
        if (!self.messageDisplayComponent) {
            WPLogDebug(
                        @"Message display component is not present yet. No display should happen.");
            return;
        }
        
        if (self.suppressMessageDisplay) {
            WPLogDebug(
                        @"Message display is being suppressed. No regular message rendering.");
            return;
        }
        
        if (self.isMsgBeingDisplayed) {
            WPLogDebug(
                        @"An in-app message display is in progress, do not over-display on top of it.");
            return;
        }
        
        if ([self.messageCache hasTestMessage] || [self enoughIntervalFromLastDisplay]) {
            // We can display test messages anytime or display regular messages when
            // the display time interval has been reached
            WPIAMMessageDefinition *nextForegroundMessage = [self.messageCache nextOnAppOpenDisplayMsg];
            
            if (nextForegroundMessage) {
                NSTimeInterval now = [self.timeFetcher currentTimestampInSeconds];
                self.lastInAppDisplayTime = now;
                self.lastRateLimitedInAppDisplayTime = now;
                [self displayMessage:nextForegroundMessage
                            triggerType:WPInAppMessagingDisplayTriggerTypeOnAppForeground
                                  delay:[nextForegroundMessage delayForTrigger:WPIAMRenderTriggerOnAppForeground]];
            } else {
                WPLogDebug(
                            @"No appropriate in-app message detected for display.");
            }
        } else {
            WPLogDebug(
                        @"Minimal display interval of %lf seconds has not been reached yet.",
                        self.setting.displayMinIntervalInMinutes * 60.0);
        }
    }
}
@end

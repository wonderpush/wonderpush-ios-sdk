/*
 * Copyright 2018 Google
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

#import <Foundation/Foundation.h>

#import <WonderPush/WPInAppMessaging.h>
#import <WonderPush/WPInAppMessagingRendering.h>
#import "WPCore+InAppMessagingDisplay.h"
#import "WPIAMBannerViewController.h"
#import "WPIAMCardViewController.h"
#import "WPIAMDefaultDisplayImpl.h"
#import "WPIAMImageOnlyViewController.h"
#import "WPIAMWebViewViewController.h"
#import "WPIAMModalViewController.h"
#import "WPIAMRenderingWindowHelper.h"
#import "WPIAMTimeFetcher.h"
#import "WonderPush_private.h"

static WPIAMDefaultDisplayImpl *instance = nil;
@implementation WPIAMDefaultDisplayImpl

+ (instancetype) instance {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [WPIAMDefaultDisplayImpl new];
    });
    return instance;
}

+ (void)load {
    [self didReceiveConfigureSDKNotification:nil];
}

+ (void)didReceiveConfigureSDKNotification:(NSNotification *)notification {
    WPLogDebug(
                @"Got notification for kWPAppReadyToConfigureSDKNotification. Setting display "
                "component on headless SDK.");
    
    WPIAMDefaultDisplayImpl *display = [WPIAMDefaultDisplayImpl instance];
    [WPInAppMessaging inAppMessaging].messageDisplayComponent = display;
}

+ (NSBundle *)getViewResourceBundle {
    return [WonderPush resourceBundle];
}

+ (void)displayCardViewWithMessageDefinition:(WPInAppMessagingCardDisplay *)cardMessage
                             controllerDelegate:(id<WPInAppMessagingControllerDelegate>)controllerDelegate {
    dispatch_async(dispatch_get_main_queue(), ^{

        if (UIApplication.sharedApplication.applicationState != UIApplicationStateActive) {
            WPLog(@"UIApplication not active when time has come to show message %@.", cardMessage);
            [controllerDelegate displayErrorForMessage:cardMessage error:[self applicationNotActiveError]];
            return;
        }

        NSBundle *resourceBundle = [self getViewResourceBundle];
        
        if (resourceBundle == nil) {
            NSError *error =
            [NSError errorWithDomain:kInAppMessagingDisplayErrorDomain
                                code:IAMDisplayRenderErrorTypeUnspecifiedError
                            userInfo:@{NSLocalizedDescriptionKey : @"Resource bundle is missing."}];
            [controllerDelegate displayErrorForMessage:cardMessage error:error];
            return;
        }
        
        WPIAMTimerWithNSDate *timeFetcher = [[WPIAMTimerWithNSDate alloc] init];
        WPIAMCardViewController *cardVC =
        [WPIAMCardViewController instantiateViewControllerWithResourceBundle:resourceBundle
                                                               displayMessage:cardMessage
                                                              controllerDelegate:controllerDelegate
                                                                  timeFetcher:timeFetcher];
        
        if (cardVC == nil) {
            WPLog(
                          @"View controller can not be created.");
            NSError *error = [NSError
                              errorWithDomain:kInAppMessagingDisplayErrorDomain
                              code:IAMDisplayRenderErrorTypeUnspecifiedError
                              userInfo:@{NSLocalizedDescriptionKey : @"View controller could not be created"}];
            [controllerDelegate displayErrorForMessage:cardMessage error:error];
            return;
        }
        
        UIWindow *displayUIWindow = [WPIAMRenderingWindowHelper UIWindowForModalView];
        displayUIWindow.rootViewController = cardVC;
        [displayUIWindow setHidden:NO];
    });
}

+ (void)displayModalViewWithMessageDefinition:(WPInAppMessagingModalDisplay *)modalMessage
                              controllerDelegate:
(id<WPInAppMessagingControllerDelegate>)controllerDelegate {
    dispatch_async(dispatch_get_main_queue(), ^{

        if (UIApplication.sharedApplication.applicationState != UIApplicationStateActive) {
            WPLog(@"UIApplication not active when time has come to show message %@.", modalMessage);
            [controllerDelegate displayErrorForMessage:modalMessage error:[self applicationNotActiveError]];
            return;
        }

        NSBundle *resourceBundle = [self getViewResourceBundle];
        
        if (resourceBundle == nil) {
            NSError *error = [NSError errorWithDomain:kInAppMessagingDisplayErrorDomain
                                                 code:IAMDisplayRenderErrorTypeUnspecifiedError
                                             userInfo:@{@"message" : @"resource bundle is missing"}];
            [controllerDelegate displayErrorForMessage:modalMessage error:error];
            return;
        }
        
        WPIAMTimerWithNSDate *timeFetcher = [[WPIAMTimerWithNSDate alloc] init];
        WPIAMModalViewController *modalVC =
        [WPIAMModalViewController instantiateViewControllerWithResourceBundle:resourceBundle
                                                                displayMessage:modalMessage
                                                               controllerDelegate:controllerDelegate
                                                                   timeFetcher:timeFetcher];
        
        if (modalVC == nil) {
            WPLog(
                          @"View controller can not be created.");
            NSError *error = [NSError errorWithDomain:kInAppMessagingDisplayErrorDomain
                                                 code:IAMDisplayRenderErrorTypeUnspecifiedError
                                             userInfo:@{}];
            [controllerDelegate displayErrorForMessage:modalMessage error:error];
            return;
        }
        
        UIWindow *displayUIWindow = [WPIAMRenderingWindowHelper UIWindowForModalView];
        displayUIWindow.rootViewController = modalVC;
        [displayUIWindow setHidden:NO];
    });
}

+ (void)displayBannerViewWithMessageDefinition:(WPInAppMessagingBannerDisplay *)bannerMessage
                               controllerDelegate:
(id<WPInAppMessagingControllerDelegate>)controllerDelegate {
    dispatch_async(dispatch_get_main_queue(), ^{

        if (UIApplication.sharedApplication.applicationState != UIApplicationStateActive) {
            WPLog(@"UIApplication not active when time has come to show message %@.", bannerMessage);
            [controllerDelegate displayErrorForMessage:bannerMessage error:[self applicationNotActiveError]];
            return;
        }

        NSBundle *resourceBundle = [self getViewResourceBundle];
        
        if (resourceBundle == nil) {
            NSError *error = [NSError errorWithDomain:kInAppMessagingDisplayErrorDomain
                                                 code:IAMDisplayRenderErrorTypeUnspecifiedError
                                             userInfo:@{}];
            [controllerDelegate displayErrorForMessage:bannerMessage error:error];
            return;
        }
        
        WPIAMTimerWithNSDate *timeFetcher = [[WPIAMTimerWithNSDate alloc] init];
        WPIAMBannerViewController *bannerVC =
        [WPIAMBannerViewController instantiateViewControllerWithResourceBundle:resourceBundle
                                                                 displayMessage:bannerMessage
                                                                controllerDelegate:controllerDelegate
                                                                    timeFetcher:timeFetcher];
        
        if (bannerVC == nil) {
            WPLog(
                          @"Banner view controller can not be created.");
            NSError *error = [NSError errorWithDomain:kInAppMessagingDisplayErrorDomain
                                                 code:IAMDisplayRenderErrorTypeUnspecifiedError
                                             userInfo:@{}];
            [controllerDelegate displayErrorForMessage:bannerMessage error:error];
            return;
        }
        
        UIWindow *displayUIWindow = [WPIAMRenderingWindowHelper UIWindowForBannerView];
        displayUIWindow.rootViewController = bannerVC;
        [displayUIWindow setHidden:NO];
    });
}

+ (void)displayImageOnlyViewWithMessageDefinition:
(WPInAppMessagingImageOnlyDisplay *)imageOnlyMessage
                                  controllerDelegate:
(id<WPInAppMessagingControllerDelegate>)controllerDelegate {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (UIApplication.sharedApplication.applicationState != UIApplicationStateActive) {
            WPLog(@"UIApplication not active when time has come to show message %@.", imageOnlyMessage);
            [controllerDelegate displayErrorForMessage:imageOnlyMessage error:[self applicationNotActiveError]];
            return;
        }
        NSBundle *resourceBundle = [self getViewResourceBundle];
        
        if (resourceBundle == nil) {
            NSError *error = [NSError errorWithDomain:kInAppMessagingDisplayErrorDomain
                                                 code:IAMDisplayRenderErrorTypeUnspecifiedError
                                             userInfo:@{}];
            [controllerDelegate displayErrorForMessage:imageOnlyMessage error:error];
            return;
        }
        
        WPIAMTimerWithNSDate *timeFetcher = [[WPIAMTimerWithNSDate alloc] init];
        WPIAMImageOnlyViewController *imageOnlyVC =
        [WPIAMImageOnlyViewController instantiateViewControllerWithResourceBundle:resourceBundle
                                                                    displayMessage:imageOnlyMessage
                                                                   controllerDelegate:controllerDelegate
                                                                       timeFetcher:timeFetcher];
        
        if (imageOnlyVC == nil) {
            WPLog(
                          @"Image only view controller can not be created.");
            NSError *error = [NSError errorWithDomain:kInAppMessagingDisplayErrorDomain
                                                 code:IAMDisplayRenderErrorTypeUnspecifiedError
                                             userInfo:@{}];
            [controllerDelegate displayErrorForMessage:imageOnlyMessage error:error];
            return;
        }
        
        UIWindow *displayUIWindow = [WPIAMRenderingWindowHelper UIWindowForImageOnlyView];
        displayUIWindow.rootViewController = imageOnlyVC;
        [displayUIWindow setHidden:NO];
    });
}

+ (void)displayWebViewViewWithMessageDefinition:
(WPInAppMessagingWebViewDisplay *)webViewMessage
                                  controllerDelegate:
(id<WPInAppMessagingControllerDelegate>)controllerDelegate {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (UIApplication.sharedApplication.applicationState != UIApplicationStateActive) {
            WPLogDebug(@"UIApplication not active when time has come to show message %@.", webViewMessage);
            [controllerDelegate displayErrorForMessage:webViewMessage error:[self applicationNotActiveError]];
            return;
        }
        if (!webViewMessage.webView) {
            WPLogDebug(@"Message misses its webView %@.", webViewMessage);
            [controllerDelegate
             displayErrorForMessage:webViewMessage
             error:[NSError errorWithDomain:kInAppMessagingDisplayErrorDomain
                                       code:IAMDisplayRenderErrorTypeWebUrlFailedToLoad
                                   userInfo:@{}]];
            return;

        }

        NSBundle *resourceBundle = [self getViewResourceBundle];
        if (resourceBundle == nil) {
            NSError *error = [NSError errorWithDomain:kInAppMessagingDisplayErrorDomain
                                                 code:IAMDisplayRenderErrorTypeUnspecifiedError
                                             userInfo:@{}];
            [controllerDelegate displayErrorForMessage:webViewMessage error:error];
            return;
        }

        WPIAMTimerWithNSDate *timeFetcher = [[WPIAMTimerWithNSDate alloc] init];
        WPIAMWebViewViewController *webViewVC = [WPIAMWebViewViewController
                                                 instantiateViewControllerWithResourceBundle:resourceBundle
                                                 displayMessage:webViewMessage
                                                 controllerDelegate:controllerDelegate
                                                 timeFetcher:timeFetcher];
        if (webViewVC == nil) {
            WPLogDebug(@"webView view controller can not be created.");
            NSError *error = [NSError errorWithDomain:kInAppMessagingDisplayErrorDomain
                                                 code:IAMDisplayRenderErrorTypeUnspecifiedError
                                             userInfo:@{}];
            [controllerDelegate displayErrorForMessage:webViewMessage error:error];
            return;
        }

        UIWindow *displayUIWindow = [WPIAMRenderingWindowHelper UIWindowForWebViewView];
        displayUIWindow.rootViewController = webViewVC;
        if ([displayUIWindow isKindOfClass:WPIAMWebViewContainerWindow.class]) {
            [(id)displayUIWindow setWebView:webViewMessage.webView];
        }
        [displayUIWindow setHidden:NO];
    });
}

#pragma mark - protocol WPInAppMessagingDisplay
- (BOOL)displayMessage:(WPInAppMessagingDisplayMessage *)messageForDisplay
       displayDelegate:(id<WPInAppMessagingControllerDelegate>)displayDelegate {
    if ([messageForDisplay isKindOfClass:[WPInAppMessagingModalDisplay class]]) {
        WPLogDebug( @"Display a modal message.");
        [self.class displayModalViewWithMessageDefinition:(WPInAppMessagingModalDisplay *)messageForDisplay
                                          controllerDelegate:displayDelegate];
        
    } else if ([messageForDisplay isKindOfClass:[WPInAppMessagingBannerDisplay class]]) {
        WPLogDebug( @"Display a banner message.");
        [self.class displayBannerViewWithMessageDefinition:(WPInAppMessagingBannerDisplay *)messageForDisplay
                                           controllerDelegate:displayDelegate];
    } else if ([messageForDisplay isKindOfClass:[WPInAppMessagingImageOnlyDisplay class]]) {
        WPLogDebug( @"Display an image only message.");
        [self.class displayImageOnlyViewWithMessageDefinition:(WPInAppMessagingImageOnlyDisplay *)messageForDisplay
                                              controllerDelegate:displayDelegate];
    } else if ([messageForDisplay isKindOfClass:[WPInAppMessagingWebViewDisplay class]]) {
        WPLogDebug( @"Display a webview message.");
        [self.class displayWebViewViewWithMessageDefinition:(WPInAppMessagingWebViewDisplay *)messageForDisplay
                                              controllerDelegate:displayDelegate];
    } else if ([messageForDisplay isKindOfClass:[WPInAppMessagingCardDisplay class]]) {
        WPLogDebug( @"Display a card message.");
        [self.class displayCardViewWithMessageDefinition:(WPInAppMessagingCardDisplay *)messageForDisplay
                                         controllerDelegate:displayDelegate];
        
    } else {
        WPLog(
                      @"Unknown message type %@ "
                      "Don't know how to handle it.",
                      messageForDisplay.class);
        NSError *error = [NSError errorWithDomain:kInAppMessagingDisplayErrorDomain
                                             code:IAMDisplayRenderErrorTypeUnspecifiedError
                                         userInfo:@{}];
        [displayDelegate displayErrorForMessage:messageForDisplay error:error];
    }
    return YES;
}

+ (NSError *)applicationNotActiveError {
    return [NSError errorWithDomain:kInAppMessagingDisplayErrorDomain
                               code:IAMDisplayRenderErrorTypeApplicationNotActiveError
                           userInfo:@{}];
}
@end

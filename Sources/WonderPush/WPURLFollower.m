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
#import <UIKit/UIKit.h>

#import "WPCore+InAppMessaging.h"
#import "WPURLFollower.h"
#import "WonderPush.h"

@interface WPURLFollower ()
@property(nonatomic, readonly, nonnull, copy) NSSet<NSString *> *appCustomURLSchemesSet;
@property(nonatomic, readonly) BOOL isOldAppDelegateOpenURLDefined;
@property(nonatomic, readonly) BOOL isNewAppDelegateOpenURLDefined;
@property(nonatomic, readonly) BOOL isContinueUserActivityMethodDefined;

@property(nonatomic, readonly, nullable) id<UIApplicationDelegate> appDelegate;
@property(nonatomic, readonly, nonnull) UIApplication *mainApplication;
@end

@implementation WPURLFollower

+ (WPURLFollower *)URLFollower {
    static WPURLFollower *URLFollower;
    static dispatch_once_t onceToken;
    
    dispatch_once(&onceToken, ^{
        NSMutableArray<NSString *> *customSchemeURLs = [[NSMutableArray alloc] init];
        
        // Reading the custom url list from the environment.
        NSBundle *appBundle = [NSBundle mainBundle];
        if (appBundle) {
            id URLTypesID = [appBundle objectForInfoDictionaryKey:@"CFBundleURLTypes"];
            if ([URLTypesID isKindOfClass:[NSArray class]]) {
                NSArray *urlTypesArray = (NSArray *)URLTypesID;
                
                for (id nextURLType in urlTypesArray) {
                    if ([nextURLType isKindOfClass:[NSDictionary class]]) {
                        NSDictionary *nextURLTypeDict = (NSDictionary *)nextURLType;
                        id nextSchemeArray = nextURLTypeDict[@"CFBundleURLSchemes"];
                        if (nextSchemeArray && [nextSchemeArray isKindOfClass:[NSArray class]]) {
                            [customSchemeURLs addObjectsFromArray:nextSchemeArray];
                        }
                    }
                }
            }
        }
        WPLogDebug(
                    @"Detected %d custom URL schemes from environment", (int)customSchemeURLs.count);
        
        if ([NSThread isMainThread]) {
            // We can not dispatch sychronously to main queue if we are already in main queue. That
            // can cause deadlock.
            URLFollower = [[WPURLFollower alloc]
                           initWithCustomURLSchemeArray:[customSchemeURLs copy]
                           withApplication:UIApplication.sharedApplication];
        } else {
            // If we are not on main thread, dispatch it to main queue since it invovles calling UIKit
            // methods, which are required to be carried out on main queue.
            dispatch_sync(dispatch_get_main_queue(), ^{
                URLFollower = [[WPURLFollower alloc]
                               initWithCustomURLSchemeArray:[customSchemeURLs copy]
                               withApplication:UIApplication.sharedApplication];
            });
        }
    });
    return URLFollower;
}

- (instancetype)initWithCustomURLSchemeArray:(NSArray<NSString *> *)customURLScheme
                             withApplication:(UIApplication *)application {
    if (self = [super init]) {
        _appCustomURLSchemesSet = [NSSet setWithArray:customURLScheme];
        _mainApplication = application;
        _appDelegate = [application delegate];
        
        if (_appDelegate) {
            _isOldAppDelegateOpenURLDefined = [_appDelegate
                                               respondsToSelector:@selector(application:openURL:sourceApplication:annotation:)];
            
            _isNewAppDelegateOpenURLDefined =
            [_appDelegate respondsToSelector:@selector(application:openURL:options:)];
            
            _isContinueUserActivityMethodDefined = [_appDelegate
                                                    respondsToSelector:@selector(application:continueUserActivity:restorationHandler:)];
        }
    }
    return self;
}

- (void)followURL:(NSURL *)targetUrl withCompletionBlock:(void (^)(BOOL success))completion {
    // So this is the logic of the url following flow
    //  1 If it's a http or https link
    //     1.1 If delegate implements application:continueUserActivity:restorationHandler: and calling
    //       it returns YES: the flow stops here: we have finished the url-following action
    //     1.2 In other cases: fall through to step 3
    //  2 If the URL scheme matches any element in appCustomURLSchemes
    //     2.1 Triggers application:openURL:options: or
    //     application:openURL:sourceApplication:annotation:
    //          depending on their availability.
    //  3 Use UIApplication openURL: or openURL:options:completionHandler: to have iOS system to deal
    //     with the url following.
    //
    //  The rationale for doing step 1 and 2 instead of simply doing step 3 for all cases are:
    //     I)  calling UIApplication openURL with the universal link targeted for current app would
    //         not cause the link being treated as a universal link. See apple doc at
    // https://developer.apple.com/library/content/documentation/General/Conceptual/AppSearch/UniversalLinks.html
    //         So step 1 is trying to handle this gracefully
    //     II) If there are other apps on the same device declaring the same custom url scheme as for
    //         the current app, doing step 3 directly have the risk of triggering another app for
    //         handling the custom scheme url: See the note about "If more than one third-party" from
    // https://developer.apple.com/library/content/documentation/iPhone/Conceptual/iPhoneOSProgrammingGuide/Inter-AppCommunication/Inter-AppCommunication.html
    //         So step 2 is to optimize user experience by short-circuiting the engagement with iOS
    //         system
    
    WPLogDebug( @"Following action url %@", targetUrl);
    
    if ([self.class isHttpOrHttpsScheme:targetUrl]) {
        WPLogDebug( @"Try to treat it as a universal link.");
        if ([self followURLWithContinueUserActivity:targetUrl]) {
            completion(YES);
            return;  // following the url has been fully handled by App Delegate's
            // continueUserActivity method
        }
    } else if ([self isCustomSchemeForCurrentApp:targetUrl]) {
        WPLogDebug( @"Custom URL scheme matches.");
        if ([self followURLWithAppDelegateOpenURLActivity:targetUrl]) {
            [[NSNotificationCenter defaultCenter] postNotificationName:WP_DEEPLINK_OPENED object:nil userInfo:@{
                WP_DEEPLINK_OPENED_URL_USERINFO_KEY : targetUrl
            }];
            completion(YES);
            return;  // following the url has been fully handled by App Delegate's openURL method
        }
    }
    
    WPLogDebug( @"Open the url via iOS.");
    [self followURLViaIOS:targetUrl withCompletionBlock:completion];
}

// Try to handle the url as a custom scheme url link by triggering
// application:openURL:options: on App's delegate object directly.
// @returns YES if that delegate method is defined and returns YES.
- (BOOL)followURLWithAppDelegateOpenURLActivity:(NSURL *)url {
    if (self.isNewAppDelegateOpenURLDefined) {
        WPLogDebug(
                    @"iOS 9+ version of App Delegate's application:openURL:options: method detected");
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wunguarded-availability"
        return [self.appDelegate application:self.mainApplication openURL:url options:@{}];
#pragma clang pop
    }
    
    // if we come here, we can try to trigger the older version of openURL method on the app's
    // delegate
    if (self.isOldAppDelegateOpenURLDefined) {
        WPLogDebug(
                    @"iOS 9 below version of App Delegate's openURL method detected");
        NSString *appBundleIdentifier = [[NSBundle mainBundle] bundleIdentifier];
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        BOOL handled = [self.appDelegate application:self.mainApplication
                                             openURL:url
                                   sourceApplication:appBundleIdentifier
                                          annotation:@{}];
#pragma clang pop
        return handled;
    }
    
    WPLogDebug(
                @"No approriate openURL method defined for App Delegate");
    return NO;
}

// Try to handle the url as a universal link by triggering
// application:continueUserActivity:restorationHandler: on App's delegate object directly.
// @returns YES if that delegate method is defined and seeing a YES being returned from
// trigging it
- (BOOL)followURLWithContinueUserActivity:(NSURL *)url {
    if (self.isContinueUserActivityMethodDefined) {
        WPLogDebug(
                    @"App delegate responds to application:continueUserActivity:restorationHandler:."
                    "Simulating action url opening from a web browser.");
        NSUserActivity *userActivity =
        [[NSUserActivity alloc] initWithActivityType:NSUserActivityTypeBrowsingWeb];
        userActivity.webpageURL = url;
        BOOL handled = [self.appDelegate application:self.mainApplication
                                continueUserActivity:userActivity
                                  restorationHandler:^(NSArray *restorableObjects) {
            // mimic system behavior of triggering restoreUserActivityState:
            // method on each element of restorableObjects
            for (id nextRestoreObject in restorableObjects) {
                if ([nextRestoreObject isKindOfClass:[UIResponder class]]) {
                    UIResponder *responder = (UIResponder *)nextRestoreObject;
                    [responder restoreUserActivityState:userActivity];
                }
            }
        }];
        if (handled) {
            WPLogDebug(
                        @"App handling acton URL returns YES, no more further action taken");
        } else {
            WPLogDebug( @"App handling acton URL returns NO.");
        }
        return handled;
    }
    
    // Look for a scene delegate
    // We'll check all the scenes, prioritizing the foregroundActive ones, then foregroundInactive, then background, finally unattached
    NSMutableArray<UIScene *> *connectedScenes = [NSMutableArray arrayWithArray:self.mainApplication.connectedScenes.allObjects];
    int(^priority)(UISceneActivationState) = ^(UISceneActivationState state) {
        switch(state) {
            case UISceneActivationStateForegroundActive: return 0;
            case UISceneActivationStateForegroundInactive: return 1;
            case UISceneActivationStateBackground: return 2;
            case UISceneActivationStateUnattached: return 3;
        }
    };
    [connectedScenes sortUsingComparator:^(id obj1, id obj2) {
        UIScene *scene1 = obj1;
        UIScene *scene2 = obj2;
        int x1 = priority(scene1.activationState);
        int x2 = priority(scene2.activationState);
        if (x1 > x2) return NSOrderedDescending;
        if (x1 < x2) return NSOrderedAscending;
        return NSOrderedSame;
    }];
    if (connectedScenes.count > 0) {
        UIScene *scene = connectedScenes.firstObject;
        if ([scene.delegate respondsToSelector:@selector(scene:continueUserActivity:)]) {
            dispatch_async(dispatch_get_main_queue(), ^{
                NSUserActivity *userActivity = [[NSUserActivity alloc] initWithActivityType:NSUserActivityTypeBrowsingWeb];
                userActivity.webpageURL = url;
                if ([scene.delegate respondsToSelector:@selector(scene:willContinueUserActivityWithType:)]) {
                    [scene.delegate scene:scene willContinueUserActivityWithType:userActivity.activityType];
                }
                [scene.delegate scene:scene continueUserActivity:userActivity];
            });
            return YES;
        }
    }
    return NO;
}

- (void)followURLViaIOS:(NSURL *)url withCompletionBlock:(void (^)(BOOL success))completion {
    if ([self.mainApplication respondsToSelector:@selector(openURL:options:completionHandler:)]) {
        NSDictionary *options = @{};
        [self.mainApplication
         openURL:url
         options:options
         completionHandler:^(BOOL success) {
            WPLogDebug( @"openURL result is %d", success);
            completion(success);
        }];
    } else {
        // fallback to the older version of openURL
        BOOL success = [self.mainApplication openURL:url];
        WPLogDebug( @"openURL result is %d", success);
        completion(success);
    }
}

- (BOOL)isCustomSchemeForCurrentApp:(NSURL *)url {
    NSString *schemeInLowerCase = [url.scheme lowercaseString];
    return [self.appCustomURLSchemesSet containsObject:schemeInLowerCase];
}

+ (BOOL)isHttpOrHttpsScheme:(NSURL *)url {
    NSString *schemeInLowerCase = [url.scheme lowercaseString];
    return
    [schemeInLowerCase isEqualToString:@"https"] || [schemeInLowerCase isEqualToString:@"http"];
}
@end

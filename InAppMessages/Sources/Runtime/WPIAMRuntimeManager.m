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
#import "WPIAMBookKeeper.h"
#import "WPIAMDisplayCheckOnAnalyticEventsFlow.h"
#import "WPIAMDisplayCheckOnAppForegroundFlow.h"
#import "WPIAMDisplayCheckOnFetchDoneNotificationFlow.h"
#import "WPIAMDisplayExecutor.h"
#import "WPIAMMessageClientCache.h"
#import "WPIAMRuntimeManager.h"
#import "WPIAMSDKModeManager.h"
#import "WPInAppMessaging.h"
#import "WonderPush_private.h"

@interface WPInAppMessaging ()
@end

// A enum indicating 3 different possiblities of a setting about auto data collection.
typedef NS_ENUM(NSInteger, WPIAMAutoDataCollectionSetting) {
    // This indicates that the config is not explicitly set.
    WPIAMAutoDataCollectionSettingNone = 0,
    
    // This indicates that the setting explicitly enables the auto data collection.
    WPIAMAutoDataCollectionSettingEnabled = 1,
    
    // This indicates that the setting explicitly disables the auto data collection.
    WPIAMAutoDataCollectionSettingDisabled = 2,
};

@interface WPIAMRuntimeManager ()
@property(nonatomic, nonnull) WPIAMDisplayCheckOnAppForegroundFlow *displayOnAppForegroundFlow;
@property(nonatomic, nonnull) WPIAMDisplayCheckOnFetchDoneNotificationFlow *displayOnFetchDoneFlow;
@property(nonatomic, nonnull) WPIAMDisplayCheckOnAnalyticEventsFlow *displayOnWonderPushEventsFlow;
@property(atomic, readwrite) BOOL running;
@end

@implementation WPIAMRuntimeManager

+ (WPIAMRuntimeManager *)getSDKRuntimeInstance {
    static WPIAMRuntimeManager *managerInstance = nil;
    static dispatch_once_t onceToken;
    
    dispatch_once(&onceToken, ^{
        managerInstance = [[WPIAMRuntimeManager alloc] init];
    });
    
    return managerInstance;
}

- (BOOL)shouldRunSDKFlowsOnStartup {
    return YES;
}

- (void)resume {
    @synchronized(self) {
        if (!self.running) {
            [self.displayOnAppForegroundFlow start];
            [self.displayOnFetchDoneFlow start];
            [self.displayOnWonderPushEventsFlow start];
            WPLogDebug(
                        @"Start WonderPush In-App Messaging flows from inactive.");
            self.running = YES;
        } else {
            WPLog(
                          @"Runtime is already active, resume is just a no-op");
        }
    }
}

- (void)pause {
    @synchronized(self) {
        if (self.running) {
            [self.displayOnAppForegroundFlow stop];
            [self.displayOnFetchDoneFlow stop];
            [self.displayOnWonderPushEventsFlow stop];
            WPLogDebug(
                        @"Shutdown WonderPush In-App Messaging flows.");
            self.running = NO;
        } else {
            WPLog(
                          @"No runtime active yet, pause is just a no-op");
        }
    }
}

- (void)setShouldSuppressMessageDisplay:(BOOL)shouldSuppress {
    WPLogDebug( @"Message display suppress set to %@",
                @(shouldSuppress));
    self.displayExecutor.suppressMessageDisplay = shouldSuppress;
}

- (void)startRuntimeWithSDKSettings:(WPIAMSDKSettings *)settings {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0ul), ^{
        [self internalStartRuntimeWithSDKSettings:settings];
    });
}

- (void)internalStartRuntimeWithSDKSettings:(WPIAMSDKSettings *)settings {
    if (self.running) {
        // Runtime has been started previously. Stop all the flows first.
        [self.displayOnAppForegroundFlow stop];
        [self.displayOnFetchDoneFlow stop];
        [self.displayOnWonderPushEventsFlow stop];
    }
    
    self.currentSetting = settings;
    
    WPIAMTimerWithNSDate *timeFetcher = [[WPIAMTimerWithNSDate alloc] init];
//    NSTimeInterval start = [timeFetcher currentTimestampInSeconds];
    
    self.bookKeeper = [[WPIAMBookKeeperViaUserDefaults alloc]
                       initWithUserDefaults:[NSUserDefaults standardUserDefaults]];
    
    self.messageCache = [[WPIAMMessageClientCache alloc] initWithBookkeeper:self.bookKeeper];
    
    // start render on app foreground flow
    WPIAMDisplaySetting *appForegroundDisplaysetting = [[WPIAMDisplaySetting alloc] init];
    appForegroundDisplaysetting.displayMinIntervalInMinutes =
    settings.appFGRenderMinIntervalInMinutes;
    
    self.displayExecutor =
    [[WPIAMDisplayExecutor alloc] initWithInAppMessaging:[WPInAppMessaging inAppMessaging]
                                                  setting:appForegroundDisplaysetting
                                             messageCache:self.messageCache
                                              timeFetcher:timeFetcher
                                               bookKeeper:self.bookKeeper];
        
    // Setting the message display component and suppression. It's needed in case
    // headless SDK is initialized after the these properties are already set on WPInAppMessaging.
    self.displayExecutor.messageDisplayComponent =
    WPInAppMessaging.inAppMessaging.messageDisplayComponent;
    self.displayExecutor.suppressMessageDisplay =
    WPInAppMessaging.inAppMessaging.messageDisplaySuppressed;
    
    // Both display flows are created on startup. But they would only be turned on (started) based on
    // the sdk mode for the current instance
    self.displayOnFetchDoneFlow = [[WPIAMDisplayCheckOnFetchDoneNotificationFlow alloc]
                                   initWithDisplayFlow:self.displayExecutor
                                   messageCache:self.messageCache];
    self.displayOnAppForegroundFlow =
    [[WPIAMDisplayCheckOnAppForegroundFlow alloc] initWithDisplayFlow:self.displayExecutor];
    
    self.displayOnWonderPushEventsFlow =
    [[WPIAMDisplayCheckOnAnalyticEventsFlow alloc] initWithDisplayFlow:self.displayExecutor];
    
    self.messageCache.analycisEventDislayCheckFlow = self.displayOnWonderPushEventsFlow;
    [self.messageCache
     loadMessagesFromRemoteConfigWithCompletion:^(BOOL success) {
        // start flows regardless whether we can load messages from fetch
        // storage successfully
        WPLogDebug(
                    @"Message loading from fetch storage was done.");
        
        if ([self shouldRunSDKFlowsOnStartup]) {
//            WPLogDebug(@"Start SDK runtime components.");
            
            [self.displayOnWonderPushEventsFlow start];
            
            self.running = YES;
            
//            WPLogDebug(@"Start regular display flow for non-testing instance mode");
            [self.displayOnAppForegroundFlow start];
            [self.displayOnFetchDoneFlow start];

            dispatch_async(dispatch_get_main_queue(), ^{
                void(^displayNext)(void) = ^{
                    [self.displayExecutor checkAndDisplayNextAppLaunchMessage];
                    // Simulate app going into foreground on startup
                    [self.displayExecutor checkAndDisplayNextAppForegroundMessage];
                };
                if (UIApplication.sharedApplication.applicationState == UIApplicationStateActive) {
                    displayNext();
                } else {
                    id __block registration = [NSNotificationCenter.defaultCenter addObserverForName:UIApplicationDidBecomeActiveNotification object:nil queue:nil usingBlock:^(NSNotification *note) {
                        [NSNotificationCenter.defaultCenter removeObserver:registration];
                        displayNext();
                    }];
                }
            });

        } else {
            WPLogDebug(
                        @"No IAM SDK startup due to settings.");
        }
    }];
    
//    WPLogDebug(@"WonderPush In-App Messaging SDK finished startup in %lf seconds with these settings: %@",
//                (double)([timeFetcher currentTimestampInSeconds] - start), settings);
}

- (void) forceFetchInApps {
    [self.messageCache loadMessagesFromRemoteConfigWithCompletion:nil];
}
@end

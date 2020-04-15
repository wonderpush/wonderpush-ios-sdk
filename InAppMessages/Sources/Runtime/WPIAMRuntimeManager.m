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
#import "WPIAMClientInfoFetcher.h"
#import "WPIAMDisplayCheckOnAnalyticEventsFlow.h"
#import "WPIAMDisplayCheckOnAppForegroundFlow.h"
#import "WPIAMDisplayCheckOnFetchDoneNotificationFlow.h"
#import "WPIAMDisplayExecutor.h"
#import "WPIAMFetchOnAppForegroundFlow.h"
#import "WPIAMFetchResponseParser.h"
#import "WPIAMMessageClientCache.h"
#import "WPIAMMsgFetcherUsingRestful.h"
#import "WPIAMRuntimeManager.h"
#import "WPIAMSDKModeManager.h"
#import "WPInAppMessaging.h"

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

@interface WPIAMRuntimeManager () <WPIAMTestingModeListener>
@property(nonatomic, nonnull) WPIAMMsgFetcherUsingRestful *restfulFetcher;
@property(nonatomic, nonnull) WPIAMDisplayCheckOnAppForegroundFlow *displayOnAppForegroundFlow;
@property(nonatomic, nonnull) WPIAMDisplayCheckOnFetchDoneNotificationFlow *displayOnFetchDoneFlow;
@property(nonatomic, nonnull) WPIAMDisplayCheckOnAnalyticEventsFlow *displayOnWonderPushEventsFlow;

@property(nonatomic, nonnull) WPIAMFetchOnAppForegroundFlow *fetchOnAppForegroundFlow;
@property(nonatomic, nonnull) WPIAMClientInfoFetcher *clientInfoFetcher;
@property(nonatomic, nonnull) WPIAMFetchResponseParser *responseParser;
@end

static NSString *const _userDefaultsKeyForIAMProgammaticAutoDataCollectionSetting = @"wonderpush-iam-sdk-auto-data-collection";

@implementation WPIAMRuntimeManager {
    // since we allow the SDK feature to be disabled/enabled at runtime, we need a field to track
    // its state on this
    BOOL _running;
}
+ (WPIAMRuntimeManager *)getSDKRuntimeInstance {
    static WPIAMRuntimeManager *managerInstance = nil;
    static dispatch_once_t onceToken;
    
    dispatch_once(&onceToken, ^{
        managerInstance = [[WPIAMRuntimeManager alloc] init];
    });
    
    return managerInstance;
}

// For protocol WPIAMTestingModeListener.
- (void)testingModeSwitchedOn {
    WPLogDebug(
                @"Dynamically switch to the display flow for testing mode instance.");
    
    [self.displayOnAppForegroundFlow stop];
    [self.displayOnFetchDoneFlow start];
}

- (BOOL)shouldRunSDKFlowsOnStartup {
    return YES;
}

- (void)resume {
    // persist the setting
    [[NSUserDefaults standardUserDefaults]
     setObject:@(YES)
     forKey:_userDefaultsKeyForIAMProgammaticAutoDataCollectionSetting];
    
    @synchronized(self) {
        if (!_running) {
            [self.fetchOnAppForegroundFlow start];
            [self.displayOnAppForegroundFlow start];
            [self.displayOnWonderPushEventsFlow start];
            WPLogDebug(
                        @"Start WonderPush In-App Messaging flows from inactive.");
            _running = YES;
        } else {
            WPLog(
                          @"Runtime is already active, resume is just a no-op");
        }
    }
}

- (void)pause {
    // persist the setting
    [[NSUserDefaults standardUserDefaults]
     setObject:@(NO)
     forKey:_userDefaultsKeyForIAMProgammaticAutoDataCollectionSetting];
    
    @synchronized(self) {
        if (_running) {
            [self.fetchOnAppForegroundFlow stop];
            [self.displayOnAppForegroundFlow stop];
            [self.displayOnWonderPushEventsFlow stop];
            WPLogDebug(
                        @"Shutdown WonderPush In-App Messaging flows.");
            _running = NO;
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
    if (_running) {
        // Runtime has been started previously. Stop all the flows first.
        [self.fetchOnAppForegroundFlow stop];
        [self.displayOnAppForegroundFlow stop];
        [self.displayOnWonderPushEventsFlow stop];
    }
    
    self.currentSetting = settings;
    
    WPIAMTimerWithNSDate *timeFetcher = [[WPIAMTimerWithNSDate alloc] init];
    NSTimeInterval start = [timeFetcher currentTimestampInSeconds];
    
    self.responseParser = [[WPIAMFetchResponseParser alloc] initWithTimeFetcher:timeFetcher];
    
    self.bookKeeper = [[WPIAMBookKeeperViaUserDefaults alloc]
                       initWithUserDefaults:[NSUserDefaults standardUserDefaults]];
    
    self.messageCache = [[WPIAMMessageClientCache alloc] initWithBookkeeper:self.bookKeeper
                                                         usingResponseParser:self.responseParser];
    self.fetchResultStorage = [[WPIAMServerMsgFetchStorage alloc] init];
    self.clientInfoFetcher = [[WPIAMClientInfoFetcher alloc] init];
    
    self.restfulFetcher =
    [[WPIAMMsgFetcherUsingRestful alloc] initWithFetchStorage:self.fetchResultStorage
                                                responseParser:self.responseParser];
    
    // start render on app foreground flow
    WPIAMDisplaySetting *appForegroundDisplaysetting = [[WPIAMDisplaySetting alloc] init];
    appForegroundDisplaysetting.displayMinIntervalInMinutes =
    settings.appFGRenderMinIntervalInMinutes;
    
    WPIAMSDKModeManager *sdkModeManager =
    [[WPIAMSDKModeManager alloc] initWithUserDefaults:NSUserDefaults.standardUserDefaults
                                   testingModeListener:self];
    
    self.displayExecutor =
    [[WPIAMDisplayExecutor alloc] initWithInAppMessaging:[WPInAppMessaging inAppMessaging]
                                                  setting:appForegroundDisplaysetting
                                             messageCache:self.messageCache
                                              timeFetcher:timeFetcher
                                               bookKeeper:self.bookKeeper];
    
    self.fetchOnAppForegroundFlow =
    [[WPIAMFetchOnAppForegroundFlow alloc] initWithMessageCache:self.messageCache
                                                  messageFetcher:self.restfulFetcher
                                                     timeFetcher:timeFetcher
                                                      bookKeeper:self.bookKeeper
                                             WPIAMSDKModeManager:sdkModeManager
                                                 displayExecutor:self.displayExecutor];
    
    // Setting the message display component and suppression. It's needed in case
    // headless SDK is initialized after the these properties are already set on WPInAppMessaging.
    self.displayExecutor.messageDisplayComponent =
    WPInAppMessaging.inAppMessaging.messageDisplayComponent;
    self.displayExecutor.suppressMessageDisplay =
    WPInAppMessaging.inAppMessaging.messageDisplaySuppressed;
    
    // Both display flows are created on startup. But they would only be turned on (started) based on
    // the sdk mode for the current instance
    self.displayOnFetchDoneFlow = [[WPIAMDisplayCheckOnFetchDoneNotificationFlow alloc]
                                   initWithDisplayFlow:self.displayExecutor];
    self.displayOnAppForegroundFlow =
    [[WPIAMDisplayCheckOnAppForegroundFlow alloc] initWithDisplayFlow:self.displayExecutor];
    
    self.displayOnWonderPushEventsFlow =
    [[WPIAMDisplayCheckOnAnalyticEventsFlow alloc] initWithDisplayFlow:self.displayExecutor];
    
    self.messageCache.analycisEventDislayCheckFlow = self.displayOnWonderPushEventsFlow;
    [self.messageCache
     loadMessageDataFromServerFetchStorage:self.fetchResultStorage
     withCompletion:^(BOOL success) {
        // start flows regardless whether we can load messages from fetch
        // storage successfully
        WPLogDebug(
                    @"Message loading from fetch storage was done.");
        
        if ([self shouldRunSDKFlowsOnStartup]) {
            WPLogDebug(
                        @"Start SDK runtime components.");
            
            [self.fetchOnAppForegroundFlow start];
            [self.displayOnWonderPushEventsFlow start];
            
            self->_running = YES;
            
            if (sdkModeManager.currentMode == WPIAMSDKModeTesting) {
                WPLogDebug(
                            @"InAppMessaging testing mode enabled. App "
                            "foreground messages will be displayed following "
                            "fetch");
                [self.displayOnFetchDoneFlow start];
            } else {
                WPLogDebug(
                            @"Start regular display flow for non-testing "
                            "instance mode");
                [self.displayOnAppForegroundFlow start];
                
                // Simulate app going into foreground on startup
                [self.displayExecutor checkAndDisplayNextAppForegroundMessage];
            }
            
            // One-time triggering of checks for both fetch flow
            // upon SDK/app startup.
            [self.fetchOnAppForegroundFlow
             checkAndFetchForInitialAppLaunch:YES];
        } else {
            WPLogDebug(
                        @"No IAM SDK startup due to settings.");
        }
    }];
    
    WPLogDebug(
                @"WonderPush In-App Messaging SDK finished startup in %lf seconds "
                "with these settings: %@",
                (double)([timeFetcher currentTimestampInSeconds] - start), settings);
}

- (void) forceFetchInApps {
    [self.restfulFetcher
    fetchMessagesWithCompletion:^(NSArray<WPIAMMessageDefinition *> *_Nullable messages,
                                  NSNumber *_Nullable nextFetchWaitTime,
                                  NSInteger discardedMessageCount,
                                  NSError *_Nullable error) {
        [self.messageCache setMessageData:messages];
    }];
}
@end

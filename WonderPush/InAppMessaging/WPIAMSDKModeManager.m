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

#import "WPCore+InAppMessaging.h"
#import "WPIAMSDKModeManager.h"

NSString *WPIAMDescriptonStringForSDKMode(WPIAMSDKMode mode) {
    switch (mode) {
        case WPIAMSDKModeTesting:
            return @"Testing Instance";
        case WPIAMSDKModeRegular:
            return @"Regular";
        case WPIAMSDKModeNewlyInstalled:
            return @"Newly Installed";
        default:
            WPLog( @"Unknown sdk mode value %d",
                          (int)mode);
            return @"Unknown";
    }
}

@interface WPIAMSDKModeManager ()
@property(nonatomic, nonnull, readonly) NSUserDefaults *userDefaults;
// Make it weak so that we don't depend on its existence to avoid circular reference.
@property(nonatomic, readonly, weak) id<WPIAMTestingModeListener> testingModeListener;
@end

NSString *const kWPIAMUserDefaultKeyForSDKMode = @"wonderpush-iam-sdk-mode";
NSString *const kWPIAMUserDefaultKeyForServerFetchCount = @"wonderpush-iam-server-fetch-count";
NSInteger const kWPIAMMaxFetchInNewlyInstalledMode = 5;

@implementation WPIAMSDKModeManager {
    WPIAMSDKMode _sdkMode;
    NSInteger _fetchCount;
}

- (instancetype)initWithUserDefaults:(NSUserDefaults *)userDefaults
                 testingModeListener:(id<WPIAMTestingModeListener>)testingModeListener {
    if (self = [super init]) {
        _userDefaults = userDefaults;
        _testingModeListener = testingModeListener;
        
        id modeEntry = [_userDefaults objectForKey:kWPIAMUserDefaultKeyForSDKMode];
        if (modeEntry == nil) {
            // no entry yet, it's a newly installed sdk instance
            _sdkMode = WPIAMSDKModeNewlyInstalled;
            
            // initialize the mode and fetch count in the persistent storage
            [_userDefaults setObject:[NSNumber numberWithInteger:_sdkMode]
                              forKey:kWPIAMUserDefaultKeyForSDKMode];
            [_userDefaults setInteger:0 forKey:kWPIAMUserDefaultKeyForServerFetchCount];
        } else {
            _sdkMode = [(NSNumber *)modeEntry integerValue];
            _fetchCount = [_userDefaults integerForKey:kWPIAMUserDefaultKeyForServerFetchCount];
        }
        
        WPLogDebug(
                    @"SDK is in mode of %@ and has seen %d fetches.",
                    WPIAMDescriptonStringForSDKMode(_sdkMode), (int)_fetchCount);
    }
    return self;
}

// inform the manager that one more fetch is done. This is to allow
// the manager to potentially graduate from the newly installed mode.
- (void)registerOneMoreFetch {
    // we only care about the fetch count when sdk is in newly installed mode (so that it may
    // graduate from that after certain number of fetches).
    if (_sdkMode == WPIAMSDKModeNewlyInstalled) {
        if (++_fetchCount >= kWPIAMMaxFetchInNewlyInstalledMode) {
            WPLogDebug(
                        @"Coming out of newly installed mode since there have been %d fetches",
                        (int)_fetchCount);
            
            _sdkMode = WPIAMSDKModeRegular;
            [_userDefaults setObject:[NSNumber numberWithInteger:_sdkMode]
                              forKey:kWPIAMUserDefaultKeyForSDKMode];
        } else {
            [_userDefaults setInteger:_fetchCount forKey:kWPIAMUserDefaultKeyForServerFetchCount];
        }
    }
}

- (void)becomeTestingInstance {
    _sdkMode = WPIAMSDKModeTesting;
    [_userDefaults setObject:[NSNumber numberWithInteger:_sdkMode]
                      forKey:kWPIAMUserDefaultKeyForSDKMode];
    
    WPLogDebug(
                @"Test mode enabled, notifying test mode listener.");
    [self.testingModeListener testingModeSwitchedOn];
}

// returns the current SDK mode
- (WPIAMSDKMode)currentMode {
    return _sdkMode;
}
@end

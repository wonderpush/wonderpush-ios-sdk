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
#import "WPIAMClientInfoFetcher.h"

@implementation WPIAMClientInfoFetcher

- (nullable NSString *)getDeviceLanguageCode {
    // No caching since it's requested at pretty low frequency and we get the benefit of seeing
    // updated info the setting has changed
    NSArray<NSString *> *preferredLanguages = [NSLocale preferredLanguages];
    return preferredLanguages.firstObject;
}

- (nullable NSString *)getAppVersion {
    // Since this won't change, read it once in the whole life-cycle of the app and cache its value
    static NSString *appVersion = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        appVersion = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
    });
    return appVersion;
}

- (nullable NSString *)getOSVersion {
    // Since this won't change, read it once in the whole life-cycle of the app and cache its value
    static NSString *OSVersion = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSOperatingSystemVersion systemVersion = [NSProcessInfo processInfo].operatingSystemVersion;
        OSVersion = [NSString stringWithFormat:@"%ld.%ld.%ld", (long)systemVersion.majorVersion,
                     (long)systemVersion.minorVersion,
                     (long)systemVersion.patchVersion];
    });
    return OSVersion;
}

- (nullable NSString *)getOSMajorVersion {
    NSArray *versionItems = [[self getOSVersion] componentsSeparatedByString:@"."];
    
    if (versionItems.count > 0) {
        return (NSString *)versionItems[0];
    } else {
        return nil;
    }
}

- (nullable NSString *)getTimezone {
    // No caching to deal with potential changes.
    return [NSTimeZone localTimeZone].name;
}

@end

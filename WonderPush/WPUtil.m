/*
 Copyright 2014 WonderPush

 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at

 http://www.apache.org/licenses/LICENSE-2.0

 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License.
 */

#import "WPUtil.h"
#import "WPConfiguration.h"
#import "WPLog.h"
#import "WonderPush_private.h"

#import <sys/utsname.h>
#import <UIKit/UIApplication.h>
#import <TCMobileProvision/TCMobileProvision.h>


NSString * const WPErrorDomain = @"WPErrorDomain";
NSInteger const WPErrorInvalidCredentials = 11000;
NSInteger const WPErrorInvalidAccessToken = 11003;

@implementation WPUtil

+ (NSString*)base64forData:(NSData*)theData
{

    const uint8_t* input = (const uint8_t*)[theData bytes];
    NSInteger length = [theData length];

    static char table[] = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/=";

    NSMutableData* data = [NSMutableData dataWithLength:((length + 2) / 3) * 4];
    uint8_t* output = (uint8_t*)data.mutableBytes;

    NSInteger i;
    for (i=0; i < length; i += 3) {
        NSInteger value = 0;
        NSInteger j;
        for (j = i; j < (i + 3); j++) {
            value <<= 8;

            if (j < length) {
                value |= (0xFF & input[j]);
            }
        }

        NSInteger theIndex = (i / 3) * 4;
        output[theIndex + 0] =                    table[(value >> 18) & 0x3F];
        output[theIndex + 1] =                    table[(value >> 12) & 0x3F];
        output[theIndex + 2] = (i + 1) < length ? table[(value >> 6)  & 0x3F] : '=';
        output[theIndex + 3] = (i + 2) < length ? table[(value >> 0)  & 0x3F] : '=';
    }

    return [[NSString alloc] initWithData:data encoding:NSASCIIStringEncoding];
}

+ (NSDictionary *)dictionaryWithFormEncodedString:(NSString *)encodedString
{
    if (!encodedString) {
        return nil;
    }

    NSMutableDictionary *result = [NSMutableDictionary dictionary];
    NSArray *pairs = [encodedString componentsSeparatedByString:@"&"];

    for (NSString *kvp in pairs) {
        if ([kvp length] == 0) {
            continue;
        }

        NSRange pos = [kvp rangeOfString:@"="];
        NSString *key;
        NSString *val;

        if (pos.location == NSNotFound) {
            key = [kvp stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
            val = @"";
        } else {
            key = [[kvp substringToIndex:pos.location]  stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
            val = [[kvp substringFromIndex:pos.location + pos.length]  stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
        }

        if (!key || !val) {
            continue; // I'm sure this will bite my arse one day
        }

        [result setObject:val forKey:key];
    }
    return result;
}

+ (NSString *)percentEncodedString:(NSString *)string
{
    static NSString * const kAFCharactersToBeEscaped = @":/?#[]@!$&'()*+,;=";
    static NSString * const kAFCharactersToLeaveUnescaped = @"-._~";
    return (__bridge_transfer  NSString *)CFURLCreateStringByAddingPercentEscapes(kCFAllocatorDefault, (__bridge CFStringRef)string, (__bridge CFStringRef)kAFCharactersToLeaveUnescaped, (__bridge CFStringRef)kAFCharactersToBeEscaped, CFStringConvertNSStringEncodingToEncoding(NSUTF8StringEncoding));
}


#pragma mark - Device

+ (NSString *)deviceModel
{
    struct utsname systemInfo;
    uname(&systemInfo);

    return [NSString stringWithCString:systemInfo.machine
                              encoding:NSUTF8StringEncoding];
}

+ (NSString *)deviceIdentifier
{
    WPConfiguration *conf = [WPConfiguration sharedConfiguration];
    NSString *deviceId = conf.deviceId;
    if (deviceId == nil) {
        // Read from local OpenUDID storage to keep a smooth transition off using OpenUDID
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        id localDict = [defaults objectForKey:@"OpenUDID"];
        if ([localDict isKindOfClass:[NSDictionary class]]) {
            id optedOutDate = [localDict objectForKey:@"OpenUDID_optOutTS"];
            if (optedOutDate == nil) {
                deviceId = [localDict objectForKey:@"OpenUDID"];
            }
        }
        if (deviceId == nil) {
            // Generate an UUIDv4
            deviceId = [[NSUUID UUID] UUIDString];
        }
        // Store device id
        conf.deviceId = deviceId;
    }
    return deviceId;
}


#pragma mark - URL Checking

+ (NSDictionary *) paramsForWonderPushURL:(NSURL *)URL
{
    if (!URL.query)
        return @{};

    return [self dictionaryWithFormEncodedString:URL.query];

}


#pragma mark - ERROR

+ (NSError *)errorFromJSON:(id)json
{
    if ([json isKindOfClass:[NSDictionary class]]) {
        NSArray *errorArray = [json arrayForKey:@"error"];
        NSDictionary *errorDict = [json dictionaryForKey:@"error"];
        if (errorDict) {
            errorArray = @[errorDict];
        }
        if (errorArray) {
            for (NSDictionary *detailedError in errorArray) {
                if (![detailedError isKindOfClass:[NSDictionary class]]) continue;
                return [[NSError alloc] initWithDomain:WPErrorDomain
                                                  code:[[detailedError numberForKey:@"code"] integerValue]
                                              userInfo:@{NSLocalizedDescriptionKey : [detailedError stringForKey:@"message"] ?: [NSNull null]}];
            }
        }
    }
    return nil;
}


#pragma mark - Application utils

+ (BOOL) currentApplicationIsInForeground
{
    return [[UIApplication sharedApplication] applicationState] == UIApplicationStateActive;
}

static NSArray *backgroundModes = nil;
+ (NSArray *) getBackgroundModes
{
    if (!backgroundModes) {
        NSBundle *bundle = [NSBundle mainBundle];
        backgroundModes = [bundle objectForInfoDictionaryKey:@"UIBackgroundModes"];
    }
    return backgroundModes;
}

static NSNumber *hasBackgroundMode = nil;
+ (BOOL) hasBackgroundModeRemoteNotification
{
    if (hasBackgroundMode == nil) {
        hasBackgroundMode = [NSNumber numberWithBool:NO];
        NSArray *backgroundModes = [WPUtil getBackgroundModes];
        if (backgroundModes != nil) {
            for (NSString *value in backgroundModes) {
                if ([value isEqual:@"remote-notification"]) {
                    WPLogDebug(@"Has background mode remote-notification");
                    hasBackgroundMode = [NSNumber numberWithBool:YES];
                    break;
                }
            }
        }
    }
    return [hasBackgroundMode boolValue];
}

static NSDictionary *entitlements = nil;
+ (NSString *) getEntitlement:(NSString *)key
{
    if (!entitlements) {
        NSString *mobileprovisionPath = [[[NSBundle mainBundle] bundlePath]
                                         stringByAppendingPathComponent:@"embedded.mobileprovision"];
        TCMobileProvision *mobileprovision = [[TCMobileProvision alloc] initWithData:[NSData dataWithContentsOfFile:mobileprovisionPath]];
        entitlements = mobileprovision.dict[@"Entitlements"];
    }
    return entitlements[key];
}

static NSNumber *hasImplementedDidReceiveRemoteNotificationWithFetchCompletionHandler = nil;
+ (BOOL) hasImplementedDidReceiveRemoteNotificationWithFetchCompletionHandler
{
    if (hasImplementedDidReceiveRemoteNotificationWithFetchCompletionHandler == nil) {
        hasImplementedDidReceiveRemoteNotificationWithFetchCompletionHandler =
        [NSNumber numberWithBool:[[UIApplication sharedApplication].delegate
                                  respondsToSelector:@selector(application:didReceiveRemoteNotification:fetchCompletionHandler:)]];
        WPLogDebug(@"Has implemented [application:didReceiveRemoteNotification:fetchCompletionHandler:] = %@", hasImplementedDidReceiveRemoteNotificationWithFetchCompletionHandler);
    }
    return [hasImplementedDidReceiveRemoteNotificationWithFetchCompletionHandler boolValue];
}

#pragma mark - UUID

+ (NSString *)UUIDString
{
    CFUUIDRef uuid = CFUUIDCreate(kCFAllocatorDefault);
    NSString *result = (NSString *)CFBridgingRelease(CFUUIDCreateString(kCFAllocatorDefault, uuid));
    CFRelease(uuid);
    return result;
}


#pragma mark - SERVER TIME

+ (long long) getServerDate
{
    WPConfiguration *configuration = [WPConfiguration sharedConfiguration];

    if (configuration.timeOffset == 0) {
        // Not synced, use device time
        return (long long) ([[NSDate date] timeIntervalSince1970] * 1000);
    }
    return (long long) (([[NSProcessInfo processInfo] systemUptime] + configuration.timeOffset) * 1000);
}


# pragma mark - LOCALIZATION

+ (NSString *) localizedStringIfPossible:(NSString *)string
{
    return NSLocalizedStringWithDefaultValue(string, nil, [NSBundle mainBundle], string, nil);
}

static NSBundle *wpLocaleBundle = nil;
static bool wpLocaleBundleLoaded = NO;
+ (NSString *) wpLocalizedString:(NSString *)key withDefault:(NSString *)defaultValue
{
    if (!wpLocaleBundleLoaded) {
        wpLocaleBundle = [NSBundle bundleForClass:[WonderPush class]];
        wpLocaleBundle = [NSBundle bundleWithPath:[wpLocaleBundle pathForResource:@"WonderPush" ofType:@"bundle"]] ?: wpLocaleBundle;
        if (!wpLocaleBundle) {
            WPLogDebug(@"Failed to load WonderPush resource bundle with the classic method");
            // https://github.com/haifengkao/PodAsset
            for (NSBundle *bundle in [NSBundle allBundles]) {
                WPLogDebug(@"Testing bundle %@", [bundle bundlePath]);
                NSString *bundlePath = [bundle pathForResource:@"WonderPush" ofType:@"bundle"];
                WPLogDebug(@"  WonderPush.bundle bundlePath: %@", bundlePath);
                if (bundlePath) {
                    wpLocaleBundle = [NSBundle bundleWithPath:bundlePath];
                    WPLogDebug(@"  Used that one. Bundle is %@", wpLocaleBundle);
                    wpLocaleBundleLoaded = YES;
                    break;
                }
                // Find first WonderPush.bundle in the current bundle and use it
                NSDirectoryEnumerator *enumerator = [[NSFileManager defaultManager] enumeratorAtPath:[bundle bundlePath]];
                NSString *filePath;
                while ((filePath = [enumerator nextObject]) != nil) {
                    if ([filePath.lastPathComponent isEqualToString:@"WonderPush.bundle"]) {
                        WPLogDebug(@"  Found %@", filePath);
                        wpLocaleBundle = [NSBundle bundleWithPath:[[bundle bundlePath] stringByAppendingPathComponent:filePath]];
                        WPLogDebug(@"  Used that one. Bundle is %@", wpLocaleBundle);
                        wpLocaleBundleLoaded = YES;
                        break;
                    }
                }
                if (wpLocaleBundleLoaded) break;
            }
        }
        if (!wpLocaleBundleLoaded) {
            WPLog(@"Could not load WonderPush resource bundle");
            wpLocaleBundleLoaded = YES; // even if we failed, don't retry next time
        }
    }
    if (!wpLocaleBundle) {
        // We have to handle the case where wpLocaleBundle is nil, otherwise we get back nil instead of the default value!
        return defaultValue;
    }
    return [wpLocaleBundle localizedStringForKey:key value:defaultValue table:@"WonderPushLocalizable"];
}


@end

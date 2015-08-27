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
#import "WPOpenUDID.h"
#import "WPConfiguration.h"

#import <sys/utsname.h>
#import <UIKit/UIApplication.h>


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
    static NSString * const kWPAFCharactersToBeEscaped = @":/?#[]@!$&'()*+,;=";
    static NSString * const kWPAFCharactersToLeaveUnescaped = @"-._~";
    return (__bridge_transfer  NSString *)CFURLCreateStringByAddingPercentEscapes(kCFAllocatorDefault, (__bridge CFStringRef)string, (__bridge CFStringRef)kWPAFCharactersToLeaveUnescaped, (__bridge CFStringRef)kWPAFCharactersToBeEscaped, CFStringConvertNSStringEncodingToEncoding(NSUTF8StringEncoding));
}


#pragma mark - Device

+ (NSString *)deviceModel {
    struct utsname systemInfo;
    uname(&systemInfo);

    return [NSString stringWithCString:systemInfo.machine
                              encoding:NSUTF8StringEncoding];
}

+ (NSString *)deviceIdentifier
{
    return [WPOpenUDID value];
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
    id errorJson = [json valueForKeyPath:@"error"];
    if (!errorJson)
        return nil;
    if ([errorJson isKindOfClass:[NSArray class]])
    {
        for (id detailedError in ((NSArray *)errorJson))
        {
            if (detailedError && ![detailedError isKindOfClass:[NSNull class]])
            {
                return [[NSError alloc] initWithDomain:WPErrorDomain code:[[detailedError valueForKeyPath:@"code"] integerValue] userInfo:@{NSLocalizedDescriptionKey : [detailedError valueForKeyPath:@"message"]}];
            }
        }
        return nil;
    }
    return [[NSError alloc] initWithDomain:WPErrorDomain code:[[errorJson valueForKeyPath:@"code"] integerValue] userInfo:@{NSLocalizedDescriptionKey : [errorJson valueForKeyPath:@"message"]}];
}


#pragma mark - Application utils

+(BOOL) currentApplicationIsInForeground
{
    return [[UIApplication sharedApplication] applicationState] == UIApplicationStateActive;
}

static NSNumber *hasBackgroundMode = nil;
+ (BOOL) hasBackgroundModeRemoteNotification
{
    if (hasBackgroundMode == nil) {
        hasBackgroundMode = [NSNumber numberWithBool:NO];
        NSBundle *bundle = [NSBundle mainBundle];
        NSArray *backgroundModes = [bundle objectForInfoDictionaryKey:@"UIBackgroundModes"];
        if (backgroundModes != nil) {
            for (NSString *value in backgroundModes) {
                if ([value isEqual:@"remote-notification"]) {
                    WPLog(@"Has background mode remote-notification");
                    hasBackgroundMode = [NSNumber numberWithBool:YES];
                    break;
                }
            }
        }
    }
    return [hasBackgroundMode boolValue];
}

static NSNumber *hasImplementedDidReceiveRemoteNotificationWithFetchCompletionHandler = nil;
+ (BOOL) hasImplementedDidReceiveRemoteNotificationWithFetchCompletionHandler
{
    if (hasImplementedDidReceiveRemoteNotificationWithFetchCompletionHandler == nil) {
        hasImplementedDidReceiveRemoteNotificationWithFetchCompletionHandler =
        [NSNumber numberWithBool:[[UIApplication sharedApplication].delegate
                                  respondsToSelector:@selector(application:didReceiveRemoteNotification:fetchCompletionHandler:)]];
        WPLog(@"Has implemented [application:didReceiveRemoteNotification:fetchCompletionHandler:] = %@", hasImplementedDidReceiveRemoteNotificationWithFetchCompletionHandler);
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

+(long long) getServerDate
{
    WPConfiguration *configuration = [WPConfiguration sharedConfiguration];

    if (configuration.timeOffset == 0) {
        // Not synced, use device time
        return (long long) ([[NSDate date] timeIntervalSince1970] * 1000);
    }
    return (long long) (([[NSProcessInfo processInfo] systemUptime] + configuration.timeOffset) * 1000);
}


@end

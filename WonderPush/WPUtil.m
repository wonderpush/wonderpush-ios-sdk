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
#import "OpenUDID.h"
#import "WPConfiguration.h"

#import <sys/utsname.h>
#import <UIKit/UIApplication.h>


NSString * const WPErrorDomain = @"WPErrorDomain";
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

+ (NSString *)percentEncodedString:(NSString *)s
{
    NSMutableString *result = [[NSMutableString alloc] init];
    s = [NSString stringWithUTF8String:[s UTF8String]];
    for (int i = 0; i < s.length; i++) {
        unichar c = [s characterAtIndex:i];
        if ((c >= 'A' && c <= 'Z')
            || (c >= 'a' && c <= 'z')
            || (c >= '0' && c <= '9')
            || c == '-'
            || c == '.'
            || c == '_'
            || c == '~') {
            [result appendFormat:@"%c", c];
        } else {
            [result appendFormat:@"%%%02X", c];
        }
    }
    return [NSString stringWithString:result];
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
    return [OpenUDID value];
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


#pragma mark - UUID

+ (NSString *)UUIDString
{
    CFUUIDRef uuid = CFUUIDCreate(kCFAllocatorDefault);
    NSString *result = (NSString *)CFBridgingRelease(CFUUIDCreateString(kCFAllocatorDefault, uuid));
    CFRelease(uuid);
    return result;
}


#pragma mark - SERVER TIME

+(NSTimeInterval) getServerDate
{
    WPConfiguration *configuration = [WPConfiguration sharedConfiguration];

    if (configuration.timeOffset == 0) {
        return floor([[NSDate date] timeIntervalSince1970]*1000);
    }
    NSTimeInterval systemUptime = floor([[NSProcessInfo processInfo] systemUptime]*1000);
    return systemUptime + configuration.timeOffset;
}


@end

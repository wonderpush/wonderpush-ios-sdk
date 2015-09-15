/*
 Copyright 2015 WonderPush

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

#import "WPJsonUtil.h"

@implementation WPJsonUtil

+ (NSDictionary *)merge:(NSDictionary *)base with:(NSDictionary *)diff
{
    if (base == nil) return nil;
    if (diff == nil) return base;

    NSMutableDictionary *rtn = [base mutableCopy];
    NSString *key;

    for (key in diff) {
        id vDiff = [diff objectForKey:key];
        id vBase = [rtn objectForKey:key];
        if (vBase == nil) {
            [rtn setObject:vDiff forKey:key];
        } else if ([vDiff isKindOfClass:[NSDictionary class]] && [vBase isKindOfClass:[NSDictionary class]]) {
            [rtn setObject:[self merge:vBase with:vDiff] forKey:key];
        } else {
            [rtn setObject:vDiff forKey:key];
        }
    }

    return rtn;
}

+ (NSDictionary *)diff:(NSDictionary *)from with:(NSDictionary *)to
{
    if (from == nil) {
        if (to == nil) {
            return nil;
        } else {
            return [[NSDictionary alloc] initWithDictionary:to];
        }
    } else if (to == nil) {
        return nil;
    }

    NSMutableDictionary *rtn = [NSMutableDictionary new];
    NSString *key;

    for (key in from) {
        id vTo = [to objectForKey:key];
        if (vTo == nil) {
            [rtn setObject:[NSNull null] forKey:key];
            continue;
        }
        id vFrom = [from objectForKey:key];
        if (![vTo isEqual:vFrom]) {
            if ([vFrom isKindOfClass:[NSDictionary class]] && [vTo isKindOfClass:[NSDictionary class]]) {
                [rtn setObject:[self diff:(NSDictionary *)vFrom with:(NSDictionary *)vTo] forKey:key];
            } else {
                [rtn setObject:vTo forKey:key];
            }
        }
    }

    for (key in to) {
        id vFrom = [from objectForKey:key];
        if (vFrom != nil) continue;
        id vTo = [to objectForKey:key];
        [rtn setObject:vTo forKey:key];
    }

    return rtn;
}

@end
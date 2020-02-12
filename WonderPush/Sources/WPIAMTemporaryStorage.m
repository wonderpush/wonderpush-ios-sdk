//
//  WPIAMTemporaryStorage.m
//  WonderPush
//
//  Created by Stéphane JAIS on 13/02/2020.
//  Copyright © 2020 WonderPush. All rights reserved.
//

#import "WPIAMTemporaryStorage.h"
#import "WPIAMRuntimeManager.h"
#import "WPIAMFetchResponseParser.h"
#import "WonderPush_private.h"
#import "WPLog.h"

#define WONDERPUSH_IAM_STORAGE_KEY @"__WONDERPUSH_IAM_STORAGE_KEY"
@implementation WPIAMTemporaryStorage {
    NSMutableArray *_inApps;
}
+ (instancetype) temporaryStorage {
    static WPIAMTemporaryStorage *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [WPIAMTemporaryStorage new];
    });
    return instance;
}

- (instancetype) init {
    if (self = [super init]) {
        _inApps = [NSMutableArray new];
        NSData *data = [[NSUserDefaults standardUserDefaults] dataForKey:WONDERPUSH_IAM_STORAGE_KEY];
        if (data) {
            id JSON = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
            if ([JSON isKindOfClass:NSArray.class]) {
                [_inApps addObjectsFromArray:JSON];
            }
        }
    }
    return self;
}
- (void) handleNotification:(NSDictionary *)payload {
    if (!payload[@"_wp"]
        || ![payload[@"_wp"][@"type"] isEqualToString:@"data"]
        || ![payload[@"_wp"][@"inApp"] isKindOfClass:[NSDictionary class]]) {
        return;
    }

    @synchronized (self) {
        [_inApps addObject:payload[@"_wp"][@"inApp"]];
    }

    // Save
    NSError *error = nil;
    NSData *data = [NSJSONSerialization dataWithJSONObject:_inApps options:0 error:&error];
    if (error) {
        WPLog(@"Could not save in-app: %@", error);
    }
    if (data) {
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        [defaults setObject:data forKey:WONDERPUSH_IAM_STORAGE_KEY];
        [defaults synchronize];
    }
}

- (NSDictionary *) fetchResponse {
//        NSBundle *bundle = [WonderPush resourceBundle];
//        NSURL *storageURL = [bundle URLForResource:@"tmp" withExtension:@"json"];
//        NSString *messageJson = [NSString stringWithContentsOfURL:storageURL encoding:NSUTF8StringEncoding error:nil];
//
//        return [NSJSONSerialization JSONObjectWithData:[messageJson dataUsingEncoding:NSUTF8StringEncoding] options:0 error:nil];

    @synchronized (self) {
        return @{
            @"campaigns": _inApps,
        };
    }
}
@end

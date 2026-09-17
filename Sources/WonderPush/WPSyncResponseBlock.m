//
//  WPSyncResponseBlock.m
//  WonderPush
//
//  Copyright © 2026 WonderPush. All rights reserved.
//

#import "WPSyncResponseBlock.h"

@interface WPSyncResponseBlock ()
@property (nonatomic, strong) NSDictionary *raw;
@end

@implementation WPSyncResponseBlock

+ (instancetype)blockWithDictionary:(NSDictionary *)dict {
    if (![dict isKindOfClass:[NSDictionary class]]) return nil;
    WPSyncResponseBlock *block = [WPSyncResponseBlock new];
    block.raw = dict;
    return block;
}

/// A recognized field is present when its key exists, regardless of value (including NSNull).
- (BOOL)hasKey:(NSString *)key {
    return self.raw[key] != nil;
}

/// Returns a boxed number for a numeric field, or nil if absent or null.
- (nullable NSNumber *)numberForKey:(NSString *)key {
    id value = self.raw[key];
    return [value isKindOfClass:[NSNumber class]] ? value : nil;
}

- (BOOL)isEmpty {
    static NSArray *recognized;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        recognized = @[@"meta", @"version", @"versionId", @"readDate", @"data", @"delta",
                       @"knownVersion", @"knownVersionId", @"knownReadDate"];
    });
    for (NSString *key in recognized) {
        if ([self hasKey:key]) return NO;
    }
    return YES;
}

- (NSDictionary *)meta {
    id value = self.raw[@"meta"];
    return [value isKindOfClass:[NSDictionary class]] ? value : nil;
}

- (NSNumber *)version { return [self numberForKey:@"version"]; }
- (NSNumber *)readDate { return [self numberForKey:@"readDate"]; }
- (NSNumber *)knownVersion { return [self numberForKey:@"knownVersion"]; }
- (NSNumber *)knownReadDate { return [self numberForKey:@"knownReadDate"]; }

- (BOOL)hasVersionId { return [self hasKey:@"versionId"]; }
- (id)versionId { return self.raw[@"versionId"]; }

- (BOOL)hasData { return [self hasKey:@"data"]; }
- (id)data { return self.raw[@"data"]; }

- (BOOL)hasDelta { return [self hasKey:@"delta"]; }
- (id)delta { return self.raw[@"delta"]; }

- (BOOL)hasKnownVersionId { return [self hasKey:@"knownVersionId"]; }
- (id)knownVersionId { return self.raw[@"knownVersionId"]; }

- (NSString *)description {
    return [NSString stringWithFormat:@"<%@ %p: %@>", NSStringFromClass(self.class), self, self.raw];
}

@end

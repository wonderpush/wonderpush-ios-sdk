//
//  WPBlackWhiteList.m
//  WonderPush
//
//  Created by Stéphane JAIS on 05/10/2020.
//  Copyright © 2020 WonderPush. All rights reserved.
//

#import "WPBlackWhiteList.h"

@interface WPBlackWhiteList ()
@property (nonatomic, nonnull, strong) NSArray<NSString *> * blackList;
@property (nonatomic, nonnull, strong) NSArray<NSString *> * whiteList;
@end

@implementation WPBlackWhiteList

- (instancetype)initWithRules:(NSArray<NSString *> *)rules {
    if (self = [super init]) {
        NSMutableArray *blackList = [NSMutableArray new];
        NSMutableArray *whiteList = [NSMutableArray new];
        if ([rules isKindOfClass:NSArray.class]) {
            for (NSString *rule in rules) {
                if (![rule isKindOfClass:NSString.class]) {
                    continue;
                }
                if ([rule hasPrefix:@"-"]) [blackList addObject:[rule substringFromIndex:1]];
                else [whiteList addObject:rule];
            }
        }
        _blackList = [NSArray arrayWithArray:blackList];
        _whiteList = [NSArray arrayWithArray:whiteList];
    }
    return self;
}

- (BOOL)allow:(NSString *)item {
    for (NSString *rule in self.whiteList) {
        if ([[self class] item:item matches:rule]) return YES;
    }
    for (NSString *rule in self.blackList) {
        if ([[self class] item:item matches:rule]) return NO;
    }
    return YES;
}

+ (BOOL)item:(NSString *)item matches:(NSString *)rule {
    if (!item || !rule) return NO;
    NSArray *tokens = [rule componentsSeparatedByString:@"*"];
    NSMutableString *buffer = [NSMutableString new];
    [buffer appendString:@"^"];
    
    for (NSInteger i = 0; i < tokens.count; i++) {
        [buffer appendString:[NSRegularExpression escapedPatternForString:tokens[i]]];
        if (i < tokens.count - 1) [buffer appendString:@".*"];
    }
    [buffer appendString:@"$"];
    NSError *error = nil;
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:buffer options:0 error:&error];
    if (error) {
        return NO;
    }
    return [regex numberOfMatchesInString:item options:0 range:NSMakeRange(0, item.length)] > 0;
}

@end

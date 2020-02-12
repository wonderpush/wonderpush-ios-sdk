//
//  WPReportingData.m
//  WonderPush
//
//  Created by Stéphane JAIS on 14/02/2020.
//  Copyright © 2020 WonderPush. All rights reserved.
//

#import "WPReportingData.h"

@implementation WPReportingData
- (instancetype) initWithDictionary:(NSDictionary *)dict {
    if (self = [super init]) {
        // strip NSNull
        NSMutableDictionary *mutableDictValue = [NSMutableDictionary new];
        for (NSString *key in dict.allKeys) {
            id value = dict[key];
            if (value != [NSNull null]) mutableDictValue[key] = value;
        }
        _dictValue = [NSDictionary dictionaryWithDictionary:mutableDictValue];
    }
    return self;
}
- (NSString *) description {
    return self.dictValue.description;
}
- (NSString *) campaignId {
    NSString *result = [self.dictValue valueForKey:@"campaignId"];
    if (!result) result = [self.dictValue valueForKey:@"c"];
    return result;
}
- (NSString *) notificationId {
    NSString *result = [self.dictValue valueForKey:@"notificationId"];
    if (!result) result = [self.dictValue valueForKey:@"n"];
    return result;
}
- (NSString *) viewId {
    return [self.dictValue valueForKey:@"viewId"];
}
@end

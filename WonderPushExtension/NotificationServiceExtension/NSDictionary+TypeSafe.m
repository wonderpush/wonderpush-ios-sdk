//
//  NSDictionary+TypeSafe.m
//  WonderPush
//
//  Created by Olivier Favre on 11/07/16.
//  Copyright © 2016 WonderPush. All rights reserved.
//

#import "NSDictionary+TypeSafe.h"

@implementation NSDictionary (TypeSafe)

- (id) typesafeObjectForKey:(id)key expectClass:(Class)expectedClass
{
    id value = self[key];
    if ([value isKindOfClass:expectedClass]) {
        return value;
    }
    return nil;
}

- (id) nullsafeObjectForKey:(id)key
{
    id value = self[key];
    if (value != [NSNull null]) {
        return value;
    }
    return nil;
}


- (NSDictionary *) dictionaryForKey:(id)key
{
    return [self typesafeObjectForKey:key expectClass:[NSDictionary class]];
}

- (NSArray *) arrayForKey:(id)key
{
    return [self typesafeObjectForKey:key expectClass:[NSArray class]];
}

- (NSString *) stringForKey:(id)key
{
    return [self typesafeObjectForKey:key expectClass:[NSString class]];
}

- (NSNumber *) numberForKey:(id)key
{
    return [self typesafeObjectForKey:key expectClass:[NSNumber class]];
}

@end

//
//  NSDictionary+TypeSafe.h
//  WonderPush
//
//  Created by Olivier Favre on 11/07/16.
//  Copyright © 2016 WonderPush. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSDictionary (TypeSafe)

- (id) typesafeObjectForKey:(id)key expectClass:(Class)expectedClass;
- (id) nullsafeObjectForKey:(id)key;

- (NSDictionary *) dictionaryForKey:(id)key;
- (NSArray *) arrayForKey:(id)key;
- (NSString *) stringForKey:(id)key;
- (NSNumber *) numberForKey:(id)key;

@end

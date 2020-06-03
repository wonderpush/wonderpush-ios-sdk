//
//  WPNSUtil.h
//  WonderPush
//
//  Created by Stéphane JAIS on 03/06/2020.
//  Copyright © 2020 WonderPush. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface WPNSUtil : NSObject

///-----------------------
/// @name Percent encoding
///-----------------------

+ (NSString *) percentEncodedString:(NSString *)s;

+ (NSDictionary *)dictionaryWithFormEncodedString:(NSString *)encodedString;


///--------------
/// @name base 64
///--------------

+ (NSString*)base64forData:(NSData*)theData;


///-----------------------
/// @name Dictionary utils
///-----------------------
+ (NSDictionary *)dictionaryByFilteringNulls:(NSDictionary *)dictionary;
+ (NSArray *)arrayByFilteringNulls:(NSArray *)array;
+ (id) typesafeObjectForKey:(id)key expectClass:(Class)expectedClass inDictionary:(NSDictionary *)dictionary;
+ (id) nullsafeObjectForKey:(id)key inDictionary:(NSDictionary *)dictionary;

+ (NSDictionary *) dictionaryForKey:(id)key inDictionary:(NSDictionary *)dictionary;
+ (NSArray *) arrayForKey:(id)key inDictionary:(NSDictionary *)dictionary;
+ (NSString *) stringForKey:(id)key inDictionary:(NSDictionary *)dictionary;
+ (NSNumber *) numberForKey:(id)key inDictionary:(NSDictionary *)dictionary;

///-----------------------
/// @name NSData utils
///-----------------------
+ (NSString *) hexForData:(NSData *)data;


@end

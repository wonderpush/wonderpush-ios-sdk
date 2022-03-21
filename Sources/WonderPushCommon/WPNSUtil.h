//
//  WPNSUtil.h
//  WonderPush
//
//  Created by Stéphane JAIS on 03/06/2020.
//  Copyright © 2020 WonderPush. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface WPNSUtil : NSObject

///-----------------------
/// @name Percent encoding
///-----------------------

+ (NSString * _Nullable) percentEncodedString:(NSString * _Nullable)s;

+ (NSDictionary * _Nullable)dictionaryWithFormEncodedString:(NSString * _Nullable)encodedString;


///--------------
/// @name base 64
///--------------

+ (NSString*)base64forData:(NSData*)theData;


///-----------------------
/// @name Dictionary utils
///-----------------------
+ (NSDictionary *)dictionaryByFilteringNulls:(NSDictionary *)dictionary;
+ (NSArray *)arrayByFilteringNulls:(NSArray *)array;
+ (id _Nullable) typesafeObjectForKey:(id)key expectClass:(Class)expectedClass inDictionary:(NSDictionary * _Nullable)dictionary;
+ (id _Nullable) nullsafeObjectForKey:(id)key inDictionary:(NSDictionary * _Nullable)dictionary;

+ (NSDictionary * _Nullable) dictionaryForKey:(id)key inDictionary:(NSDictionary * _Nullable)dictionary;
+ (NSArray * _Nullable) arrayForKey:(id)key inDictionary:(NSDictionary * _Nullable)dictionary;
+ (NSString * _Nullable) stringForKey:(id)key inDictionary:(NSDictionary * _Nullable)dictionary;
+ (NSNumber * _Nullable) numberForKey:(id)key inDictionary:(NSDictionary * _Nullable)dictionary;
+ (NSNumber * _Nullable) numberForKey:(id)key inDictionary:(NSDictionary * _Nullable)dictionary defaultValue:(NSNumber *)defaultValue;

///-----------------------
/// @name NSData utils
///-----------------------
+ (NSString *) hexForData:(NSData *)data;


@end

NS_ASSUME_NONNULL_END

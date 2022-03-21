//
//  WPNSUtil.m
//  WonderPush
//
//  Created by Stéphane JAIS on 03/06/2020.
//  Copyright © 2020 WonderPush. All rights reserved.
//

#import "WPNSUtil.h"
NSCharacterSet *PercentEncodedAllowedCharacterSet = nil;

@implementation WPNSUtil

+ (void) initialize
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSMutableCharacterSet *allowed = [NSMutableCharacterSet new];
        // Allow anything that's valid in a query
        [allowed formUnionWithCharacterSet:[NSCharacterSet URLQueryAllowedCharacterSet]];
        // Allow -._~
        [allowed formUnionWithCharacterSet:[NSCharacterSet characterSetWithCharactersInString:@"-._~"]];
        // Escape :/?#[]@!$&'()*+,;=
        [allowed formIntersectionWithCharacterSet:[[NSCharacterSet characterSetWithCharactersInString:@":/?#[]@!$&'()*+,;="] invertedSet]];
        PercentEncodedAllowedCharacterSet = [allowed copy];
    });
}

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
            key = [kvp stringByRemovingPercentEncoding];
            val = @"";
        } else {
            key = [[kvp substringToIndex:pos.location] stringByRemovingPercentEncoding];
            val = [[kvp substringFromIndex:pos.location + pos.length] stringByRemovingPercentEncoding];
        }

        if (!key || !val) {
            continue; // I'm sure this will bite my arse one day
        }

        result[key] = val;
    }
    return [result copy];
}

+ (NSString *)percentEncodedString:(NSString *)string
{
    return [string stringByAddingPercentEncodingWithAllowedCharacters:PercentEncodedAllowedCharacterSet];
}

+ (id _Nullable) typesafeObjectForKey:(id)key expectClass:(Class)expectedClass inDictionary:(NSDictionary * _Nullable)dictionary
{
    id value = dictionary[key];
    if ([value isKindOfClass:expectedClass]) {
        return value;
    }
    return nil;
}

+ (id _Nullable) nullsafeObjectForKey:(id)key inDictionary:(NSDictionary * _Nullable)dictionary
{
    id value = dictionary[key];
    if (value != [NSNull null]) {
        return value;
    }
    return nil;
}


+ (NSDictionary * _Nullable) dictionaryForKey:(id)key inDictionary:(NSDictionary * _Nullable)dictionary
{
    return [self typesafeObjectForKey:key expectClass:[NSDictionary class] inDictionary:dictionary];
}

+ (NSArray * _Nullable) arrayForKey:(id)key inDictionary:(NSDictionary * _Nullable)dictionary
{
    return [self typesafeObjectForKey:key expectClass:[NSArray class] inDictionary:dictionary];
}

+ (NSString * _Nullable) stringForKey:(id)key inDictionary:(NSDictionary * _Nullable)dictionary
{
    return [self typesafeObjectForKey:key expectClass:[NSString class] inDictionary:dictionary];
}

+ (NSNumber * _Nullable) numberForKey:(id)key inDictionary:(NSDictionary * _Nullable)dictionary
{
    return [self typesafeObjectForKey:key expectClass:[NSNumber class] inDictionary:dictionary];
}

+ (NSNumber * _Nullable) numberForKey:(id)key inDictionary:(NSDictionary * _Nullable)dictionary defaultValue:(NSNumber *)defaultValue
{
    NSNumber *result = [self typesafeObjectForKey:key expectClass:[NSNumber class] inDictionary:dictionary];
    return result ?: defaultValue;
}

+ (NSDictionary *)dictionaryByFilteringNulls:(NSDictionary *)dictionary
{
    NSMutableDictionary *result = [NSMutableDictionary new];
    for (id key in [dictionary allKeys]) {
        id value = dictionary[key];
        if (value == [NSNull null]) continue;
        if ([value isKindOfClass:[NSDictionary class]]) {
            result[key] = [self dictionaryByFilteringNulls:value];
        } else if ([value isKindOfClass:[NSArray class]]) {
            result[key] = [self arrayByFilteringNulls:value];
        } else {
            result[key] = value;
        }
    }
    return [NSDictionary dictionaryWithDictionary:result];
}
+ (NSArray *)arrayByFilteringNulls:(NSArray *)array
{
    NSMutableArray *result = [NSMutableArray new];
    for (id value in array) {
        if (value == [NSNull null]) continue;
        if ([value isKindOfClass:[NSDictionary class]]) {
            [result addObject:[self dictionaryByFilteringNulls:value]];
        } else if ([value isKindOfClass:[NSArray class]]) {
            [result addObject:[self arrayByFilteringNulls:value]];
        } else {
            [result addObject:value];
        }
    }
    return [NSArray arrayWithArray:result];
}

+ (NSString *) hexForData:(NSData *)data
{
    char const * const alphabet = "0123456789abcdef";
    unsigned char const *readCursor = data.bytes;
    char *hexCString = malloc(sizeof(char) * (2 * data.length + 1));
    if (hexCString == NULL) {
        [NSException raise:@"NSInternalInconsistencyException" format:@"Failed to allocate more memory" arguments:nil];
        return nil;
    }
    char *writeCursor = hexCString;
    for (unsigned i = 0; i < data.length; ++i) {
        *(writeCursor++) = alphabet[((*readCursor & 0xF0) >> 4)];
        *(writeCursor++) = alphabet[(*readCursor & 0x0F)];
        readCursor++;
    }
    *writeCursor = '\0';
    NSString *hexString = [NSString stringWithUTF8String:hexCString];
    free(hexCString);
    return hexString;
}


@end

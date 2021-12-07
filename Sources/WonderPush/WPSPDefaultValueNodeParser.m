//
//  WPSPDefaultValueNodeParser.m
//  WonderPush
//
//  Created by Stéphane JAIS on 29/06/2020.
//  Copyright © 2020 WonderPush. All rights reserved.
//

#import "WPSPDefaultValueNodeParser.h"
#import "WPSPISO8601Duration.h"
#import "WPSPExceptions.h"
#import "WPSPGeohash.h"
#import "WPSPGeoCircle.h"
#import "WPSPGeoPolygon.h"
#import <WonderPushCommon/WPJsonUtil.h>

@implementation WPSPDefaultValueNodeParser

+ (NSDictionary<NSString *, NSNumber *> * _Nonnull) humanReadableUnitToMs {
    static NSDictionary<NSString *, NSNumber *> * rtn = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSNumber * NS_TO_MS = [NSNumber numberWithDouble:1 / 1e6];
        NSNumber * US_TO_MS = [NSNumber numberWithDouble:1 / 1e3];
        NSNumber * MS_TO_MS = [NSNumber numberWithDouble:1];
        NSNumber * SECONDS_TO_MS = [NSNumber numberWithDouble:1000];
        NSNumber * MINUTES_TO_MS = [NSNumber numberWithDouble:1000 * 60];
        NSNumber * HOURS_TO_MS = [NSNumber numberWithDouble:1000 * 60 * 60];
        NSNumber * DAYS_TO_MS = [NSNumber numberWithDouble:1000 * 60 * 60 * 24];
        NSNumber * WEEKS_TO_MS = [NSNumber numberWithDouble:1000 * 60 * 60 * 24 * 7];
        rtn = @{
            @"nanoseconds" : NS_TO_MS,
            @"nanosecond" : NS_TO_MS,
            @"nanos" : NS_TO_MS,
            @"ns" : NS_TO_MS,
            @"microseconds" : US_TO_MS,
            @"microsecond" : US_TO_MS,
            @"micros" : US_TO_MS,
            @"us" : US_TO_MS,
            @"milliseconds" : MS_TO_MS,
            @"millisecond" : MS_TO_MS,
            @"millis" : MS_TO_MS,
            @"ms" : MS_TO_MS,
            @"seconds" : SECONDS_TO_MS,
            @"second" : SECONDS_TO_MS,
            @"secs" : SECONDS_TO_MS,
            @"sec" : SECONDS_TO_MS,
            @"s" : SECONDS_TO_MS,
            @"minutes" : MINUTES_TO_MS,
            @"minute" : MINUTES_TO_MS,
            @"min" : MINUTES_TO_MS,
            @"m" : MINUTES_TO_MS,
            @"hours" : HOURS_TO_MS,
            @"hour" : HOURS_TO_MS,
            @"hr" : HOURS_TO_MS,
            @"h" : HOURS_TO_MS,
            @"days" : DAYS_TO_MS,
            @"day" : DAYS_TO_MS,
            @"d" : DAYS_TO_MS,
            @"weeks" : WEEKS_TO_MS,
            @"week" : WEEKS_TO_MS,
            @"w" : WEEKS_TO_MS,
        };
    });
    return rtn;
}

+ (NSRegularExpression *) relativeDateRegularExpression {
    static NSRegularExpression *rtn = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        rtn = [[NSRegularExpression alloc] initWithPattern:@"^[+-]?P" options:0 error:nil];
    });
    return rtn;
}

+ (NSRegularExpression *) absoluteDateRegularExpression {
    static NSRegularExpression *rtn = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        rtn = [[NSRegularExpression alloc] initWithPattern:@"^([0-9][0-9][0-9][0-9](?:-[0-9][0-9](?:-[0-9][0-9])?)?)(?:T([0-9][0-9](?::[0-9][0-9](?::[0-9][0-9](?:.[0-9][0-9][0-9])?)?)?))?(Z|[+-][0-9][0-9](?::[0-9][0-9](?::[0-9][0-9](?:.[0-9][0-9][0-9])?)?)?)?$" options:0 error:nil];
    });
    return rtn;
}

+ (NSRegularExpression *) humanReadableDurationRegularExpression {
    static NSRegularExpression *rtn = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        rtn = [[NSRegularExpression alloc] initWithPattern:@"^[ \t\n\r\v\f]*([+-]?[0-9.]+(?:[eE][+-]?[0-9]+)?)[ \t\n\r\v\f]*([a-zA-Z]*)?[ \t\n\r\v\f]*$" options:0 error:nil];
    });
    return rtn;
}

- (instancetype)init {
    if (self = [super init]) {
        [self registerExactNameParserWithKey:@"date" parser:[self.class parseDate]];
        [self registerExactNameParserWithKey:@"duration" parser:[self.class parseDuration]];
        [self registerExactNameParserWithKey:@"geolocation" parser:[self.class parseGeolocation]];
        [self registerExactNameParserWithKey:@"geobox" parser:[self.class parseGeobox]];
        [self registerExactNameParserWithKey:@"geocircle" parser:[self.class parseGeocircle]];
        [self registerExactNameParserWithKey:@"geopolygon" parser:[self.class parseGeopolygon]];
    }
    return self;
}

+ (WPSPASTValueNodeParser) parseDate {
    return VALUE_NODE_PARSER_BLOCK {
        if ([WPJsonUtil isBoolNumber:input]) @throw [WPSPBadInputException new];
        if ([input isKindOfClass:NSNumber.class]) {
            return [[WPSPDateValueNode alloc] initWithContext:context value:input];
        }
        if ([input isKindOfClass:NSString.class]) {
            NSString *stringValue = input;
            // Detect relative date
            if ([[self.class relativeDateRegularExpression] numberOfMatchesInString:stringValue options:0 range:NSMakeRange(0, stringValue.length)] > 0) {
                WPSPISO8601Duration *duration = [WPSPISO8601Duration parse:stringValue];
                return [[WPSPRelativeDateValueNode alloc] initWithContext:context duration:duration];
            }
            // Detect absolute dates
            // We're not try/catching here as we want the BadInputException to bubble up
            NSDate *parsed = [self parseAbsoluteDate:stringValue];
            if (parsed) {
                NSNumber *msSince1970 = [NSNumber numberWithDouble:parsed.timeIntervalSince1970 * 1000.0];
                return [[WPSPDateValueNode alloc] initWithContext:context value:msSince1970];
            }
        }
        
        @throw [WPSPBadInputException new];
    };
}

+ (NSDate * _Nullable) parseAbsoluteDate:(NSString *)input {
    NSArray <NSTextCheckingResult *> *matches = [self.absoluteDateRegularExpression
                                                 matchesInString:input
                                                 options:0
                                                 range:NSMakeRange(0, input.length)];
    if (!matches.count) return nil;
    if (matches.count != 1) {
        @throw [WPSPBadInputException new]; // There should be exactly one match
    }
    NSTextCheckingResult *match = matches.firstObject;
    NSString *date = [match rangeAtIndex:1].location == NSNotFound ? @"" : [input substringWithRange:[match rangeAtIndex:1]];
    NSString *time = [match rangeAtIndex:2].location == NSNotFound ? @"" : [input substringWithRange:[match rangeAtIndex:2]];
    NSString *offset = [match rangeAtIndex:3].location == NSNotFound ? @"" : [input substringWithRange:[match rangeAtIndex:3]];
    
    // Fill parts to default unspecified items
    date = [date stringByAppendingString:[@"1970-01-01" substringFromIndex:date.length]];
    time = [time stringByAppendingString:[@"00:00:00.000" substringFromIndex:time.length]];
    if ([@"Z" isEqualToString:offset]) offset = @"";
    offset = [offset stringByAppendingString:[@"+00:00.000" substringFromIndex:offset.length]];
    offset = [[offset substringWithRange:NSMakeRange(0, 6)] stringByReplacingOccurrencesOfString:@":" withString:@""];
    
    // Create fully specified date
    NSString *str = [date stringByAppendingFormat:@"T%@%@", time, offset];
    static NSDateFormatter* dateFormat = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        dateFormat = [NSDateFormatter new];
        [dateFormat setDateFormat:@"yyyy-MM-dd'T'HH:mm:ss.SSSZ"];
    });

    NSDate *result = [dateFormat dateFromString:str];
    if (!result) @throw [WPSPBadInputException new];
    return result;
}

+ (WPSPASTValueNodeParser) parseDuration {
    return VALUE_NODE_PARSER_BLOCK {
        if ([WPJsonUtil isBoolNumber:input]) @throw [WPSPBadInputException new];
        if ([input isKindOfClass:NSNumber.class]) return [[WPSPDurationValueNode alloc] initWithContext:context value:input];
        
        if ([input isKindOfClass:NSString.class]) {
            NSString *stringValue = input;
            if ([[self.class relativeDateRegularExpression] numberOfMatchesInString:stringValue options:0 range:NSMakeRange(0, stringValue.length)] > 0) {
                WPSPISO8601Duration *duration = [WPSPISO8601Duration parse:stringValue];
                return [[WPSPDurationValueNode alloc] initWithContext:context duration:duration];
            }
            // Parse a human readable duration
            NSArray <NSTextCheckingResult *> * matches = [self.humanReadableDurationRegularExpression matchesInString:stringValue options:0 range:NSMakeRange(0, stringValue.length)];
            if (matches.count == 1) {
                NSTextCheckingResult *match = matches.firstObject;
                double value = [stringValue substringWithRange:[match rangeAtIndex:1]].doubleValue;
                NSString *label = [stringValue substringWithRange:[match rangeAtIndex:2]];
                
                NSNumber * unitValueInMs = self.humanReadableUnitToMs[label];
                if (unitValueInMs) {
                    NSNumber *valueInMs = [NSNumber numberWithDouble:value * unitValueInMs.doubleValue];
                    return [[WPSPDurationValueNode alloc] initWithContext:context value:valueInMs];
                } else {
                    @throw [[WPSPBadInputException alloc] initWithReason:[NSString stringWithFormat:@"\"%@\" string values expect a valid unit", key]];
                }
            }
        }
        
        NSString *reason = [[@"\"" stringByAppendingString:key] stringByAppendingString:@"\" values expect a number or a valid string value"];
        @throw [[WPSPBadInputException alloc] initWithReason:reason];
    };
}

+ (WPSPASTValueNodeParser) parseGeolocation {
    return VALUE_NODE_PARSER_BLOCK {
        if ([input isKindOfClass:NSString.class]) {
            return [[WPSPGeoLocationValueNode alloc] initWithContext:context value:[WPSPGeohash parse:input].toGeoLocation];
        }
        
        if ([input isKindOfClass:NSDictionary.class]) {
            id lat = input[@"lat"];
            id lon = input[@"lon"];
            if ([lat isKindOfClass:NSNumber.class] && [lon isKindOfClass:NSNumber.class]) {
                return [[WPSPGeoLocationValueNode alloc]
                        initWithContext:context
                        value:[[WPSPGeoLocation alloc]
                               initWithLat:[lat doubleValue]
                               lon:[lon doubleValue]]];
            }
        }
        
        NSString *reason = [NSString stringWithFormat:@"\"%@\" values expect an object with a \"lat\" and \"lon\" numeric fields", key];
        @throw [[WPSPBadInputException alloc] initWithReason:reason];
    };
}

+ (WPSPASTValueNodeParser) parseGeobox {
    return VALUE_NODE_PARSER_BLOCK {
        if ([input isKindOfClass:NSString.class]) {
            return [[WPSPGeoBoxValueNode alloc] initWithContext:context value:[WPSPGeohash parse:input]];
        }
        
        if (![input isKindOfClass:NSDictionary.class]) {
            NSString *reason = [NSString stringWithFormat:@"\"%@\" values expect an object", key];
            @throw [[WPSPBadInputException alloc] initWithReason:reason];
        }
        
        NSDictionary *objectInput = input;
        if (objectInput[@"topLeft"] && objectInput[@"bottomRight"]) {
            WPSPGeoLocationValueNode *topLeft = (WPSPGeoLocationValueNode *)self.parseGeolocation(context, @"geolocation", objectInput[@"topLeft"]);
            WPSPGeoLocationValueNode *bottomRight = (WPSPGeoLocationValueNode *)self.parseGeolocation(context, @"geolocation", objectInput[@"bottomRight"]);
            WPSPGeoBox *geoBox = [[WPSPGeoBox alloc] initWithTop:topLeft.value.lat right:bottomRight.value.lon bottom:bottomRight.value.lat left:topLeft.value.lon];
            return [[WPSPGeoBoxValueNode alloc] initWithContext:context value:geoBox];
        }

        if (objectInput[@"topRight"] && objectInput[@"bottomLeft"]) {
            WPSPGeoLocationValueNode *topRight = (WPSPGeoLocationValueNode *)self.parseGeolocation(context, @"geolocation", objectInput[@"topRight"]);
            WPSPGeoLocationValueNode *bottomLeft = (WPSPGeoLocationValueNode *)self.parseGeolocation(context, @"geolocation", objectInput[@"bottomLeft"]);
            WPSPGeoBox *geoBox = [[WPSPGeoBox alloc] initWithTop:topRight.value.lat right:topRight.value.lon bottom:bottomLeft.value.lat left:bottomLeft.value.lon];
            return [[WPSPGeoBoxValueNode alloc] initWithContext:context value:geoBox];
        }

        id top = objectInput[@"top"];
        id right = objectInput[@"right"];
        id bottom = objectInput[@"bottom"];
        id left = objectInput[@"left"];
        if ([top isKindOfClass:NSNumber.class]
            && [right isKindOfClass:NSNumber.class]
            && [bottom isKindOfClass:NSNumber.class]
            && [left isKindOfClass:NSNumber.class]) {
            
            WPSPGeoBox *geoBox = [[WPSPGeoBox alloc]
                                  initWithTop:[top doubleValue]
                                  right:[right doubleValue]
                                  bottom:[bottom doubleValue]
                                  left:[left doubleValue]];
            return [[WPSPGeoBoxValueNode alloc] initWithContext:context value:geoBox];
        }

        NSString *reason = [NSString stringWithFormat:@"\"%@\" did not receive an object with a handled format", key];
        @throw [[WPSPBadInputException alloc] initWithReason:reason];
    };
}

+ (WPSPASTValueNodeParser) parseGeocircle {
    return VALUE_NODE_PARSER_BLOCK {
        if (![input isKindOfClass:NSDictionary.class]) {
            NSString *reason = [NSString stringWithFormat:@"\"%@\" values expect an object", key];
            @throw [[WPSPBadInputException alloc] initWithReason:reason];
        }
        
        NSDictionary *objectInput = input;
        NSNumber *radius = objectInput[@"radius"];
        if (![radius isKindOfClass:NSNumber.class]) {
            NSString *reason = [NSString stringWithFormat:@"\"%@\" needs a radius numeric field", key];
            @throw [[WPSPBadInputException alloc] initWithReason:reason];
        }
        
        id center = objectInput[@"center"];
        if (!center) {
            NSString *reason = [NSString stringWithFormat:@"\"%@\" did not receive an object with a handled format", key];
            @throw [[WPSPBadInputException alloc] initWithReason:reason];
        }
        
        WPSPGeoLocationValueNode *centerValueNode = (WPSPGeoLocationValueNode *)self.parseGeolocation(context, @"geolocation", center);
        WPSPGeoCircle *geoCircle = [[WPSPGeoCircle alloc] initWithCenter:centerValueNode.value radiusMeters:radius.doubleValue];
        return [[WPSPGeoCircleValueNode alloc] initWithContext:context value:geoCircle];
    };
}

+ (WPSPASTValueNodeParser) parseGeopolygon {
    return VALUE_NODE_PARSER_BLOCK {
        if (![input isKindOfClass:NSArray.class] || [input count] <3) {
            NSString *reason = [NSString stringWithFormat:@"\"%@\" values expect an array of at least 3 geolocations", key];
            @throw [[WPSPBadInputException alloc] initWithReason:reason];
        }
        
        NSArray *arrayInput = input;
        NSInteger length = arrayInput.count;
        NSMutableArray <WPSPGeoLocation *> * points = [[NSMutableArray alloc] initWithCapacity:length];
        for (NSInteger i = 0; i < length; i++) {
            WPSPGeoLocationValueNode *geoLocationValueNode = (WPSPGeoLocationValueNode *)self.parseGeolocation(context, @"geolocation", arrayInput[i]);

            [points addObject:geoLocationValueNode.value];
        }
        WPSPGeoPolygon *polygon = [[WPSPGeoPolygon alloc] initWithPoints:points];
        return [[WPSPGeoPolygonValueNode alloc] initWithContext:context value:polygon];
        
    };
}
@end

//
//  WPSPSegmenter.m
//  WonderPush
//
//  Created by Olivier Favre on 7/6/20.
//  Copyright © 2020 WonderPush. All rights reserved.
//

#import "WPSPSegmenter.h"
#import "WPSPSegmentationDSLParser.h"
#import "WPSPDefaultValueNodeParser.h"
#import "WPLog.h"
#import "WPUtil.h"
#import "WPNSUtil.h"
#import "WPJsonUtil.h"
#import "WPJsonSyncInstallation.h"
#import "WPConfiguration.h"
#import "WonderPush_private.h"

@implementation WPSPSegmenterPresenceInfo

- (instancetype)initWithFromDate:(long long)fromDate untilDate:(long long)untilDate elapsedTime:(long long)elapsedTime {
    if (self = [super init]) {
        _fromDate = fromDate;
        _untilDate = untilDate;
        _elapsedTime = elapsedTime;
    }
    return self;
}

@end

@implementation WPSPSegmenterData

+ (instancetype)forCurrentUser {
    NSDictionary *installationData = [WPJsonSyncInstallation forCurrentUser].sdkState;
    NSArray <NSDictionary *> *events = WPConfiguration.sharedConfiguration.trackedEvents;
    WPConfiguration *configuration = WPConfiguration.sharedConfiguration;
    
    WPPresencePayload *presence = [[WonderPush presenceManager] lastPresencePayload];
    WPSPSegmenterPresenceInfo *presenceInfo = presence ? [[WPSPSegmenterPresenceInfo alloc] initWithFromDate:(long long)(presence.fromDate.timeIntervalSince1970 * 1000) untilDate:(long long)(presence.untilDate.timeIntervalSince1970 * 1000) elapsedTime:(long long)(presence.elapsedTime * 1000)] : nil;
    
    NSDate *lastAppOpenDate = configuration.lastAppOpenDate;
    WPSPSegmenterData *data = [[WPSPSegmenterData alloc]
                               initWithInstallation:installationData
                               allEvents:events
                               presenceInfo:presenceInfo
                               lastAppOpenDate:(long long)(lastAppOpenDate.timeIntervalSince1970 * 1000)];
    return data;
}

- (instancetype)initWithInstallation:(NSDictionary *)installation allEvents:(NSArray<NSDictionary *> *)allEvents presenceInfo:(WPSPSegmenterPresenceInfo * _Nullable)presenceInfo lastAppOpenDate:(long long)lastAppOpenDate {
    if (self = [super init]) {
        _installation = installation;
        _allEvents = [NSArray arrayWithArray:allEvents];
        _presenceInfo = presenceInfo;
        _lastAppOpenDate = lastAppOpenDate;
    }
    return self;
}

@end

@implementation WPSPSegmenter

- (instancetype)initWithData:(WPSPSegmenterData *)data {
    if (self = [super init]) {
        _data = data;
    }
    return self;
}

+ (WPSPASTCriterionNode *)parseInstallationSegment:(NSDictionary *)segmentInput {
    return [[WPSPSegmentationDSLParser defaultParser] parse:segmentInput dataSource:[WPSPInstallationSource new]];
}

- (BOOL)parsedSegmentMatchesInstallation:(WPSPASTCriterionNode *)parsedInstallationSegment {
    id rtn = [parsedInstallationSegment accept:[[WPSPInstallationVisitor alloc] initWithData:self.data]];
    if ([rtn isKindOfClass:NSNumber.class]) {
        return [rtn boolValue];
    }
    return NO;
}

@end

@implementation WPSPInstallationVisitor

- (id)visitFieldSource:(WPSPFieldSource *)dataSource {
    return [super visitFieldSource:dataSource withObject:self.data.installation];
}

@end

@implementation WPSPEventVisitor

- (instancetype)initWithData:(WPSPSegmenterData *)data event:(NSDictionary *)event {
    if (self = [super initWithData:data]) {
        _event = event;
    }
    return self;
}

- (id)visitFieldSource:(WPSPFieldSource *)dataSource {
    return [super visitFieldSource:dataSource withObject:self.event];
}

@end

@interface WPSPBaseVisitor ()

@property (nonatomic, assign, readonly) BOOL debug;

@end

@implementation WPSPBaseVisitor

- (instancetype)initWithData:(WPSPSegmenterData *)data {
    if (self = [super init]) {
        _debug = WPLogEnabled();
        _data = data;
    }
    return self;
}

///
/// WPSPASTValueVisitor
///

- (nonnull id)visitASTUnknownValueNode:(nonnull WPSPASTUnknownValueNode *)node {
    WPLog(@"Unsupported unknown value of type %@ with value %@", node.key, node.value);
    return [NSNull null];
}

- (nonnull id)visitBooleanValueNode:(nonnull WPSPBooleanValueNode *)node {
    return node.value;
}

- (nonnull id)visitNullValueNode:(nonnull WPSPNullValueNode *)node {
    return node.value;
}

- (nonnull id)visitNumberValueNode:(nonnull WPSPNumberValueNode *)node {
    return node.value;
}

- (nonnull id)visitStringValueNode:(nonnull WPSPStringValueNode *)node {
    return node.value;
}

-(nonnull id) visitDateValueNode:(WPSPDateValueNode *)node {
    return node.value;
}

-(nonnull id) visitRelativeDateValueNode:(WPSPRelativeDateValueNode *)node {
    return [NSNumber numberWithLongLong:([node.duration applyTo:[NSDate dateWithTimeIntervalSince1970:(WPUtil.getServerDate / 1000.0)]].timeIntervalSince1970 * 1000)];
}

-(nonnull id) visitDurationValueNode:(WPSPDurationValueNode *)node {
    return node.value;
}

-(nonnull id) visitGeoLocationValueNode:(WPSPGeoLocationValueNode *)node {
    return node.value;
}

-(nonnull id) visitGeoBoxValueNode:(WPSPGeoBoxValueNode *)node {
    return node.value;
}

-(nonnull id) visitGeoCircleValueNode:(WPSPGeoCircleValueNode *)node {
    return node.value;
}

-(nonnull id) visitGeoPolygonValueNode:(WPSPGeoPolygonValueNode *)node {
    return node.value;
}

///
/// WPSPASTCriterionVisitor
///

- (nonnull id)visitASTUnknownCriterionNode:(nonnull WPSPASTUnknownCriterionNode *)node {
    WPLog(@"Unsupported unknown criterion %@ with value %@", node.key, node.value);
    return @NO;
}

- (nonnull id)visitMatchAllCriterionNode:(nonnull WPSPMatchAllCriterionNode *)node {
    if (_debug) WPLog(@"[%@] return true", NSStringFromSelector(_cmd));
    return @YES;
}

- (nonnull id)visitAndCriterionNode:(nonnull WPSPAndCriterionNode *)node {
    for (WPSPASTCriterionNode *child in node.children) {
        if (!((NSNumber *)[child accept:self]).boolValue) {
            if (_debug) WPLog(@"[%@] return false because %@ is false", NSStringFromSelector(_cmd), child);
            return @NO;
        }
    }
    if (_debug) WPLog(@"[%@] return true", NSStringFromSelector(_cmd));
    return @YES;
}

- (nonnull id)visitOrCriterionNode:(nonnull WPSPOrCriterionNode *)node {
    for (WPSPASTCriterionNode *child in node.children) {
        if (((NSNumber *)[child accept:self]).boolValue) {
            if (_debug) WPLog(@"[%@] return true because %@ is true", NSStringFromSelector(_cmd), child);
            return @YES;
        }
    }
    if (_debug) WPLog(@"[%@] return false", NSStringFromSelector(_cmd));
    return @NO;
}

- (nonnull id)visitNotCriterionNode:(nonnull WPSPNotCriterionNode *)node {
    NSNumber *rtn = [NSNumber numberWithBool:!((NSNumber *)[node.child accept:self]).boolValue];
    if (_debug) WPLog(@"[%@] return %@", NSStringFromSelector(_cmd), rtn);
    return rtn;
}

- (nonnull id)visitAllCriterionNode:(nonnull WPSPAllCriterionNode *)node {
    NSArray<id> *dataSourceValues = [node.context.dataSource accept:self];
    if (![dataSourceValues isKindOfClass:NSArray.class]) {
        WPLog(@"[%@] Unexpected dataSourceValues: %@", NSStringFromSelector(_cmd), dataSourceValues);
    }
    for (WPSPASTValueNode *value in node.values) {
        BOOL found = NO;
        id actualValue = [value accept:self];
        if (actualValue == nil || [[NSNull null] isEqual:actualValue]) {
            if (dataSourceValues.count == 0) {
                found = YES;
            }
        } else {
            for (id dataSourceValue in dataSourceValues) {
                if ([actualValue isEqual:dataSourceValue]) {
                    found = true;
                    break;
                }
            }
        }
        if (!found) {
            if (_debug) WPLog(@"[%@] return false because %@ is not contained in %@", NSStringFromSelector(_cmd), actualValue, dataSourceValues);
            return @NO;
        }
    }
    if (_debug) WPLog(@"[%@] return true for %@", NSStringFromSelector(_cmd), dataSourceValues);
    return @YES;
}

- (nonnull id)visitAnyCriterionNode:(nonnull WPSPAnyCriterionNode *)node {
    NSArray<id> *dataSourceValues = [node.context.dataSource accept:self];
    if (![dataSourceValues isKindOfClass:NSArray.class]) {
        WPLog(@"[%@] Unexpected dataSourceValues: %@", NSStringFromSelector(_cmd), dataSourceValues);
    }
    for (WPSPASTValueNode *value in node.values) {
        id actualValue = [value accept:self];
        if (actualValue == nil || [[NSNull null] isEqual:actualValue]) {
            if (dataSourceValues.count == 0) {
                if (_debug) WPLog(@"[%@] return true for %@", NSStringFromSelector(_cmd), dataSourceValues);
                return @YES;
            }
        }
        for (id dataSourceValue in dataSourceValues) {
            if ([actualValue isEqual:dataSourceValue]) {
                if (_debug) WPLog(@"[%@] return true for %@", NSStringFromSelector(_cmd), dataSourceValues);
                return @YES;
            }
        }
    }
    if (_debug) WPLog(@"[%@] return false for %@", NSStringFromSelector(_cmd), dataSourceValues);
    return @NO;
}

NSComparisonResult compareObjectOrThrow(id a, id b) {
    if ([[NSNull null] isEqual:a]) a = nil;
    if ([[NSNull null] isEqual:b]) b = nil;
    if (a == nil && b == nil) return 0;
    if (a == nil) return -compareObjectOrThrow(b, nil);
    // Now a is non nil, we'll compare depending on its type, and take an appropriate zero-value for b if it is nil
    if ([a isKindOfClass:NSNumber.class] && [WPJsonUtil isBoolNumber:a]) {
        if (b == nil) b = @NO;
        if ([b isKindOfClass:NSNumber.class] && [WPJsonUtil isBoolNumber:b]) {
            return [((NSNumber *)a) compare:b];
        }
    } else if ([a isKindOfClass:NSNumber.class]) {
        if (b == nil) b = @0;
        if ([b isKindOfClass:NSNumber.class]) {
            return [((NSNumber *)a) compare:b];
        }
    } else if ([a isKindOfClass:NSString.class]) {
        if (b == nil) b = @"";
        if ([b isKindOfClass:NSString.class]) {
            return [((NSString *)a) compare:b];
        }
    }
    @throw @"cannot compare the given types";
}

- (nonnull id)visitComparisonCriterionNode:(nonnull WPSPComparisonCriterionNode *)node {
    NSArray<id> *dataSourceValues = [node.context.dataSource accept:self];
    if (![dataSourceValues isKindOfClass:NSArray.class]) {
        WPLog(@"[%@] Unexpected dataSourceValues: %@", NSStringFromSelector(_cmd), dataSourceValues);
    }
    BOOL result = NO;
    id actualValue = [node.value accept:self];
    for (WPSPASTValueNode *dataSourceValue in dataSourceValues) {
        @try {
            NSComparisonResult comparison = compareObjectOrThrow(dataSourceValue, actualValue);
            if (node.comparator == WPSPComparatorGt) {
                result = comparison == NSOrderedDescending;
            } else if (node.comparator == WPSPComparatorGte) {
                result = comparison != NSOrderedAscending;
            } else if (node.comparator == WPSPComparatorLt) {
                result = comparison == NSOrderedAscending;
            } else if (node.comparator == WPSPComparatorLte) {
                result = comparison != NSOrderedDescending;
            }
        } @catch (id ignored) {}
        if (result) {
            break;
        }
    }
    if (_debug) {
        NSString *comparatorStr = @"??";
        if (node.comparator == WPSPComparatorGt) comparatorStr = @"gt";
        else if (node.comparator == WPSPComparatorGte) comparatorStr = @"gte";
        else if (node.comparator == WPSPComparatorLt) comparatorStr = @"lt";
        else if (node.comparator == WPSPComparatorLte) comparatorStr = @"lte";
        WPLog(@"[%@] return %@ because %@ %@ %@ %@", NSStringFromSelector(_cmd), result ? @"true" : @"false", dataSourceValues, result ? @"is" : @"is not", comparatorStr, actualValue);
    }
    return result ? @YES : @NO;
}

- (nonnull id)visitEqualityCriterionNode:(nonnull WPSPEqualityCriterionNode *)node {
    NSArray<id> *dataSourceValues = [node.context.dataSource accept:self];
    if (![dataSourceValues isKindOfClass:NSArray.class]) {
        WPLog(@"[%@] Unexpected dataSourceValues: %@", NSStringFromSelector(_cmd), dataSourceValues);
    }
    id actualValue = [node.value accept:self];
    if (actualValue == nil || [[NSNull null] isEqual:actualValue]) {
        return dataSourceValues.count == 0 ? @YES : @NO;
    }
    BOOL result = NO;
    for (id dataSourceValue in dataSourceValues) {
        if (!dataSourceValue || [dataSourceValue isKindOfClass:NSNull.class]) continue;
        if (([actualValue isKindOfClass:NSNumber.class] && [WPJsonUtil isBoolNumber:actualValue]) || ([dataSourceValue isKindOfClass:NSNumber.class] && [WPJsonUtil isBoolNumber:dataSourceValue])) {
            if ([actualValue isKindOfClass:NSNumber.class] && [WPJsonUtil isBoolNumber:actualValue] && [dataSourceValue isKindOfClass:NSNumber.class] && [WPJsonUtil isBoolNumber:dataSourceValue]) {
                result = ((NSNumber *)actualValue).boolValue == ((NSNumber *)dataSourceValue).boolValue;
            } else {
                result = NO;
            }
        } else if ([actualValue isKindOfClass:NSNumber.class]) {
            if ([dataSourceValue isKindOfClass:NSNumber.class]) {
                result = [actualValue isEqual:dataSourceValue];
            } else {
                result = NO;
            }
        } else {
            result = [actualValue isEqual:dataSourceValue];
        }
        if (result) break;
    }
    if (_debug) WPLog(@"[%@] return %@ because %@ %@ %@", NSStringFromSelector(_cmd), result ? @"true" : @"false", dataSourceValues, result ? @"==" : @"!=", actualValue);
    return result ? @YES : @NO;
}

- (nonnull id)visitGeoCriterionNode:(nonnull WPSPGeoCriterionNode *)node {
    if (_debug) WPLog(@"[%@] unsupported", NSStringFromSelector(_cmd));
    return @NO;
}

- (nonnull id)visitInsideCriterionNode:(nonnull WPSPInsideCriterionNode *)node {
    if (_debug) WPLog(@"[%@] unsupported", NSStringFromSelector(_cmd));
    return @NO;
}

- (nonnull id)visitJoinCriterionNode:(nonnull WPSPJoinCriterionNode *)node {
    if ([node.context.dataSource isKindOfClass:WPSPEventSource.class]) {
        for (NSDictionary *event in self.data.allEvents) {
            WPSPEventVisitor *eventVisitor = [[WPSPEventVisitor alloc] initWithData:self.data event:event];
            if (((NSNumber *)[node.child accept:eventVisitor]).boolValue) {
                return @YES;
            }
        }
        return @NO;
    }
    if ([node.context.dataSource isKindOfClass:WPSPInstallationSource.class]) {
        WPSPInstallationVisitor *installationVisitor = [[WPSPInstallationVisitor alloc] initWithData:self.data];
        return [node.child accept:installationVisitor];
    }
    WPLog(@"[%@] return false for unsupported %@", NSStringFromSelector(_cmd), NSStringFromClass(node.context.dataSource.class));
    return @NO;
}

- (nonnull id)visitLastActivityDateCriterionNode:(nonnull WPSPLastActivityDateCriterionNode *)node {
    if (node.dateComparison == nil) {
        return self.data.lastAppOpenDate > 0 ? @YES : @NO;
    }
    return [node.dateComparison accept:self];
}

- (nonnull id)visitPrefixCriterionNode:(nonnull WPSPPrefixCriterionNode *)node {
    NSArray<id> *dataSourceValues = [node.context.dataSource accept:self];
    if (![dataSourceValues isKindOfClass:NSArray.class]) {
        WPLog(@"[%@] Unexpected dataSourceValues: %@", NSStringFromSelector(_cmd), dataSourceValues);
    }
    NSString *actualValue = [node.value accept:self];
    if (![actualValue isKindOfClass:NSString.class]) {
        WPLog(@"[%@] value %@ is not a string", NSStringFromSelector(_cmd), actualValue);
        return @NO;
    }
    BOOL result = NO;
    for (id dataSourceValue in dataSourceValues) {
        if (![dataSourceValue isKindOfClass:NSString.class]) {
            WPLog(@"[%@] value %@ is not a string", NSStringFromSelector(_cmd), dataSourceValue);
            continue;
        }
        result = [((NSString *)dataSourceValue) hasPrefix:actualValue];
        if (result) break;
    }
    if (_debug) WPLog(@"[%@] return %@ because %@ %@ %@", NSStringFromSelector(_cmd), result ? @"true" : @"false", dataSourceValues, result ? @"starts with" : @"does not start with", actualValue);
    return result ? @YES : @NO;
}

- (nonnull id)visitPresenceCriterionNode:(nonnull WPSPPresenceCriterionNode *)node {
    // Are we present right now?
    BOOL present = self.data.presenceInfo == nil || (self.data.presenceInfo.untilDate >= [WPUtil getServerDate] && self.data.presenceInfo.fromDate <= [WPUtil getServerDate]);
    if (present != node.present) {
        if (_debug) WPLog(@"[%@] return false because presence mismatch, expected %@", NSStringFromSelector(_cmd), node.present ? @"present" : @"absent");
        return @NO;
    }
    
    if (node.elapsedTimeComparison != nil && !((NSNumber *)[node.elapsedTimeComparison accept:self]).boolValue) {
        if (_debug) WPLog(@"[%@] return false because elapsedTime mismatch", NSStringFromSelector(_cmd));
        return @NO;
    }
    if (node.sinceDateComparison != nil && !((NSNumber *)[node.sinceDateComparison accept:self]).boolValue) {
        if (_debug) WPLog(@"[%@] return false because sinceDate mismatch", NSStringFromSelector(_cmd));
        return @NO;
    }
    if (_debug) WPLog(@"[%@] return true", NSStringFromSelector(_cmd));
    return @YES;
}

- (nonnull id)visitSubscriptionStatusCriterionNode:(nonnull WPSPSubscriptionStatusCriterionNode *)node {
    NSString *pushTokenData = [WPNSUtil stringForKey:@"data" inDictionary:[WPNSUtil dictionaryForKey:@"pushToken" inDictionary:self.data.installation]];
    BOOL hasPushToken = [pushTokenData isKindOfClass:NSString.class] && [(NSString *)pushTokenData length] > 0;
    NSString *preferencesSubscriptionStatus = [WPNSUtil stringForKey:@"subscriptionStatus" inDictionary:[WPNSUtil dictionaryForKey:@"preferences" inDictionary:self.data.installation]];
    WPSPSubscriptionStatus actualStatus;
    if (!hasPushToken) {
        actualStatus = WPSPSubscriptionStatusOptOut;
    } else if ([@"optOut" isEqual:preferencesSubscriptionStatus]) {
        actualStatus = WPSPSubscriptionStatusSoftOptOut;
    } else {
        actualStatus = WPSPSubscriptionStatusOptIn;
    }
    return node.subscriptionStatus == actualStatus ? @YES : @NO;
}

///
/// WPSPDataSourceVisitor
///

- (nonnull id)visitEventSource:(nonnull WPSPEventSource *)dataSource {
    return @[];
}

// The following method is voluntarily left for subclasses,
// which should call [visitFieldSource:withObject:] with the right object.
//- (nonnull id)visitFieldSource:(nonnull WPSPFieldSource *)dataSource {
//}

- (NSArray<id> *)visitFieldSource:(WPSPFieldSource *)dataSource withObject:(NSDictionary *)object {
    WPSPFieldPath *fieldPath = dataSource.fullPath;
    id curr = object;
    for (NSString *part in fieldPath.parts) {
        if ([curr isKindOfClass:NSDictionary.class]) {
            curr = curr[part];
        } else if ([curr isKindOfClass:NSArray.class]) {
            NSInteger index = -1;
            if ([[NSScanner scannerWithString:part] scanInteger:&index]) {
                curr = curr[index];
            } else {
                curr = nil;
            }
        } else {
            curr = nil;
        }
    }
    NSArray<id> *rtn;
    if ([curr isKindOfClass:NSArray.class]) {
        // Ignore nulls
        NSExpression *lhs = [NSExpression expressionForEvaluatedObject];
        NSExpression *rhs = [NSExpression expressionForConstantValue:[NSNull null]];
        NSPredicate *filterDifferent = [NSComparisonPredicate predicateWithLeftExpression:lhs rightExpression:rhs modifier:NSDirectPredicateModifier type:NSNotEqualToPredicateOperatorType options:0];
        rtn = [curr filteredArrayUsingPredicate:filterDifferent];
    } else if (curr == nil || [[NSNull null] isEqual:curr]) {
        rtn = @[];
    } else {
        rtn = @[curr];
    }
    if (fieldPath.parts.count >= 2 && [@"custom" isEqualToString:fieldPath.parts[0]] && [fieldPath.parts.lastObject hasPrefix:@"date_"]) {
        NSMutableArray<id> *parsedDates = [NSMutableArray arrayWithCapacity:rtn.count];
        for (id item in rtn) {
            id itemToAdd = item;
            if ([item isKindOfClass:NSString.class]) {
                @try {
                    NSDate *parsed = [WPSPDefaultValueNodeParser parseAbsoluteDate:(NSString *)item];
                    if (parsed) {
                        itemToAdd = [NSNumber numberWithLongLong:(long long)(parsed.timeIntervalSince1970) * 1000LL];
                    }
                } @catch (id ignored) {}
            }
            [parsedDates addObject:itemToAdd];
        }
        rtn = [NSArray arrayWithArray:parsedDates];
    }
    return rtn;
}

- (nonnull id)visitGeoDateSource:(nonnull WPSPGeoDateSource *)dataSource {
    // TODO Implement geo
    return @[];
}

- (nonnull id)visitGeoLocationSource:(nonnull WPSPGeoLocationSource *)dataSource {
    // TODO Implement geo
    return @[];
}

- (nonnull id)visitInstallationSource:(nonnull WPSPInstallationSource *)dataSource {
    return @[];
}

- (nonnull id)visitLastActivityDateSource:(nonnull WPSPLastActivityDateSource *)dataSource {
    return @[
        [NSNumber numberWithLongLong:self.data.lastAppOpenDate],
    ];
}

- (nonnull id)visitPresenceElapsedTimeSource:(nonnull WPSPPresenceElapsedTimeSource *)dataSource {
    if (dataSource.present) {
        return @[
            [NSNumber numberWithLongLong:(self.data.presenceInfo == nil ? 0 : MAX(0, [WPUtil getServerDate] - self.data.presenceInfo.fromDate))],
        ];
    }
    return @[
        [NSNumber numberWithLongLong:(self.data.presenceInfo == nil ? 0 : self.data.presenceInfo.elapsedTime)],
    ];
}

- (nonnull id)visitPresenceSinceDateSource:(nonnull WPSPPresenceSinceDateSource *)dataSource {
    // Note: with in-apps, if we're running this, we're present.
    if (dataSource.present) {
        // When presence info is missing, assume the user just got here.
        return @[
            [NSNumber numberWithLongLong:(self.data.presenceInfo == nil ? [WPUtil getServerDate] : self.data.presenceInfo.fromDate)],
        ];
    }
    // When presence info is missing, assume the user will stay here indefinitely (yay!).
    return @[
        [NSNumber numberWithLongLong:(self.data.presenceInfo == nil ? LONG_LONG_MAX : self.data.presenceInfo.untilDate)],
    ];
}

- (nonnull id)visitUserSource:(nonnull WPSPUserSource *)dataSource {
    return @[];
}

- (nonnull id)visitFieldSource:(nonnull WPSPFieldSource *)dataSource {
    @throw [NSException exceptionWithName:NSInternalInconsistencyException reason:[NSString stringWithFormat:@"%@ must be overridden", NSStringFromSelector(_cmd)] userInfo:nil];
}


@end

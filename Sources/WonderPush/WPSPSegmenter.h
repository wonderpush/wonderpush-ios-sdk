//
//  WPSPSegmenter.h
//  WonderPush
//
//  Created by Olivier Favre on 7/6/20.
//  Copyright © 2020 WonderPush. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "WPSPASTCriterionNode.h"
#import "WPSPASTCriterionVisitor.h"
#import "WPSPASTValueVisitor.h"
#import "WPSPDataSourceVisitor.h"

NS_ASSUME_NONNULL_BEGIN

@interface WPSPSegmenterPresenceInfo : NSObject

@property (nonatomic, assign, readonly) long long fromDate;
@property (nonatomic, assign, readonly) long long untilDate;
@property (nonatomic, assign, readonly) long long elapsedTime;

- (instancetype)initWithFromDate:(long long)fromDate untilDate:(long long)untilDate elapsedTime:(long long)elapsedTime;

@end

@interface WPSPSegmenterData : NSObject

@property (nonnull, readonly) NSDictionary *installation;
@property (nonnull, readonly) NSArray<NSDictionary *> *allEvents;
@property (nullable, readonly) WPSPSegmenterPresenceInfo *presenceInfo;
@property (nonatomic, assign, readonly) long long lastAppOpenDate;
/// The synced contact object (sdk-sync `contact` source), or nil. Consumed by `contact` segmentation
/// criteria — a distinct namespace from installation/user. Injected after construction by
/// forCurrentUser (readwrite so it can be set without changing the init signature / callers).
@property (nonatomic, nullable) NSDictionary *contact;

+ (instancetype)forCurrentUser;
- (instancetype)initWithInstallation:(NSDictionary *)installation allEvents:(NSArray<NSDictionary *> *)allEvents presenceInfo:(WPSPSegmenterPresenceInfo * _Nullable)presenceInfo lastAppOpenDate:(long long)lastAppOpenDate;

@end

@interface WPSPSegmenter : NSObject

@property (nonnull, readonly) WPSPSegmenterData *data;

+ (WPSPASTCriterionNode *)parseInstallationSegment:(NSDictionary *)segmentInput;

- (instancetype)initWithData:(WPSPSegmenterData *)data;

- (BOOL)parsedSegmentMatchesInstallation:(WPSPASTCriterionNode *)parsedInstallationSegment;

/// Coerces a raw field value (number, ISO8601/RFC3339 string, or anything else) to a unix timestamp
/// in ms, the same way WPSPDefaultValueNodeParser's "date" parser does for `date` value nodes. Lets
/// any field be compared against an explicit date value regardless of how it was stored, without
/// relying on a naming convention. Values that can't be parsed as dates are returned unchanged, so
/// the comparison simply won't match.
+ (id)coerceToDateValue:(WPSPParsingContext *)context input:(id)input;

@end

@interface WPSPBaseVisitor : NSObject <WPSPASTCriterionVisitor, WPSPASTValueVisitor, WPSPDataSourceVisitor>

@property (nonnull, readonly) WPSPSegmenterData *data;

- (instancetype)initWithData:(WPSPSegmenterData *)data;

- (NSArray<id> *)visitFieldSource:(WPSPFieldSource *)dataSource withObject:(NSDictionary *)object;

@end

@interface WPSPInstallationVisitor : WPSPBaseVisitor

@end

@interface WPSPEventVisitor : WPSPBaseVisitor

@property (nonnull, readonly) NSDictionary *event;

- (instancetype)initWithData:(WPSPSegmenterData *)data event:(NSDictionary *)event;

@end

@interface WPSPContactVisitor : WPSPBaseVisitor

@end

NS_ASSUME_NONNULL_END

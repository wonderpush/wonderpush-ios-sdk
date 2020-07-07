//
//  WPSPSegmenterTests.m
//  WonderPushExampleTests
//
//  Created by Olivier Favre on 7/7/20.
//  Copyright © 2020 WonderPush. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "WPSPSegmenter.h"

@interface WPSPSegmenterTests : XCTestCase

@end

static WPSPSegmenterData * _Nonnull emptyData = nil;

@interface WPSPSegmenterData (private)

- (WPSPSegmenterData *) withInstallation:(NSDictionary *)installation;

@end

@implementation WPSPSegmenterData (private)

- (WPSPSegmenterData *) withInstallation:(NSDictionary *)installation {
    return [[WPSPSegmenterData alloc] initWithInstallation:installation allEvents:self.allEvents presenceInfo:self.presenceInfo lastAppOpenDate:self.lastAppOpenDate];
}

@end

@implementation WPSPSegmenterTests

+ (void) initialize {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        emptyData = [[WPSPSegmenterData alloc] initWithInstallation:@{} allEvents:@[] presenceInfo:nil lastAppOpenDate:0];
    });
}

+ (WPSPSegmenterData *) data:(WPSPSegmenterData *)data withInstallation:(NSDictionary *)installation {
    return [[WPSPSegmenterData alloc] initWithInstallation:installation allEvents:data.allEvents presenceInfo:data.presenceInfo lastAppOpenDate:data.lastAppOpenDate];
}

- (void) testItShouldMatchAll {
    WPSPSegmenter *s = [[WPSPSegmenter alloc] initWithData:emptyData];
    WPSPASTCriterionNode *parsedSegment = [WPSPSegmenter parseInstallationSegment:@{}];
    XCTAssertTrue([s parsedSegmentMatchesInstallation:parsedSegment]);
}

@end

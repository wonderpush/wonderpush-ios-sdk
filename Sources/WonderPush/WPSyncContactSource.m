//
//  WPSyncContactSource.m
//  WonderPush
//
//  Copyright © 2026 WonderPush. All rights reserved.
//

#import "WPSyncContactSource.h"
#import "WPSyncContactStore.h"

@implementation WPSyncContactSource

- (id)dataByApplyingData:(id)data toCurrentData:(id)currentData {
    NSDictionary *current = [currentData isKindOfClass:[NSDictionary class]] ? currentData : nil;
    return [WPSyncContactStore applyContactData:current data:data];
}

- (id)dataByApplyingDelta:(id)delta toCurrentData:(id)currentData {
    NSDictionary *current = [currentData isKindOfClass:[NSDictionary class]] ? currentData : nil;
    return [WPSyncContactStore applyContactDelta:current delta:delta];
}

@end

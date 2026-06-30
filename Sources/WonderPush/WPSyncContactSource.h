//
//  WPSyncContactSource.h
//  WonderPush
//
//  Copyright © 2026 WonderPush. All rights reserved.
//
// The `contact` source plug-in (issue .19). Ported from sync-contact.js. Registered with the WPSync
// orchestrator under the name "contact"; its callbacks (invoked by the processor's decision) apply
// the synced payload to the source's stored `data` using WPSyncContactStore's single-object
// transforms (full reset / delta patch / clear), persisting under the current profile.
//
// The synced contact object is then readable via WPSync.dataForSource:@"contact" — that's what the
// segmentation/popup engines consume (issue .26).

#import <Foundation/Foundation.h>
#import "WPSync.h"   // WPSyncSourcePlugin

@class WPSyncStateStore;

NS_ASSUME_NONNULL_BEGIN

@interface WPSyncContactSource : NSObject <WPSyncSourcePlugin>

/// `identifiersProvider` returns the current {userId?, deviceId, …} — it MUST be the same provider
/// (and `stateStore` the same instance) the orchestrator uses, so they read/write the same slot.
- (instancetype)initWithStateStore:(WPSyncStateStore *)stateStore
                identifiersProvider:(NSDictionary *(^)(void))identifiersProvider NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END

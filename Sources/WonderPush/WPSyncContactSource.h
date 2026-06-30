//
//  WPSyncContactSource.h
//  WonderPush
//
//  Copyright © 2026 WonderPush. All rights reserved.
//
// The `contact` source plug-in (issue .19). Ported from sync-contact.js. Registered with the WPSync
// orchestrator under the name "contact". It is a PURE transformer: given the source's current stored
// data and a synced payload, it returns the new data (single-object reset / delta-patch via
// WPSyncContactStore). The orchestrator owns persistence — it folds the result into the source's
// state and saves under the response's captured profile — so this plug-in is stateless and never
// touches storage or the profile.
//
// The synced contact object is read via WPSync.dataForSource:@"contact" (the segmentation engine, .26).

#import <Foundation/Foundation.h>
#import "WPSync.h"   // WPSyncSourcePlugin

NS_ASSUME_NONNULL_BEGIN

@interface WPSyncContactSource : NSObject <WPSyncSourcePlugin>
@end

NS_ASSUME_NONNULL_END

#import "WPJsonSync.h"

#import <Foundation/Foundation.h>

@interface WPJsonSyncInstallationCustom : WPJsonSync

+ (void) initialize;

+ (WPJsonSyncInstallationCustom *)forCurrentUser;

+ (WPJsonSyncInstallationCustom *)forUser:(NSString *)userId;

+ (void) flush;
- (void) flush;

@end

#import "WPJsonSync.h"

#import <Foundation/Foundation.h>

@interface WPJsonSyncInstallationCore : WPJsonSync

+ (void) initialize;

+ (WPJsonSyncInstallationCore *)forCurrentUser;

+ (WPJsonSyncInstallationCore *)forUser:(NSString *)userId;

+ (void) flush;
- (void) flush;

@end

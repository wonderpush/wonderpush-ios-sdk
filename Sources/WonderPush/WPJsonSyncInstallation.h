#import "WPJsonSync.h"

#import <Foundation/Foundation.h>

@interface WPJsonSyncInstallation : WPJsonSync

+ (void) initialize;

+ (WPJsonSyncInstallation *)forCurrentUser;

+ (WPJsonSyncInstallation *)forUser:(NSString *)userId;

+ (void) flush;
+ (void) flushSync:(BOOL)sync;
- (void) flush;
- (void) flushSync:(BOOL)sync;

+ (void) setDisabled:(BOOL)disabled;
+ (BOOL) disabled;

@end

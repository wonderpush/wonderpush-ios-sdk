#import <Foundation/Foundation.h>

/**
 Button of type link (opens the browser)
 */
#define WP_ACTION_LINK @"link"

/**
 Button of type map (opens the map application)
 */
#define WP_ACTION_MAP_OPEN @"mapOpen"

/**
 Button of type method (launch a notification using NSNotification)
 */
#define WP_ACTION_METHOD_CALL @"method"

/**
 Button of type rating (opens the itunes app on the current application)
 */
#define WP_ACTION_RATING @"rating"

/**
 Button of type track event (track a event on button click)
 */
#define WP_ACTION_TRACK @"trackEvent"

/**
 Button of type update installation (update installation custom data on button click)
 */
#define WP_ACTION_UPDATE_INSTALLATION @"updateInstallation"

/**
 Resynchronize installation
 */
#define WP_ACTION_RESYNC_INSTALLATION @"resyncInstallation"

/**
 Dump installation state as an event
 */
#define WP_ACTION__DUMP_STATE @"_dumpState"

/**
 Override [WonderPush setLogging:]
 */
#define WP_ACTION__OVERRIDE_SET_LOGGING @"_overrideSetLogging"

/**
 Override notification receipt
 */
#define WP_ACTION__OVERRIDE_NOTIFICATION_RECEIPT @"_overrideNotificationReceipt"


/*
 Copyright 2014 WonderPush

 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at

 http://www.apache.org/licenses/LICENSE-2.0

 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License.
 */

#import <Foundation/Foundation.h>
#import <CoreLocation/CoreLocation.h>
#import <CoreBluetooth/CoreBluetooth.h>

FOUNDATION_EXPORT double WonderPushVersionNumber;
FOUNDATION_EXPORT const unsigned char WonderPushVersionString[];


/**
 Name of the notification that is sent using NSNotificationCenter when the sdk is initialized
 */
#define WP_NOTIFICATION_INITIALIZED @"_wonderpushInitialized"

/**
 Name of the notification that is sent using NSNotificationCenter when a user logs in
 */
#define WP_NOTIFICATION_USER_LOGED_IN @"_wonderpushUserLoggedIn"

/**
 Key of the SID parameter for WP_NOTIFICATION_USER_LOGED_IN notification
 */
#define WP_NOTIFICATION_USER_LOGED_IN_SID_KEY @"_wonderpushSID"

/**
 Key of the Access Token parameter for WP_NOTIFICATION_USER_LOGED_IN notification
 */
#define WP_NOTIFICATION_USER_LOGED_IN_ACCESS_TOKEN_KEY @"_wonderpushAccessToken"

/**
 Key of the parameter used when a button of type `method` is called.
 */
#define WP_REGISTERED_CALLBACK_PARAMETER_KEY @"_wonderpushCallbackParameter"


/**
 `WonderPush` is your main interface to the WonderPush SDK.

 Make sure you properly installed the WonderPush SDK, as described in [the guide](../index.html).

 You must call `<setClientId:secret:>` before using any other method.

 Troubleshooting tip: As the SDK should not interfere with your application other than when a notification is to be shown, make sure to monitor your logs for WonderPush output during development, if things did not went as smoothly as they should have.
 */
@interface WonderPush : NSObject

///---------------------
/// @name Initialization
///---------------------

/**
 Initializes the WonderPush SDK.

 Initialization should occur at the earliest possible time, when your application starts.
 A good place is the `application:didFinishLaunchingWithOptions:` method of your `AppDelegate`.

 Please refer to the step entitled *Initialize the SDK* from [the guide](../index.html).

 @param clientId Your WonderPush client id
 @param secret Your WonderPush client secret
 */
+ (void) setClientId:(NSString *)clientId secret:(NSString *)secret;

/**
 Sets the user id, used to identify a single identity across multiple devices, and to correctly identify multiple users on a single device.

 If not called, the last used user id it assumed. Defaulting to `nil` if none is known.

 Prefer calling this method just before calling `<setClientId:secret:>`, rather than just after.
 Upon changing userId, the access token is wiped, so avoid unnecessary calls, like calling with null just before calling with a user id.

 @param userId The user id, unique to your application. Use `nil` for anonymous users.
     You are strongly encouraged to use your own unique internal identifier.
 */
+ (void) setUserId:(NSString *)userId;

+ (void) initialize;

/**
 Returns whether the WonderPush SDK is ready to operate.
 Returns YES when the WP_NOTIFICATION_INITIALIZED is sent.
 @return The initialization state as a BOOL
 */
+ (BOOL) isReady;


///---------------------------------
/// @name Push Notification handling
///---------------------------------

/**
 Activates or deactivates the push notification on the device (if the user accepts) and registers the device token with WondePush.

 @param enabled The new activation state of push notifications.
 */
+ (void) setNotificationEnabled:(BOOL)enabled;

/**
 Forwards an application delegate to the SDK.

 Method to call in your `application:didFinishLaunchingWithOptions:` method of your `AppDelegate`.

 @param launchOptions The launch options.
 */
+ (BOOL) handleApplicationLaunchWithOption:(NSDictionary*)launchOptions;

/**
 Forwards an application delegate to the SDK.

 Method call in your `application:didReceiveRemoteNotification:` method of your `AppDelegate`.

 @param userInfo The userInfo provided by the system.
 */
+ (BOOL) handleDidReceiveRemoteNotification:(NSDictionary *)userInfo;

/**
 Forwards an application delegate to the SDK.

 Method call in your `application:didRegisterForRemoteNotificationsWithDeviceToken:` method of your `AppDelegate`.

 @param deviceToken The device token provided by the system.
 */
+ (void) didRegisterForRemoteNotificationsWithDeviceToken:(NSData*)deviceToken;

/**
 Forwards an application delegate to the SDK.

 If your application uses backgroundModes/remote-notification, call this method in your
 `application:didReceiveLocalNotification:` method of your `AppDelegate`.
 Handles a notification and presents the associated dialog.

 @param notificationUserInfo The `UILocalNotification` `userInfo` member.
 */
+ (BOOL) handleNotification:(NSDictionary*)notificationUserInfo;

/**
 Forwards an application delegate to the SDK.

 If your application uses backgroundModes/remote-notification, call this method in your
 `application:didReceiveRemoteNotification:fetchCompletionHandler:` method

 @param userInfo The userInfo provided by the system.
 */
+ (void) handleNotificationReceivedInBackground:(NSDictionary *)userInfo;


///-----------------------------------
/// @name Installation data and events
///-----------------------------------

/**
 Updates the custom properties attached to the current installation object stored by WonderPush.

 In order to remove a value, don't forget to use `[NSNull null]` as value.

 @param customProperties The partial object containing only the properties to update.
 */
+ (void) putInstallationCustomProperties:(NSDictionary *)customProperties;

/**
 Send an event to be tracked to WonderPush.

 @param type The event type, or name. Event types starting with an `@` character are reserved.
 @param data A dictionary containing custom properties to be attached to the event.
     Prefer using a few custom properties over a plethora of event type variants.
 */
+ (void) trackEvent:(NSString*)type withData:(id)data;


@end

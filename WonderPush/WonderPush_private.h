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

#ifndef WonderPush_WonderPush_private_h
#define WonderPush_WonderPush_private_h

#import "WonderPush.h"
#import "WPResponse.h"


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
 Key to set in your .plist file to allow rating button action
 */
#define WP_ITUNES_APP_ID @"itunesAppID"


/**
 Key of the WonderPush content in a push notification
 */
#define WP_PUSH_NOTIFICATION_KEY @"_wp"

/**
 Key of the deep link url to open with the notification
 */
#define WP_TARGET_URL_KEY @"targetUrl"
#define WP_TARGET_URL_SDK_PREFIX @"wonderpush://"
#define WP_TARGET_URL_DEFAULT @"wonderpush://notificationOpen/default"
#define WP_TARGET_URL_BROADCAST @"wonderpush://notificationOpen/broadcast"

/**
 Notification of type map
 */
#define WP_PUSH_NOTIFICATION_SHOW_MAP @"map"

/**
 Notification of type url
 */
#define WP_PUSH_NOTIFICATION_SHOW_URL @"url"

/**
 Notification of type text
 */
#define WP_PUSH_NOTIFICATION_SHOW_TEXT @"text"

/**
 Notification of type html
 */
#define WP_PUSH_NOTIFICATION_SHOW_HTML @"html"


/**
 Default notification button label
 */
#define WP_DEFAULT_BUTTON_LOCALIZED_LABEL NSLocalizedString(@"Close", nil)


@interface WonderPush (private)

+ (void) executeAction:(NSDictionary *)action onNotification:(NSDictionary *) notification;

+ (void) updateInstallationCoreProperties;

+ (void) setIsReady:(BOOL)isReady;

+ (void) setIsReachable:(BOOL)isReachable;

+ (NSString *)languageCode;

+ (void) setLanguageCode:(NSString *) languageCode;

+ (NSString *) getSDKVersionNumber;

+(void) resetButtonHandler;

/**
 Method returning the rechability state of WonderPush on this phone
 @return the recheability state as a BOOL
 */
+ (BOOL) isReachable;


///---------------------
/// @name Installation data and events
///---------------------

/**
 Updates or add properties to the current installation
 @param properties a collection of properties to add
 @param overwrite if true all the installation will be cleaned before update
 */
+ (void) updateInstallation:(NSDictionary *) properties shouldOverwrite:(BOOL) overwrite;

/**
 Tracks an internal event, starting with a @ sign.
 @param eventData A collection of properties to add directly to the event body.
 @param customData A collection of custom properties to add to the `custom` field of the event.
 */
+(void) trackInternalEvent:(NSString *) type eventData:(NSDictionary *) data customData:(NSDictionary *) customData;


///---------------------
/// @name REST API
///---------------------

/**
 Perform an authenticated GET request to the WonderPush API
 @param resource The relative resource path, ommiting the first "/"
 @param params a key value dictionary with the parameters for the request
 @param handler the completion callback (optional)
 */
+ (void) get:(NSString *)resource params:(id)params handler:(void(^)(WPResponse *response, NSError *error))handler;

/**
 Perform an authenticated POST request to the WonderPush API
 @param resource The relative resource path, ommiting the first "/"
 @param params A dictionary with parameter names and corresponding values that will constitute the POST request's body.
 @param handler the completion callback (optional)
 */
+ (void) post:(NSString *)resource params:(id)params handler:(void(^)(WPResponse *response, NSError *error))handler;

/**
 Perform an authenticated DELETE request to the WonderPush API
 @param resource The relative resource path, ommiting the first "/"
 @param params a key value dictionary with the parameters for the request
 @param handler the completion callback (optional)
 */
+ (void) delete:(NSString *)resource params:(id)params handler:(void(^)(WPResponse *response, NSError *error))handler;

/**
 Perform an authenticated PUT request to the WonderPush API
 @param resource The relative resource path, ommiting the first "/"
 @param params a key value dictionary with the parameters for the request
 @param handler the completion callback (optional)
 */
+ (void) put:(NSString *)resource params:(id)params handler:(void(^)(WPResponse *response, NSError *error))handler;

/**
 Perform a POST request to the API, retrying later (even after application restarts) in the case of a network error.
 @param resource The relative resource path, ommiting the first "/"
 Example: `scores/best`
 @param params A dictionary with parameter names and corresponding values that will constitute the POST request's body.
 @param handler A block to be executed when the request is done executing. Note that this handler will not be executed if the request completes after a network error.
 */
+ (void) postEventually:(NSString *)resource params:(id)params handler:(void(^)(WPResponse *response, NSError *error))handler;

/**
 The last known location
 @return the last known location
 */
+ (CLLocation *) location;


@end


#endif

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

#import <WonderPush/WonderPush.h>
#import <WonderPushCommon/WPResponse.h>
#import <WonderPushCommon/WPReportingData.h>
#import "WPInAppMessagingRenderingPrivate.h"
#import "WPURLConstants.h"
#import "WPRemoteConfig.h"
#import <WonderPushCommon/WPMeasurementsApiClient.h>
#import "WPPresenceManager.h"
#import "WonderPush_constants.h"

/**
 Default notification button label
 */
#define WP_DEFAULT_BUTTON_LOCALIZED_LABEL [WPUtil wpLocalizedString:@"CLOSE" withDefault:@"Close"]

/**
 * Name of the NSNotificationCenter notification fired when an event is fired.
 */
extern NSString * const WPEventFiredNotification;

/**
* Name of the NSNotificationCenter notification payload key that contains the name of the event fired.
*/
extern NSString * const WPEventFiredNotificationEventTypeKey;

/**
* Name of the NSNotificationCenter notification payload key that contains the event data.
*/
extern NSString * const WPEventFiredNotificationEventDataKey;

/**
* Name of the NSNotificationCenter notification payload key that contains the event occurrences dictionary.
*/
extern NSString * const WPEventFiredNotificationEventOccurrencesKey;

/**
 * Name of the NSNotificationCenter notification fired when subscription status changes.
 */
extern NSString * const WPSubscriptionStatusChangedNotification;

/**
 Name of the NSNotificationCenter notification userInfo key that contains the previous subscription status if not nil
 */

extern NSString * const WPSubscriptionStatusChangedNotificationPreviousStatusInfoKey;

/**
 Opt-in subscription status
 */
extern NSString * const WPSubscriptionStatusOptIn;

/**
 Opt-out subscription status
 */
extern NSString * const WPSubscriptionStatusOptOut;

/**
 Force the opening of the URL in the default browser
 */
extern NSString * const WPTargetUrlModeExternal;

@interface WonderPush (private)

+ (void) executeAction:(WPAction *)action withReportingData:(WPReportingData *)reportingData attributionReason:(NSString *)reason;

+ (void) updateInstallationCoreProperties;

+ (void) refreshPreferencesAndConfiguration;
+ (void) refreshPreferencesAndConfigurationSync:(BOOL)sync;

+ (void) sendPreferences;
+ (void) sendPreferencesSync:(BOOL)sync;

+ (void) setIsReachable:(BOOL)isReachable;

+ (NSString *) languageCode;

+ (void) setLanguageCode:(NSString *)languageCode;

+ (NSString *) getIntegrator;

+ (NSBundle *) resourceBundle;
/**
 Method returning the rechability state of WonderPush on this phone
 @return the recheability state as a BOOL
 */
+ (BOOL) isReachable;


///---------------------
/// @name Installation data and events
///---------------------

/**
Called when receiving the full state of the installation
 */
+ (void)receivedFullInstallationFromServer:(NSDictionary *)installation updateDate:(NSDate *)installationUpdateDate;

/**
 Tracks an internal event, starting with a @ sign.
 @param data A collection of properties to add directly to the event body.
 @param customData A collection of custom properties to add to the `custom` field of the event.
 */
+ (void) trackInternalEvent:(NSString *)type eventData:(NSDictionary *)data customData:(NSDictionary *)customData;

/**
 Tracks an internal event, starting with a @ sign.
 @param data A collection of properties to add directly to the event body.
 @param customData A collection of custom properties to add to the `custom` field of the event.
 @param sentCallback A block executed once a request is in the request vault.
 */
+ (void) trackInternalEvent:(NSString *)type eventData:(NSDictionary *)data customData:(NSDictionary *)customData sentCallback:(void(^)(void))sentCallback;

/**
 Tracks an in-app event, sent to the SDK API no matter what (accessToken or not).
 @param data A collection of properties to add directly to the event body.
 @param customData A collection of custom properties to add to the `custom` field of the event.
 */
+ (void) trackInAppEvent:(NSString *)type eventData:(NSDictionary *)data customData:(NSDictionary *)customData ;

/**
 Counts an internal event with measurements API, starting with a @ sign.
 @param data A collection of properties to add directly to the event body.
 @param customData A collection of custom properties to add to the `custom` field of the event.
 */
+ (void) countInternalEvent:(NSString *)type eventData:(NSDictionary *)data customData:(NSDictionary *)customData;

/**
 Whether the user has already been prompted for permission by the OS.
 This asks the OS itself, so it can detect a situation for an application updating from pre-WonderPush push-enabled version.
 */
+ (void) hasAcceptedVisibleNotificationsWithCompletionHandler:(void(^)(BOOL result))handler;

/**
 Makes sure we have an up-to-date device token, and send it to WonderPush servers if necessary.
 */
+ (void) refreshDeviceTokenIfPossible;
/**
 Opens the given URL
 */
+ (void) openURL:(NSURL *)url targetUrlMode:(NSString *)targetUrlMode;

///---------------------
/// @name REST API
///---------------------

/**
 Perform an authenticated request to the WonderPush API for a specified userId
 @param userId The userId the request should be bound to
 @param method The HTTP method to use
 @param resource The relative resource path, ommiting the first "/"
 @param params a key value dictionary with the parameters for the request
 @param handler the completion callback (optional)
 */
+ (void) requestForUser:(NSString *)userId method:(NSString *)method resource:(NSString *)resource params:(id)params handler:(void(^)(WPResponse *response, NSError *error))handler;

/**
 Perform an authenticated without access token request to the WonderPush API for a specified userId
 @param userId The userId the request should be bound to
 @param method The HTTP method to use
 @param resource The relative resource path, ommiting the first "/"
 @param params a key value dictionary with the parameters for the request
 @param handler the completion callback (optional)
 */
+ (void) requestLiveActivityAPIForUser:(NSString *)userId method:(NSString *)method resource:(NSString *)resource params:(id)params handler:(void(^)(WPResponse *response, NSError *error))handler;

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
 */
+ (void) postEventually:(NSString *)resource params:(id)params;

/**
 Triggers the system location prompt. Requires that:
   - you link with the CoreLocation framework
   - you set NSLocationAlwaysUsageDescription, NSLocationAlwaysAndWhenInUseUsageDescription or NSLocationWhenInUseUsageDescription in your Info.plist file
 */
+ (void) triggerLocationPrompt;

/**
 The last known location
 @return the last known location
 */
+ (CLLocation *) location;

+ (void) safeDeferWithConsent:(void(^)(void))block;
+ (void) safeDeferWithSubscription:(void(^)(void))block;

+ (WPRemoteConfigManager *) remoteConfigManager;

+ (WPMeasurementsApiClient *) measurementsApiClient;

+ (void) requestEventuallyWithMeasurementsApi:(WPRequest *)request;

+ (void)requestEventuallyWithOptionalAccessToken:(WPRequest *)request;

+ (WPReportingData *) lastClickedNotificationReportingData;

+ (NSString *) subscriptionStatus;
+ (BOOL) subscriptionStatusIsOptIn;
+ (WPPresenceManager *)presenceManager;
@end


#endif

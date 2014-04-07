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

#import "WonderPush_public.h"
#import "WPResponse.h"

@interface WonderPush (private)

+ (void) executeAction:(NSDictionary *)action onNotification:(NSDictionary *) notification;

+ (void) updateInstallationCoreProperties;

+ (void) setIsReachable:(BOOL)isReachable;

+ (NSArray *) validLanguageCodes;

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

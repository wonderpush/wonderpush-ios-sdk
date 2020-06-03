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


/**
 This class contains static utilities that would be better implemented as categories if it wasn't for this bug:
 https://developer.apple.com/library/mac/#qa/qa2006/qa1490.html
 */
@interface WPUtil : NSObject

///--------------
/// @name Device
///--------------

+ (NSString *)deviceIdentifier;

+ (NSString *)deviceModel;


///-------------------
/// @name ERROR
///-------------------

+ (NSError *)errorFromJSON:(id)json;

///------------------
/// @name Server time
///------------------

+ (long long) getServerDate;

///------------------------
/// @name Application utils
///------------------------

+ (BOOL) currentApplicationIsInForeground;

+ (NSArray *) getBackgroundModes;

+ (BOOL) hasBackgroundModeRemoteNotification;

+ (NSString *) getEntitlement:(NSString *)key;

+ (BOOL) hasImplementedDidReceiveRemoteNotificationWithFetchCompletionHandler;

+ (NSString *) localizedStringIfPossible:(NSString *)string;

+ (NSString *) wpLocalizedString:(NSString *)key withDefault:(NSString *)defaultValue;

+ (void) askUserPermission;

@end


///-----------------
/// @name Constants
///-----------------

extern NSString * const WPErrorDomain;
//extern NSInteger const WPErrorInvalidParameter;
//extern NSInteger const WPErrorMissingMandatoryParameter;
extern NSInteger const WPErrorInvalidCredentials;
extern NSInteger const WPErrorInvalidAccessToken;
extern NSInteger const WPErrorMissingUserConsent;
extern NSInteger const WPErrorHTTPFailure;
extern NSInteger const WPErrorInvalidFormat;
extern NSInteger const WPErrorNotFound;
//extern NSInteger const WPErrorSecureConnectionRequired;
//extern NSInteger const WPErrorInvalidPrevNextParameter;
//extern NSInteger const WPErrorInvalidSid;
//extern NSInteger const WPErrorInactiveApplication;
//extern NSInteger const WPErrorMissingPermissions;
//extern NSInteger const WPErrorServiceException;

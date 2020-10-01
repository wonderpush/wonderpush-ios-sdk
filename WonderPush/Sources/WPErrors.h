//
//  WPErrors.h
//  WonderPush
//
//  Created by Stéphane JAIS on 01/10/2020.
//  Copyright © 2020 WonderPush. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

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
extern NSInteger const WPErrorForbidden;

//extern NSInteger const WPErrorSecureConnectionRequired;
//extern NSInteger const WPErrorInvalidPrevNextParameter;
//extern NSInteger const WPErrorInvalidSid;
//extern NSInteger const WPErrorInactiveApplication;
//extern NSInteger const WPErrorMissingPermissions;
//extern NSInteger const WPErrorServiceException;
NS_ASSUME_NONNULL_END

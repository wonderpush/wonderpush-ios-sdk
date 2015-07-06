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
 WPConfiguration is a singleton that holds configuration values for this WonderPush installation
 */

@interface WPConfiguration : NSObject

+ (WPConfiguration *)sharedConfiguration;

@property (strong, nonatomic) NSString *clientId;

@property (strong, nonatomic) NSString *clientSecret;

@property (readonly, nonatomic) NSURL *baseURL;

@property (assign, nonatomic) NSTimeInterval timeOffset;

@property (assign, nonatomic) NSTimeInterval timeOffsetPrecision;

@property (readonly) BOOL usesSandbox;

/// The access token used to hit the WonderPush API
@property (readonly) NSString *accessToken;

// Thedevice token used for APNS
@property (readonly) NSString *deviceToken;

/// The sid used to hit the WonderPush API
@property (nonatomic, strong) NSString *sid;

@property (nonatomic, strong) NSString *userId;

@property (nonatomic, strong) NSString *installationId;

@property (nonatomic, strong) NSDictionary *cachedInstallationCoreProperties;
@property (nonatomic, strong) NSDate *cachedInstallationCorePropertiesDate;

- (void) setAccessToken:(NSString *)accessToken;

- (void) setDeviceToken:(NSString *)deviceToken;

-(void) setStoredClientId:(NSString *)clientId;

-(NSString *) getStoredClientId;

-(void) addToEventReceivedHistory:(NSString *) notificationId;

-(BOOL) isInEventReceivedHistory:(NSString *) notificationId;

-(void) addToQueuedNotifications:(NSDictionary *) notification;

-(NSMutableArray *) getQueuedNotifications;

-(void) clearQueuedNotifications;

@end

//
//  WonderPushAPI.h
//  Pods
//
//  Created by Stéphane JAIS on 07/02/2019.
//

#import <Foundation/Foundation.h>
#import <CoreLocation/CoreLocation.h>

@protocol WonderPushAPI
- (void) initWonderPush;
- (NSString *) userId;
- (void) setUserId:(NSString *)userId;
- (void) activate;
- (void) deactivate;
- (NSString *) installationId;
- (NSString *) deviceId;
- (NSString *) pushToken;
- (NSString *) accessToken;
- (BOOL) getNotificationEnabled;
- (void) setNotificationEnabled:(BOOL)enabled;
- (void) updateInstallationCoreProperties;
- (NSDictionary *) getInstallationCustomProperties;
- (void) putInstallationCustomProperties:(NSDictionary *)customProperties;
- (void) trackEvent:(NSString*)type;
- (void) trackEvent:(NSString*)type withData:(NSDictionary *)data;
- (void) trackInternalEvent:(NSString *)type eventData:(NSDictionary *)data customData:(NSDictionary *)customData;
- (void) refreshDeviceTokenIfPossible;
- (void) executeAction:(NSDictionary *)action onNotification:(NSDictionary *)notification;
- (CLLocation *) location;
- (void) setDeviceToken:(NSString *)deviceToken;
@end

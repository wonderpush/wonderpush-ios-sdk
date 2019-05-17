//
//  WonderPushAPI.h
//  Pods
//
//  Created by Stéphane JAIS on 07/02/2019.
//

#import <Foundation/Foundation.h>
#import <CoreLocation/CoreLocation.h>

@protocol WonderPushAPI
// Public API
- (void) subscribeToNotifications;
- (void) unsubscribeFromNotifications;
- (BOOL) isSubscribedToNotifications;
- (void) trackEvent:(NSString*)eventType;
- (void) trackEvent:(NSString *)eventType attributes:(NSDictionary *)attributes;
- (void) putProperties:(NSDictionary *)properties;
- (NSDictionary *) getProperties;
- (void) addTag:(NSString *)tag;
- (void) removeTag:(NSString *)tag;
- (void) removeAllTags;
- (NSOrderedSet<NSString *> *) getTags;
- (bool) hasTag:(NSString *)tag;
- (void) clearEventsHistory;
- (void) clearPreferences;
- (void) clearAllData;
- (void) downloadAllData:(void(^)(NSData *data, NSError *error))completion;


// Old / private API
- (void) activate;
- (void) deactivate;
- (NSString *) installationId;
- (NSString *) deviceId;
- (NSString *) pushToken;
- (NSString *) accessToken;
- (BOOL) getNotificationEnabled;
- (void) setNotificationEnabled:(BOOL)enabled;
- (void) sendPreferences;
- (void) updateInstallationCoreProperties;
- (NSDictionary *) getInstallationCustomProperties;
- (void) putInstallationCustomProperties:(NSDictionary *)customProperties;
- (void) trackEvent:(NSString*)type withData:(NSDictionary *)data;
- (void) trackInternalEvent:(NSString *)type eventData:(NSDictionary *)data customData:(NSDictionary *)customData;
- (void) refreshDeviceTokenIfPossible;
- (void) executeAction:(NSDictionary *)action onNotification:(NSDictionary *)notification;
- (CLLocation *) location;
- (void) setDeviceToken:(NSString *)deviceToken;
@end

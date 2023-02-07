//
//  WPSwiftInterop.h
//  WonderPush
//
//  Created by Olivier Favre on 31/01/2023.
//  Copyright © 2023 WonderPush. All rights reserved.
//

#ifndef WPSwiftInterop_h
#define WPSwiftInterop_h

#import <WonderPush/WonderPush-Swift.h>

NS_ASSUME_NONNULL_BEGIN


// The protocol, exposed from ObjC, that enable Swift to call advertised methods.
// See: https://github.com/amichnia/Swift-framework-with-private-ObjC-example
SWIFT_PROTOCOL_NAMED("WonderPushPrivateProtocol")
@protocol WonderPushPrivateProtocol

// This method is automatically implemented by classes, and it permits Swift to grab an instance directly from the protocol itself.
- (nonnull instancetype)init;

- (void)log:(NSString *)message;
- (void)logDebug:(NSString *)message;

- (NSDictionary<NSString *, NSArray<NSString *> *> *) liveActivityIdsPerAttributesTypeName;

- (void)trackInternalEvent:(NSString *)type eventData:(NSDictionary *)data customData:(NSDictionary *)customData sentCallback:(void (^)(void))sentCallback;

@end


// The protocol, exposed from ObjC, that enable Swift to call advertised methods.
// See: https://github.com/amichnia/Swift-framework-with-private-ObjC-example
SWIFT_PROTOCOL_NAMED("WPJsonSyncLiveActivityProtocol")
@protocol WPJsonSyncLiveActivityProtocol

// This method is automatically implemented by classes, and it permits Swift to grab an instance directly from the protocol itself.
- (nonnull instancetype)init;

- (nullable instancetype) initFromSavedStateForActivityId:(nonnull NSString *)activityId;
- (nonnull instancetype) initWithActivityId:(nonnull NSString *)activityId userId:(nullable NSString *)userId;

- (void) flush;
- (void) activityChangedWithAttributesType:(nullable NSString *)attributesTypeName creationDate:(nullable NSDate *)creationDate activityState:(nullable NSString *)activityState pushToken:(nullable NSData *)pushToken topic:(nullable NSString *)topic custom:(nullable NSDictionary *)custom;

- (void) put:(NSDictionary *)diff;
- (void) receiveState:(NSDictionary *)state resetSdkState:(bool)reset;
- (void) receiveServerState:(NSDictionary *)state;
- (void) receiveDiff:(NSDictionary *)diff;

- (bool) performScheduledPatchCall;

@end


// Declares the existence of a factory class, implemented in Swift,
// that ObjC will use to register the actual implementation of WonderPushPrivateProtocol.
// See: https://github.com/amichnia/Swift-framework-with-private-ObjC-example
SWIFT_CLASS("WonderPushObjCInterop")
@interface WonderPushObjCInterop : NSObject

+ (void) registerWonderPushPrivate:(Class<WonderPushPrivateProtocol> _Nonnull)type;
+ (void) registerWPJsonSyncLiveActivity:(Class<WPJsonSyncLiveActivityProtocol> _Nonnull)type;

@end


// ObjC implementation of WonderPushPrivateProtocol, that will be exposed to Swift using WonderPushObjCInterop
// See: https://github.com/amichnia/Swift-framework-with-private-ObjC-example
@interface WonderPushPrivate : NSObject<WonderPushPrivateProtocol>

- (void)log:(NSString *)message;
- (void)logDebug:(NSString *)message;

- (NSDictionary<NSString *, NSArray<NSString *> *> *) liveActivityIdsPerAttributesTypeName;

- (void) trackInternalEvent:(NSString *)type eventData:(NSDictionary *)data customData:(NSDictionary *)customData sentCallback:(void (^)(void))sentCallback;

@end


NS_ASSUME_NONNULL_END

#endif /* WPSwiftInterop_h */

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

- (void)doSomethingInternalWithSecretAttribute:(NSInteger)attribute;

@end


// Declares the existence of a factory class, implemented in Swift,
// that ObjC will use to register the actual implementation of WonderPushPrivateProtocol.
// See: https://github.com/amichnia/Swift-framework-with-private-ObjC-example
SWIFT_CLASS("WonderPushObjCInterop")
@interface WonderPushObjCInterop : NSObject

+ (void) registerWonderPushPrivate:(Class<WonderPushPrivateProtocol> _Nonnull)type;

@end


// ObjC implementation of WonderPushPrivateProtocol, that will be exposed to Swift using WonderPushObjCInterop
// See: https://github.com/amichnia/Swift-framework-with-private-ObjC-example
@interface WPSwiftInterop : NSObject<WonderPushPrivateProtocol>

- (void) doSomethingInternalWithSecretAttribute:(NSInteger)attribute;

@end


NS_ASSUME_NONNULL_END

#endif /* WPSwiftInterop_h */

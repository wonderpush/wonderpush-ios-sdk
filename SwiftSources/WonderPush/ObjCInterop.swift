//
//  ObjCInterop.swift
//  WonderPush
//
//  Created by Olivier Favre on 31/01/2023.
//  Copyright © 2023 WonderPush. All rights reserved.
//

import Foundation

// The protocol, exposed in ObjC, that enable Swift to call advertised methods.
// See: https://github.com/amichnia/Swift-framework-with-private-ObjC-example
@objc(WonderPushPrivateProtocol)
internal protocol WonderPushPrivate {

    // Implemented by the underlying ObjC class and returns a new instance of a class implementing this protocol
    init()

    func log(_ message: String) -> Void
    func logDebug(_ message: String) -> Void

    func liveActivityIdsPerAttributesTypeName() -> [String: Array<String>]
    func trackInternalEvent(_ type: String, eventData: NSDictionary, customData: NSDictionary, sentCallback: @escaping () -> Void)

}

// The protocol, exposed in ObjC, that enable Swift to call advertised methods.
// See: https://github.com/amichnia/Swift-framework-with-private-ObjC-example
@objc(WPJsonSyncLiveActivityProtocol)
internal protocol WPJsonSyncLiveActivity {

    init()

    func initFromSavedStateForActivityId(_ activityId: String) -> Self?
    func initWithActivityId(_ activityId: String, userId:String?, attributesTypeName:String) -> Self

    func flush() -> Void
    func activityChangedWithAttributesType(_ attributesTypeName:String?, creationDate:Date?, activityState:String?, pushToken:Data?, topic:String?, custom:NSDictionary?) -> Void

    func put(_ diff: NSDictionary) -> Void
    func receiveState(_ state: NSDictionary, resetSdkState: Bool) -> Void
    func receiveServerState(_ state: NSDictionary) -> Void
    func receiveDiff(_ diff: NSDictionary) -> Void

    func performScheduledPatchCall() -> Bool

}

// A private factory, receiving a type instance from the private ObjC part.
// Upon building an instance in Swift, we can call ObjC methods on it.
// See: https://github.com/amichnia/Swift-framework-with-private-ObjC-example
@objc(WonderPushObjCInterop)
internal class WonderPushObjCInterop: NSObject {
    
    private(set) static var WonderPushPrivate: WonderPushPrivate! = nil
    private static var WPJsonSyncLiveActivityType: WPJsonSyncLiveActivity.Type!
    
    @objc static func registerWonderPushPrivate(_ type: WonderPushPrivate.Type) {
        WonderPushPrivate = type.init()
    }
    
    @objc static func registerWPJsonSyncLiveActivity(_ type: WPJsonSyncLiveActivity.Type) {
        WPJsonSyncLiveActivityType = type
    }
    
    static func initWPJsonSyncLiveActivityFromSavedStateForActivityId(_ activityId: String) -> WPJsonSyncLiveActivity? {
        return WPJsonSyncLiveActivityType.init().initFromSavedStateForActivityId(activityId)
    }
    
    static func initWPJsonSyncLiveActivityWithActivityId(_ activityId: String, userId:String?, attributesTypeName:String) -> WPJsonSyncLiveActivity {
        return WPJsonSyncLiveActivityType.init().initWithActivityId(activityId, userId: userId, attributesTypeName: attributesTypeName)
    }

}

internal func WPLog(_ message: String) -> Void {
    WonderPushObjCInterop.WonderPushPrivate.log(message)
}

internal func WPLogDebug(_ message: String) -> Void {
    WonderPushObjCInterop.WonderPushPrivate.logDebug(message)
}

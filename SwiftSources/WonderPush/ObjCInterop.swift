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

    func doSomethingInternal(withSecretAttribute: Int)
    
}

// A private factory, receiving a type instance from the private ObjC part.
// Upon building an instance in Swift, we can call ObjC methods on it.
// See: https://github.com/amichnia/Swift-framework-with-private-ObjC-example
@objc(WonderPushObjCInterop)
internal class WonderPushObjCInterop: NSObject {
    
    private(set) static var WonderPushPrivate: WonderPushPrivate! = nil
    
    @objc static func registerWonderPushPrivate(_ type: WonderPushPrivate.Type) {
        print("REGISTRATION CALLED WITH TYPE = \(type)")
        WonderPushPrivate = type.init()
    }
    
}

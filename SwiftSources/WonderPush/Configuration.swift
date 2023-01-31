//
//  Configuration.swift
//  WonderPush
//
//  Created by Olivier Favre on 31/01/2023.
//  Copyright © 2023 WonderPush. All rights reserved.
//

import Foundation

class Configuration {
    
    class func getDecodedFromJSON<T: Decodable>(_ type: T.Type, key: String) throws -> T? {
        let data = UserDefaults.standard.data(forKey: key)
        if data == nil {
            return nil
        }
        return try JSONDecoder().decode(type, from: data!)
    }
    
    class func setEncodedToJSON<T: Encodable>(_ value: T, key: String) -> Void {
        let data = try? JSONEncoder().encode(value)
        if data == nil {
            UserDefaults.standard.removeObject(forKey: key)
        } else {
            UserDefaults.standard.set(data, forKey:key)
        }
    }
    
    @available(iOS 16.1, *)
    class func getPersistedActivityStates() -> [String: PersistedActivityState] {
        let earliestAcceptableCreationDate = Date(timeIntervalSinceNow: -8*60*60)
        return (try? self.getDecodedFromJSON([String: PersistedActivityState].self, key: "__wonderpush_persistedActivityStates")) ?? ([:] as [String: PersistedActivityState])
            .filter({ element in
                element.value.creationDate > earliestAcceptableCreationDate
            })
    }
    
    @available(iOS 16.1, *)
    class func setPersistedActivityStates(_ value: [String: PersistedActivityState]) -> Void {
        self.setEncodedToJSON(value, key: "__wonderpush_persistedActivityStates")
    }

    @available(iOS 16.1, *)
    class func updatePersistedActivityStates(_ callback: (inout [String: PersistedActivityState]) -> Void) -> Void {
        var persistedActivityStates = self.getPersistedActivityStates()
        callback(&persistedActivityStates)
        self.setPersistedActivityStates(persistedActivityStates)
    }

}

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

}

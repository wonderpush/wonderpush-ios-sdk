//
//  NotificationService.swift
//  WonderPushNotificationServiceExtension
//
//  Created by Stéphane JAIS on 09/03/2021.
//  Copyright © 2021 WonderPush. All rights reserved.
//

import WonderPushExtension

class NotificationService: WPNotificationServiceExtension {
    override class func clientId() -> String {
        return "ENTER_CLIENT_ID"
    }
    override class func clientSecret() -> String {

        return "ENTER_CLIENT_SECRET"

    }

}

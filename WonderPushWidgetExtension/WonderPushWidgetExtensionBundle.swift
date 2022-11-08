//
//  WonderPushWidgetExtensionBundle.swift
//  WonderPushWidgetExtension
//
//  Created by Stéphane JAIS on 08/11/2022.
//  Copyright © 2022 WonderPush. All rights reserved.
//

import WidgetKit
import SwiftUI

@main
struct WonderPushWidgetExtensionBundle: WidgetBundle {
    var body: some Widget {
        WonderPushWidgetExtension()
        WonderPushWidgetExtensionLiveActivity()
    }
}

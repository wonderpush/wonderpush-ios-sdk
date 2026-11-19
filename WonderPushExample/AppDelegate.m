//
//  AppDelegate.m
//  WonderPushExample
//
//  Created by Stéphane JAIS on 12/05/2020.
//  Copyright © 2020 WonderPush. All rights reserved.
//

#import "AppDelegate.h"
#import <WonderPush/WonderPush.h>

@interface AppDelegate ()

@end

@implementation AppDelegate


- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    // Override point for customization after application launch.
    
#ifdef DEBUG
    [WonderPush setLogging:YES];
#endif

    // Replace with real values
    [WonderPush setClientId:@"USE_REMEMBERED" secret:@"USE_REMEMBERED"];
    
    [WonderPush setupDelegateForApplication:application];
    [WonderPush setupDelegateForUserNotificationCenter];
    [WonderPush subscribeToNotifications];
    return YES;
}

@end

// Recent iOS versions require adopting the UIScene lifecycle, and crash at launch otherwise.
// This minimal scene delegate only holds the window, which UIKit creates from the storyboard
// declared in the UIApplicationSceneManifest of Info.plist.
@interface SceneDelegate : UIResponder <UIWindowSceneDelegate>
@property (strong, nonatomic) UIWindow *window;
@end

@implementation SceneDelegate
@end

//
//  WPAppDelegate.m
//  WonderPush
//
//  Created by Olivier Favre on 13/01/16.
//  Copyright © 2016 WonderPush. All rights reserved.
//

#import "WPAppDelegate.h"

#import <Foundation/Foundation.h>
#import <objc/runtime.h>

#import "WonderPush.h"


const char * const WPAPPDELEGATE_ASSOCIATION_KEY = "com.wonderpush.sdk.WPAppDelegate";


@interface WPAppDelegate ()

@end


@implementation WPAppDelegate

@synthesize nextDelegate;


#pragma mark - Setup and chaining

+ (void) setupDelegateForApplication:(UIApplication *)application
{
    WPAppDelegate *delegate = [WPAppDelegate new];

    // Retain the delegate as long as the UIApplication lives
    objc_setAssociatedObject(application, WPAPPDELEGATE_ASSOCIATION_KEY, delegate, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    // Note: the association is not breakable, like the created delegate chain

    // Setup the delegate chain
    delegate.nextDelegate = application.delegate;
    application.delegate = delegate;
}

- (id) forwardingTargetForSelector:(SEL)aSelector
{
    return self.nextDelegate;
}

- (BOOL)respondsToSelector:(SEL)aSelector
{
    return [super respondsToSelector:aSelector] || [self.nextDelegate respondsToSelector:aSelector];
}


#pragma mark - Overriding useful methods

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    WPLog(@"%@", NSStringFromSelector(_cmd));
    [WonderPush application:application didFinishLaunchingWithOptions:launchOptions];
    if ([self.nextDelegate respondsToSelector:_cmd]) {
        return [self.nextDelegate application:application didFinishLaunchingWithOptions:launchOptions];
    } else {
        return YES;
    }
}

- (void)application:(UIApplication *)application didReceiveLocalNotification:(UILocalNotification *)notification
{
    WPLog(@"%@", NSStringFromSelector(_cmd));
    [WonderPush application:application didReceiveLocalNotification:notification];
    if ([self.nextDelegate respondsToSelector:_cmd]) {
        [self.nextDelegate application:application didReceiveLocalNotification:notification];
    }
}

- (void) application:(UIApplication *)application didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken
{
    WPLog(@"%@", NSStringFromSelector(_cmd));
    [WonderPush application:application didRegisterForRemoteNotificationsWithDeviceToken:deviceToken];
    if ([self.nextDelegate respondsToSelector:_cmd]) {
        [self.nextDelegate application:application didRegisterForRemoteNotificationsWithDeviceToken:deviceToken];
    }
}

- (void)application:(UIApplication *)application didFailToRegisterForRemoteNotificationsWithError:(NSError *)error
{
    WPLog(@"%@", NSStringFromSelector(_cmd));
    [WonderPush application:application didFailToRegisterForRemoteNotificationsWithError:error];
    if ([self.nextDelegate respondsToSelector:_cmd]) {
        [self.nextDelegate application:application didFailToRegisterForRemoteNotificationsWithError:error];
    }
}

- (void) application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo
{
    WPLog(@"%@", NSStringFromSelector(_cmd));
    [WonderPush application:application didReceiveRemoteNotification:userInfo];
    if ([self.nextDelegate respondsToSelector:_cmd]) {
        [self.nextDelegate application:application didReceiveRemoteNotification:userInfo];
    }
}

- (void) application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo fetchCompletionHandler:(void (^)(UIBackgroundFetchResult))completionHandler
{
    WPLog(@"%@", NSStringFromSelector(_cmd));
    if ([self.nextDelegate respondsToSelector:_cmd]) {
        [self.nextDelegate application:application didReceiveRemoteNotification:userInfo fetchCompletionHandler:completionHandler];
        completionHandler = nil;
    }
    [WonderPush application:application didReceiveRemoteNotification:userInfo fetchCompletionHandler:completionHandler];
}

- (void)applicationDidEnterBackground:(UIApplication *)application {
    WPLog(@"%@", NSStringFromSelector(_cmd));
    [WonderPush applicationDidEnterBackground:application];
    if ([self.nextDelegate respondsToSelector:_cmd]) {
        [self.nextDelegate applicationDidEnterBackground:application];
    }
}

- (void)applicationDidBecomeActive:(UIApplication *)application {
    WPLog(@"%@", NSStringFromSelector(_cmd));
    [WonderPush applicationDidBecomeActive:application];
    if ([self.nextDelegate respondsToSelector:_cmd]) {
        [self.nextDelegate applicationDidBecomeActive:application];
    }
}


@end
/*
 Copyright 2014 WonderPush

 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at

 http://www.apache.org/licenses/LICENSE-2.0

 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License.
 */

#import <CoreGraphics/CGGeometry.h>
#import <UIKit/UIKit.h>
#import <CoreTelephony/CTTelephonyNetworkInfo.h>
#import <CoreTelephony/CTCarrier.h>
#import <AVFoundation/AVFoundation.h>
#import <CoreMotion/CoreMotion.h>
#import <sys/utsname.h>
#import "WPUtil.h"
#import "WonderPush_private.h"
#import "WPConfiguration.h"
#import "WPDialogButtonHandler.h"
#import "WPClient.h"
#import "CustomIOS7AlertView.h"


static BOOL _isReady = NO;

static BOOL _isReachable = NO;

static NSTimeInterval _lastAppOpen = 0;


@implementation WonderPush

static NSString *_currentLanguageCode = nil;
static CLLocationManager *LocationManager = nil;

+ (void) initialize
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        LocationManager = [[CLLocationManager alloc] init];
    });
}

+ (BOOL) isReady
{
    return _isReady;
}

+ (void) setIsReady:(BOOL)isReady {
    _isReady = isReady;
}

+ (BOOL) isReachable
{
    return _isReachable;
}

+ (void) setIsReachable:(BOOL)isReachable {
    _isReachable = isReachable;
}

+ (void) setUserId:(NSString *) userId
{
    WPConfiguration *configuration = [WPConfiguration sharedConfiguration];
    configuration.userId = userId;
}

+ (void) setClientId:(NSString *)clientId secret:(NSString *)secret{
    NSException* invalidArgumentException = nil;

    if (clientId == nil) {
        invalidArgumentException = [NSException
                                    exceptionWithName:@"InvalidArgumentException"
                                    reason:@"Please set 'clientId' argument of [WonderPush setClientId:secret] method"
                                    userInfo:nil];
    } else if (secret == nil) {
        invalidArgumentException = [NSException
                                    exceptionWithName:@"InvalidArgumentException"
                                    reason:@"Please set 'secret' argument of [WonderPush setClientId:secret] method"
                                    userInfo:nil];
    }
    if (invalidArgumentException != nil) {
        @throw invalidArgumentException;
    }


    WPConfiguration *configuration = [WPConfiguration sharedConfiguration];
    configuration.clientId = clientId;
    configuration.clientSecret = secret;
    if ((configuration.clientId == nil && [configuration getStoredClientId] != nil)
        || (configuration.clientId != nil && ![configuration.clientId isEqualToString: [configuration getStoredClientId]]))
    {
        [configuration setStoredClientId:clientId];
        // clientId changed reseting token
        configuration.accessToken = nil;
        configuration.sid = nil;
    }
    // Fetch anonymous access token right away
    BOOL isFetching = [[WPClient sharedClient] fetchAnonymousAccessTokenIfNeededAndCall:^(WPAFHTTPRequestOperation *operation, id responseObject) {
        [self setIsReady:YES];
        [[NSNotificationCenter defaultCenter] postNotificationName:WP_NOTIFICATION_INITIALIZED
                                                            object:self
                                                          userInfo:nil];
    } failure:^(WPAFHTTPRequestOperation *operation, NSError *error) {}];
    if (NO == isFetching) {
        [self setIsReady:YES];
        [[NSNotificationCenter defaultCenter] postNotificationName:WP_NOTIFICATION_INITIALIZED
                                                            object:self
                                                          userInfo:nil];
        [WonderPush updateInstallationCoreProperties];
    }
}

+(void) updateInstallation:(NSDictionary *) properties shouldOverwrite:(BOOL) overwrite {
    NSString *installationEndPoint = @"/installation";
    NSError * err;
    NSData * jsonData = [NSJSONSerialization dataWithJSONObject:properties options:0 error:&err];
    NSString * propertiesString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    [self postEventually:installationEndPoint params:@{@"body":propertiesString, @"overwrite":[NSNumber numberWithBool:overwrite]} handler:^(WPResponse *response, NSError *error) {}];
}

+ (void) putInstallationCustomProperties:(NSDictionary *) customProperties;
{
    if (!customProperties) return;
    [self updateInstallation:@{@"custom": customProperties} shouldOverwrite:NO];
}

+ (NSString *) getSDKVersionNumber
{
    NSString *result;
#ifdef SDK_VERSION
    result = SDK_VERSION;
#else
    // Note: Only valid for framework builds
    NSBundle *bundle = [NSBundle bundleWithIdentifier:@"com.wonderpush.WonderPush"];
    result = [NSString stringWithFormat:@"iOS-%@", [bundle objectForInfoDictionaryKey:@"CFBundleShortVersionString"]];
#endif
    return result;
}

+(void) updateInstallationCoreProperties
{
    NSDictionary *application = @{@"version" : [self getVersionString],
                                  @"sdkVersion": [self getSDKVersionNumber],
                                };

    CGRect screenSize = [self getScreenSize];
    NSDictionary *device = @{@"id": [WPUtil deviceIdentifier],
                             @"platform": @"iOS",
                             @"osVersion": [self getOsVersion],
                             @"brand": @"Apple",
                             @"model": [self getDeviceModel],
                             @"name": [self getDeviceName],
                             @"screenWidth": [NSNumber numberWithInt:(int)screenSize.size.width],
                             @"screenHeight": [NSNumber numberWithInt:(int)screenSize.size.height],
                             @"screenDensity": [NSNumber numberWithInt:(int)[self getScreenDensity]],
                             };

    NSDictionary *configuration = @{@"timeZone": [self getTimezone],
                                    @"carrier": [self getCarrierName],
                                    @"locale": [self getLocale]};

    NSDictionary *capabilities = @{@"bluetooth": [NSNumber numberWithBool:[self getBluetoothSupported]],
                                   @"bluetoothLe": [NSNumber numberWithBool:[self getBluetoothLeSupported]],
                                   @"nfc": [NSNumber numberWithBool:[self getNFCSupported]],
                                   @"telephony": [NSNumber numberWithBool:[self getTelephonySupported]],
                                   @"telephonyGsm": [NSNumber numberWithBool:[self getTelephonyGSMSupported]],
                                   @"telephonyCdma": [NSNumber numberWithBool:[self getTelephoneCDMASupported]],
                                   @"wifi": @YES, // all have wifi otherwise how did we install the app
                                   @"wifiDirect": @NO, // not supported by Apple
                                   @"gps": [NSNumber numberWithBool:[self getGPSSupported]],
                                   @"networkLocation": @YES,
                                   @"camera": [NSNumber numberWithBool:[self getCameraSupported]],
                                   @"frontCamera": [NSNumber numberWithBool:[self getFrontCameraSupported]],
                                   @"microphone": [NSNumber numberWithBool:[self getMicrophoneSupported]],
                                   @"sensorAccelerometer":@YES,
                                   @"sensorBarometer": @NO,
                                   @"sensorCompass": [NSNumber numberWithBool:[self getCompassSupported]],
                                   @"sensorGyroscope": [NSNumber numberWithBool:[self getGyroscopeSupported]],
                                   @"sensorLight": @YES,
                                   @"sensorProximity": [NSNumber numberWithBool:[self getProximitySensorSupported]],
                                   @"sensorStepDetector": @NO,
                                   @"touchscreen": @YES,
                                   @"touchscreenTwoFingers": @YES,
                                   @"touchscreenDistinct": @YES,
                                   @"touchscreenFullHand": @YES,
                                   @"figerprintScanner":[NSNumber numberWithBool:[self getFingerprintScannerSupported]]
                                   };

    NSDictionary *properties = @{@"application": application,
                                 @"device": device,
                                 @"configuration": configuration,
                                 @"capabilities": capabilities};
    [self updateInstallation:properties shouldOverwrite:NO];
}


#pragma mark - push notification types handling

// We need to keep a reference on the DialogButtonHandler as the UIAlertView just keep a weak reference.
// We can only have one dialog on screen so having only one reference is no problem
static WPDialogButtonHandler *buttonHandler = nil;

+(void) resetButtonHandler
{
    buttonHandler = nil;
}

+(void) handleTextNotification:(NSDictionary *) wonderPushData
{
    if (buttonHandler != nil) {
        // we currently support only one dialog at a time
        return;
    }

    UIAlertView *dialog = [[UIAlertView alloc] initWithTitle:[wonderPushData objectForKey:@"title"] message:[wonderPushData objectForKey:@"message"] delegate:nil cancelButtonTitle:nil otherButtonTitles:nil, nil];
    NSArray *buttons = [wonderPushData objectForKey:@"buttons"];
    if (buttons != nil && [buttons count] > 0)
    {
        for (NSDictionary *button in buttons)
        {
            [dialog addButtonWithTitle:[button objectForKey:@"label"]];
        }
        buttonHandler = [[WPDialogButtonHandler alloc] init];
        buttonHandler.buttonConfiguration = buttons;
        buttonHandler.notificationConfiguration = wonderPushData;
        dialog.delegate = buttonHandler;
    }
    else
    {
        [dialog addButtonWithTitle:WP_DEFAULT_BUTTON_LOCALIZED_LABEL];
    }
    [dialog show];
}

+(void) handleHtmlNotificaiton:(NSDictionary*) wonderPushData
{
    if (buttonHandler != nil) {
        // we currently support only one dialog at a time
        return;
    }
    CustomIOS7AlertView *alert = [[CustomIOS7AlertView alloc] init];
    UIWebView *view = [[UIWebView alloc] initWithFrame:CGRectMake(0, 0, 260, 300)];
    [view sizeToFit];
//    view.scalesPageToFit = YES;
    NSString *message = [wonderPushData valueForKey:@"message"];
    NSString *url = [wonderPushData valueForKey:@"url"];
    if (message != nil)
    {
        [view loadHTMLString:[wonderPushData valueForKey:@"message"] baseURL:nil];
    }
    else if (url != nil)
    {
        [view loadRequest:[[NSURLRequest alloc] initWithURL:[NSURL URLWithString:url]]];
    }
    else
    {
        WPLog(@"Error the link / url provided is null");
        return;
    }
    [view setBackgroundColor:[UIColor clearColor]];

    // setting rounded corners
    view.layer.cornerRadius = 10;
    view.scrollView.layer.cornerRadius = 10;

    //deactivate bounceScroll
    for (id subview in view.subviews)
        if ([[subview class] isSubclassOfClass: [UIScrollView class]])
            ((UIScrollView *)subview).bounces = NO;

    [alert setContainerView:view];

    NSArray *buttons = [wonderPushData objectForKey:@"buttons"];
    if (buttons != nil && [buttons count] > 0)
    {
        NSMutableArray *textButtons = [[NSMutableArray alloc] initWithCapacity:[buttons count]];
        for (NSDictionary *button in buttons)
        {
            [textButtons addObject:[button valueForKey:@"label"]];
        }
        buttonHandler = [[WPDialogButtonHandler alloc] init];
        buttonHandler.buttonConfiguration = buttons;
        buttonHandler.notificationConfiguration = wonderPushData;
        [alert setDelegate:buttonHandler];
        [alert setButtonTitles:textButtons];
    }
    else
    {
        [alert setButtonTitles:@[WP_DEFAULT_BUTTON_LOCALIZED_LABEL]];
    }
    [alert show];
}

+(void) handleMapNotificaiton:(NSDictionary*) wonderPushData
{
    if (buttonHandler != nil) {
        // we currently support only one dialog at a time
        return;
    }

    NSDictionary *mapData = [wonderPushData objectForKey:@"map"];
    if (mapData == nil)
    {
        return;
    }

    NSDictionary *place = [mapData objectForKey:@"place"];
    if (place == nil)
    {
        return;
    }

    NSDictionary *point = [place objectForKey:@"point"];
    if (point == nil)
    {
        return;
    }


    NSString *staticMapUrl = [NSString stringWithFormat:@"http://maps.google.com/maps/api/staticmap?markers=color:red|%f,%f&zoom=%ld&size=260x300&sensor=true",
                              [[point objectForKey:@"lat"] doubleValue], [[point objectForKey:@"lon"] doubleValue],(long)[[place objectForKey:@"zoom"] integerValue]];

    NSURL *mapUrl = [NSURL URLWithString:[staticMapUrl stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
    UIImage *image = [UIImage imageWithData: [NSData dataWithContentsOfURL:mapUrl]];


    CustomIOS7AlertView *alert = [[CustomIOS7AlertView alloc] init];
    UIImageView * view = [[UIImageView alloc] initWithImage:image];
    // setting rounded corners
    view.layer.masksToBounds = YES;
    view.layer.cornerRadius = 10;

   [alert setContainerView:view];

    NSArray *buttons = [wonderPushData objectForKey:@"buttons"];
    if (buttons != nil && [buttons count] > 0)
    {
        NSMutableArray *textButtons = [[NSMutableArray alloc] initWithCapacity:[buttons count]];
        for (NSDictionary *button in buttons)
        {
            [textButtons addObject:[button valueForKey:@"label"]];
        }
        buttonHandler = [[WPDialogButtonHandler alloc] init];
        buttonHandler.buttonConfiguration = buttons;
        buttonHandler.notificationConfiguration = wonderPushData;
        [alert setDelegate:buttonHandler];
        [alert setButtonTitles:textButtons];
    }
    else
    {
        [alert setButtonTitles:@[WP_DEFAULT_BUTTON_LOCALIZED_LABEL]];
    }
    [alert show];
}


#pragma mark - Push notification handling

+ (void) executeAction:(NSDictionary *)action onNotification:(NSDictionary *) notification
{
    NSString *type = [action objectForKey:@"type"];
    if ([type isEqualToString:WP_ACTION_TRACK])
    {
        NSDictionary *event = [action objectForKey:@"event"];
        if (event == nil)
        {
            return;
        }
        NSString *type = [event objectForKey:@"type"];
        NSDictionary *custom = [event objectForKey:@"custom"];
        [WonderPush trackEvent:type withData:custom];
    }
    if ([type isEqualToString:WP_ACTION_RATING])
    {
        NSBundle* mainBundle = [NSBundle mainBundle];
        NSString *itunesAppId = [mainBundle objectForInfoDictionaryKey:WP_ITUNES_APP_ID];
        if (itunesAppId != nil)
        {
            [[UIApplication sharedApplication] openURL:[NSURL URLWithString:[NSString stringWithFormat:ITUNES_APP_URL_FORMAT, itunesAppId]]];
        }

    }
    if ([type isEqualToString:WP_ACTION_METHOD_CALL])
    {
        NSString *methodName = [action objectForKey:@"method"];
        id methodParameter = [action objectForKey:@"methodArg"];
        if (!methodParameter) methodParameter = [NSNull null];
        NSDictionary *parameters = @{WP_REGISTERED_CALLBACK_PARAMETER_KEY: methodParameter};
        [[NSNotificationCenter defaultCenter]  postNotificationName:methodName
                                                             object:self
                                                           userInfo:parameters];
    }
    if ([type isEqualToString:WP_ACTION_LINK])
    {
        NSString *url = [action objectForKey:@"url"];
       [[UIApplication sharedApplication] openURL:[NSURL URLWithString:url]];
    }
    if ([type isEqualToString:WP_ACTION_MAP_OPEN])
    {
        NSDictionary *mapData = [notification objectForKey:@"map"];
        if (mapData == nil)
        {
            return;
        }

        NSDictionary *place = [mapData objectForKey:@"place"];
        if (place == nil)
        {
            return;
        }

        NSDictionary *point = [place objectForKey:@"point"];
        if (point == nil)
        {
            return;
        }
        NSString *url = [NSString stringWithFormat:@"http://maps.apple.com/?ll=%f,%f", [[point objectForKey:@"lat"] doubleValue], [[point objectForKey:@"lon"] doubleValue]];
        WPLog(@"url: %@", url);
        [[UIApplication sharedApplication] openURL:[NSURL URLWithString:url]];
    }
}

+ (BOOL) handleApplicationLaunchWithOption:(NSDictionary*) launchOptions
{
    WPLog(@"notification:  %@", launchOptions);
    if (launchOptions == nil)
    {
        return NO;
    }

    NSDictionary *notificationDictionary = [launchOptions objectForKey:UIApplicationLaunchOptionsRemoteNotificationKey];
    return [self handleNotification:notificationDictionary];
}

+(void) setDeviceToken:(NSString *) deviceToken
{
    deviceToken = [deviceToken stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"<>"]];
    deviceToken = [deviceToken stringByReplacingOccurrencesOfString:@" " withString:@""];
    [[WPConfiguration sharedConfiguration] setDeviceToken:deviceToken];

    [self updateInstallation:@{@"pushToken":@{@"data":deviceToken}} shouldOverwrite:NO];
}

+ (void) setNotificationEnabled:(BOOL) enabled
{
    if (enabled) {
        if ([[UIApplication sharedApplication] respondsToSelector:@selector(registerUserNotificationSettings:)]) {
            [[UIApplication sharedApplication] registerUserNotificationSettings:[UIUserNotificationSettings settingsForTypes:(UIUserNotificationTypeSound | UIUserNotificationTypeAlert | UIUserNotificationTypeBadge) categories:nil]];
            [[UIApplication sharedApplication] registerForRemoteNotifications];
        } else {
            [[UIApplication sharedApplication] registerForRemoteNotificationTypes:(UIRemoteNotificationTypeSound | UIRemoteNotificationTypeAlert)];
        }
    } else {
        [self setDeviceToken:@""];
        [[UIApplication sharedApplication] unregisterForRemoteNotifications];
    }
}


+ (BOOL) handleDidReceiveRemoteNotification:(NSDictionary *)userInfo
{
    return [self handleNotification:userInfo];
}

+ (BOOL) handleNotification:(NSDictionary*) notificationDictionary
{
    if (notificationDictionary == nil)
    {
        return NO;
    }

    NSDictionary *wonderpushData = [notificationDictionary objectForKey:WP_PUSH_NOTIFICATION_KEY];
    if (wonderpushData == nil)
    {
        return NO;
    }

    if ([UIApplication sharedApplication].applicationState == UIApplicationStateInactive)
    {
        // FIXME: Track notification received. Beware remote-notifications background mode!
        WPConfiguration *configuration = [WPConfiguration sharedConfiguration];
        [configuration addToQueuedNotifications:notificationDictionary];
        return YES;
    }

    id campagnId      = [wonderpushData objectForKey:@"c"];
    id notificationId = [wonderpushData objectForKey:@"n"];
    NSMutableDictionary *notificationInformations = [NSMutableDictionary new];
    if (campagnId)      notificationInformations[@"campaignId"]     = campagnId;
    if (notificationId) notificationInformations[@"notificationId"] = notificationId;

    NSString *type = [wonderpushData objectForKey:@"type"];
    if ([type isEqualToString:WP_PUSH_NOTIFICATION_SHOW_TEXT])
    {
        [self handleTextNotification:wonderpushData];
        [self handleNotificationTracking:notificationInformations];
        return YES;
    }
    else if ([type isEqualToString:WP_PUSH_NOTIFICATION_SHOW_HTML])
    {
        [self handleHtmlNotificaiton:wonderpushData];
        [self handleNotificationTracking:notificationInformations];
        return YES;
    }
    else if ([type isEqualToString:WP_PUSH_NOTIFICATION_SHOW_URL])
    {
        [self handleHtmlNotificaiton:wonderpushData];
        [self handleNotificationTracking:notificationInformations];
        return YES;
    }
    else if ([type isEqualToString:WP_PUSH_NOTIFICATION_SHOW_MAP])
    {
        [self handleMapNotificaiton:wonderpushData];
        [self handleNotificationTracking:notificationInformations];
        return YES;
    }


    return NO;
}

+ (void) didRegisterForRemoteNotificationsWithDeviceToken:(NSData*) deviceToken
{
    NSString *newToken = [deviceToken description];
    [WonderPush setDeviceToken:newToken];
}

+ (void) applicationDidBecomeActive:(UIApplication *)application;
{
    _lastAppOpen = [[NSProcessInfo processInfo] systemUptime];
    [self trackInternalEvent:@"@APP_OPEN" eventData:nil customData:nil];
    // Show any queued notifications
    WPConfiguration *configuration = [WPConfiguration sharedConfiguration];
    NSArray *queuedNotifications = [configuration getQueuedNotifications];
    for (NSDictionary *queuedNotification in queuedNotifications)
    {
        [self handleNotification:queuedNotification];
    }
    [configuration clearQueuedNotifications];
}

+ (void) applicationDidEnterBackground:(UIApplication *)application
{
    [self trackInternalEvent:@"@APP_CLOSE"
                   eventData:@{@"openedTime":(_lastAppOpen > 0
                                              ? [NSNumber numberWithLong:floor(1000 * ([[NSProcessInfo processInfo] systemUptime] - _lastAppOpen))]
                                              : [NSNull null])}
                  customData:nil];
    // Send queued notifications as LocalNotifications
    WPConfiguration *configuration = [WPConfiguration sharedConfiguration];
    NSArray *queuedNotifications = [configuration getQueuedNotifications];
    for (NSDictionary *queuedNotification in queuedNotifications)
    {
        [self handleNotificationReceivedInBackground:queuedNotification];
    }
    [configuration clearQueuedNotifications];
}


#pragma mark - Informations mining

+(BOOL) getProximitySensorSupported
{
    UIDevice *device = [UIDevice currentDevice];
    device.proximityMonitoringEnabled = YES;
    if (device.proximityMonitoringEnabled == YES) {
        device.proximityMonitoringEnabled = NO;
        return YES;
    }
    return NO;
}

+(BOOL) getGyroscopeSupported
{
#ifdef __IPHONE_4_0
    CMMotionManager *motionManager = [[CMMotionManager alloc] init];
    return motionManager.gyroAvailable;
#else
    return NO;
#endif
}

+(BOOL) getCompassSupported
{
    BOOL compassAvailable = NO;

#ifdef __IPHONE_3_0
	compassAvailable = [CLLocationManager headingAvailable];
#else
	CLLocationManager *cl = [[CLLocationManager alloc] init];
	compassAvailable = cl.headingAvailable;
#endif
    return compassAvailable;
}

+(BOOL) getMicrophoneSupported
{
    NSArray *availableInputs = [[AVAudioSession sharedInstance] availableInputs];
    for (AVAudioSessionPortDescription *port in availableInputs)
    {
        if ([port.portType isEqualToString:AVAudioSessionPortBuiltInMic] ||
            [port.portType isEqualToString:AVAudioSessionPortHeadsetMic])
        {
            return YES;
        }
    }
    return NO;
}

+(BOOL) getCameraSupported
{
    if ([UIImagePickerController isSourceTypeAvailable: UIImagePickerControllerSourceTypeCamera])
        return YES;
    return NO;
}

+(BOOL) getFrontCameraSupported
{
    if( [UIImagePickerController isCameraDeviceAvailable: UIImagePickerControllerCameraDeviceFront ])
        return YES;

    return NO;
}

+(BOOL) getGPSSupported
{
    struct utsname systemInfo;

    uname(&systemInfo);

    NSString* code = [NSString stringWithCString:systemInfo.machine
                                        encoding:NSUTF8StringEncoding];

    static NSDictionary* gpsCapabilityByCode = nil;

    if (!gpsCapabilityByCode) {

        gpsCapabilityByCode = @{ @"iPhone1,1"   : @NO,
                                 @"iPhone1,2"   : @YES,
                                 @"iPhone2,1"   : @YES,
                                 @"iPhone3,1"   : @YES,
                                 @"iPhone3,3"   : @YES,
                                 @"iPhone4,1"   : @YES,
                                 @"iPhone5,1"   : @YES,
                                 @"iPhone5,2"   : @YES,
                                 @"iPhone5,3"   : @YES,
                                 @"iPhone5,4"   : @YES,
                                 @"iPhone6,1"   : @YES,
                                 @"iPhone6,2"   : @YES,
                                 @"iPod1,1"     : @NO,
                                 @"iPod2,1"     : @NO,
                                 @"iPod3,1"     : @NO,
                                 @"iPod4,1"     : @NO,
                                 @"iPod5,1"     : @NO,
                                 @"iPad1,1"     : @NO,
                                 @"iPad2,1"     : @NO,
                                 @"iPad2,2"     : @YES,
                                 @"iPad2,3"     : @YES,
                                 @"iPad2,4"     : @NO,
                                 @"iPad2,5"     : @NO,
                                 @"iPad2,6"     : @YES,
                                 @"iPad2,7"     : @YES,
                                 @"iPad3,1"     : @NO,
                                 @"iPad3,2"     : @YES,
                                 @"iPad3,3"     : @YES,
                                 @"iPad3,4"     : @NO,
                                 @"iPad3,5"     : @YES,
                                 @"iPad3,6"     : @YES,
                                 @"iPad4,1"     : @NO,
                                 @"iPad4,2"     : @YES,
                                 @"iPad4,4"     : @NO,
                                 @"iPad4,5"     : @YES,
                                 @"i386"        : @NO,
                                 @"x86_64"      : @NO
                                 };
    }
    BOOL gpsCapability = [[gpsCapabilityByCode objectForKey:code] boolValue];

    if (!gpsCapability) {
        // Not found on database. At least guess main device type from string contents:

        if ([code rangeOfString:@"iPod"].location != NSNotFound) {
            gpsCapability = NO;
        }
        else if([code rangeOfString:@"iPad"].location != NSNotFound) {
            gpsCapability = NO; // this is not sure but it's still better than crashing
        }
        else if([code rangeOfString:@"iPhone"].location != NSNotFound){
            gpsCapability = YES;
        }
    }

    return gpsCapability;
}

+(BOOL) getTelephoneCDMASupported
{
    NSString *model = [self getDeviceModel];
    if ([model rangeOfString:@"CDMA"].location != NSNotFound ||
        [model isEqualToString:@"Verizon iPhone 4"]) {
        return YES;
    }
    return NO;
}

+(BOOL) getTelephonyGSMSupported
{
    NSString *model = [self getDeviceModel];
    if ([model rangeOfString:@"GSM"].location != NSNotFound ||
        [model isEqualToString:@"iPhone 1G"] || [model isEqualToString:@"iPhone 3G"] ||
        [model isEqualToString:@"iPhone 3GS"] || [model isEqualToString:@"iPhone 4"]) {
        return YES;
    }
    return NO;
}

+(BOOL) getTelephonySupported
{
    return [[UIApplication sharedApplication] canOpenURL:[NSURL URLWithString:@"tel://"]];
}

+(BOOL) getNFCSupported
{
    // Right now (18/10/2014) iphone 6 has been announced with NFC support however it seems that there is now opened API for developpers to use it,
    // It seems only limited to Apple Pay, the device name by code is not yet available so returning false for now
    // but will have to return true if iPhone 6 as soon as utsname.machine code for iPhone6 is known
    return NO;
}

+(BOOL) getBluetoothLeSupported
{
    UIDevice *currentDevice = [UIDevice currentDevice];
    if ([currentDevice.model rangeOfString:@"Simulator"].location == NSNotFound) {
        CBCentralManager *btManager = [[CBCentralManager alloc] initWithDelegate:nil queue:nil options:nil];
        if ([btManager state] == CBCentralManagerStateUnknown || [btManager state] == CBCentralManagerStateUnsupported) {
            return YES;
        }
    }
    return NO;
}

+(BOOL) getBluetoothSupported
{
    // right now we will assume that all apple iOS device have bluetooth as just iPod touch 1st gen and apple tv2 seems not to have any bluetooth
    return YES;
}

+(BOOL) getFingerprintScannerSupported
{
    // will be supported on iOS 8.0
    return NO;
}

+(NSString *) getDeviceName
{
    return [[UIDevice currentDevice] name];
}

+(NSString *) getDeviceModel
{
    struct utsname systemInfo;

    uname(&systemInfo);

    NSString* code = [NSString stringWithCString:systemInfo.machine
                                        encoding:NSUTF8StringEncoding];

    static NSDictionary* deviceNamesByCode = nil;

    if (!deviceNamesByCode) {

        deviceNamesByCode = @{ @"iPhone1,1"   : @"iPhone 1G",
                               @"iPhone1,2"   : @"iPhone 3G",
                               @"iPhone2,1"   : @"iPhone 3GS",
                               @"iPhone3,1"   : @"iPhone 4",
                               @"iPhone3,3"   : @"Verizon iPhone 4",
                               @"iPhone4,1"   : @"iPhone 4S",
                               @"iPhone5,1"   : @"iPhone 5 (GSM)",
                               @"iPhone5,2"   : @"iPhone 5 (GSM+CDMA)",
                               @"iPhone5,3"   : @"iPhone 5c (GSM)",
                               @"iPhone5,4"   : @"iPhone 5c (Global)",
                               @"iPhone6,1"   : @"iPhone 5s (GSM)",
                               @"iPhone6,2"   : @"iPhone 5s (Global)",
                               @"iPod1,1"     : @"iPod Touch 1G",
                               @"iPod2,1"     : @"iPod Touch 2G",
                               @"iPod3,1"     : @"iPod Touch 3G",
                               @"iPod4,1"     : @"iPod Touch 4G",
                               @"iPod5,1"     : @"iPod Touch 5G",
                               @"iPad1,1"     : @"iPad",
                               @"iPad2,1"     : @"iPad 2 (WiFi)",
                               @"iPad2,2"     : @"iPad 2 (GSM)",
                               @"iPad2,3"     : @"iPad 2 (CDMA)",
                               @"iPad2,4"     : @"iPad 2 (WiFi)",
                               @"iPad2,5"     : @"iPad Mini (WiFi)",
                               @"iPad2,6"     : @"iPad Mini (GSM)",
                               @"iPad2,7"     : @"iPad Mini (GSM+CDMA)",
                               @"iPad3,1"     : @"iPad 3 (WiFi)",
                               @"iPad3,2"     : @"iPad 3 (GSM+CDMA)",
                               @"iPad3,3"     : @"iPad 3 (GSM)",
                               @"iPad3,4"     : @"iPad 4 (WiFi)",
                               @"iPad3,5"     : @"iPad 4 (GSM)",
                               @"iPad3,6"     : @"iPad 4 (GSM+CDMA)",
                               @"iPad4,1"     : @"iPad Air (WiFi)",
                               @"iPad4,2"     : @"iPad Air (GSM)",
                               @"iPad4,4"     : @"iPad Mini Retina (WiFi)",
                               @"iPad4,5"     : @"iPad Mini Retina (GSM)",
                               @"i386"        : @"Simulator",
                               @"x86_64"      : @"Simulator"
                              };
    }

    NSString* deviceName = [deviceNamesByCode objectForKey:code];

    if (!deviceName) {
        // Not found on database. At least guess main device type from string contents:

        if ([code rangeOfString:@"iPod"].location != NSNotFound) {
            deviceName = @"iPod Touch";
        }
        else if([code rangeOfString:@"iPad"].location != NSNotFound) {
            deviceName = @"iPad";
        }
        else if([code rangeOfString:@"iPhone"].location != NSNotFound){
            deviceName = @"iPhone";
        }
    }

    return deviceName;
}

+(CGRect) getScreenSize
{
    return [[UIScreen mainScreen] bounds];
}

+(NSInteger) getScreenDensity
{
    CGFloat density = [[UIScreen mainScreen] scale];
    return density;
}

+(NSString *) getTimezone
{
    NSTimeZone *timeZone = [NSTimeZone localTimeZone];
    return [timeZone name];
}

+(NSString *) getCarrierName
{
    CTTelephonyNetworkInfo *netinfo = [[CTTelephonyNetworkInfo alloc] init];
    CTCarrier *carrier = [netinfo subscriberCellularProvider];
    if (carrier == nil) {
        return @"unknown";
    }
    return [carrier carrierName];
}

+(NSString *) getVersionString
{
    return [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
}

+(NSString *) getLocale
{
    return [[NSLocale currentLocale] localeIdentifier];
}

+(NSString *) getOsVersion
{
    return [[UIDevice currentDevice] systemVersion];
}


#pragma mark - REST API Access

+ (void) post:(NSString *)resource params:(id)params handler:(void(^)(WPResponse *response, NSError *error))handler
{
    WPClient *client = [WPClient sharedClient];
    WPRequest *request = [[WPRequest alloc] init];
    NSMutableDictionary *parameters = [[NSMutableDictionary alloc] initWithDictionary:params];
    [parameters setObject:[NSString stringWithFormat:@"%lld", [WPUtil getServerDate]] forKey:@"timestamp"];
    request.method = @"POST";
    request.resource = resource;
    request.handler = handler;
    request.params = parameters;

    [client requestAuthenticated:request];
}

+ (void) get:(NSString *)resource params:(id)params handler:(void(^)(WPResponse *response, NSError *error))handler
{
    WPClient *client = [WPClient sharedClient];
    WPRequest *request = [[WPRequest alloc] init];
    NSMutableDictionary *parameters = [[NSMutableDictionary alloc] initWithDictionary:params];
    [parameters setObject:[NSString stringWithFormat:@"%lld", [WPUtil getServerDate]] forKey:@"timestamp"];
    request.method = @"GET";
    request.resource = resource;
    request.handler = handler;
    request.params = parameters;
    [client requestAuthenticated:request];
}

+ (void) delete:(NSString *)resource params:(id)params handler:(void(^)(WPResponse *response, NSError *error))handler
{
    WPClient *client = [WPClient sharedClient];
    WPRequest *request = [[WPRequest alloc] init];
    NSMutableDictionary *parameters = [[NSMutableDictionary alloc] initWithDictionary:params];
    [parameters setObject:[NSString stringWithFormat:@"%lld", [WPUtil getServerDate]] forKey:@"timestamp"];
    request.method = @"DELETE";
    request.resource = resource;
    request.handler = handler;
    request.params = parameters;
    [client requestAuthenticated:request];
}

+ (void) put:(NSString *)resource params:(id)params handler:(void(^)(WPResponse *response, NSError *error))handler
{
    WPClient *client = [WPClient sharedClient];
    WPRequest *request = [[WPRequest alloc] init];
    NSMutableDictionary *parameters = [[NSMutableDictionary alloc] initWithDictionary:params];
    [parameters setObject:[NSString stringWithFormat:@"%lld", [WPUtil getServerDate]] forKey:@"timestamp"];
    request.method = @"PUT";
    request.resource = resource;
    request.handler = handler;
    request.params = parameters;
    [client requestAuthenticated:request];
}

+ (void) postEventually:(NSString *)resource params:(id)params handler:(void(^)(WPResponse *response, NSError *error))handler
{
    WPClient *client = [WPClient sharedClient];
    WPRequest *request = [[WPRequest alloc] init];
    NSMutableDictionary *parameters = [[NSMutableDictionary alloc] initWithDictionary:params];
    [parameters setObject:[NSString stringWithFormat:@"%lld", [WPUtil getServerDate]] forKey:@"timestamp"];
    request.method = @"POST";
    request.resource = resource;
    request.handler = handler;
    request.params = parameters;
    [client requestEventually:request];
}


#pragma mark - Language

+ (NSArray *)validLanguageCodes
{
    static NSArray *result = nil;
    if (!result)
        result = @[@"af", @"ar", @"be",
                   @"bg", @"bn", @"ca", @"cs", @"da", @"de", @"el", @"en", @"en_GB", @"en_US",
                   @"es", @"es_ES", @"es_MX", @"et", @"fa", @"fi", @"fr", @"fr_FR", @"fr_CA",
                   @"he", @"hi", @"hr", @"hu", @"id", @"is", @"it", @"ja", @"ko", @"lt", @"lv",
                   @"mk", @"ms", @"nb", @"nl", @"pa", @"pl", @"pt", @"pt_PT", @"pt_BR", @"ro",
                   @"ru", @"sk", @"sl", @"sq", @"sr", @"sv", @"sw", @"ta", @"th", @"tl", @"tr",
                   @"uk", @"vi", @"zh", @"zh_CN", @"zh_TW", @"zh_HK",
                   ];
    return result;
}

+ (NSString *)languageCode
{
    if (_currentLanguageCode != nil) {
        return _currentLanguageCode;
    }
    NSArray *preferredLanguageCodes = [NSLocale preferredLanguages];
    return [self wonderpushLanguageCodeForLocaleLanguageCode:preferredLanguageCodes.count ? [preferredLanguageCodes objectAtIndex:0] : @"en"];
}

+(void) setLanguageCode:(NSString *) languageCode {
    if ([[self validLanguageCodes] containsObject:languageCode]) {
        _currentLanguageCode = languageCode;
    }
    return;
}

+ (NSString *)wonderpushLanguageCodeForLocaleLanguageCode:(NSString *)localeLanguageCode
{
    NSString *code = [localeLanguageCode stringByReplacingOccurrencesOfString:@"-" withString:@"_"];
    if ([[self validLanguageCodes] containsObject:code])
        return code;
    return @"en";
}

+ (CLLocation *)location
{
    return LocationManager.location;
}

+(void) handleNotificationTracking:(NSDictionary *) notificationInformation
{
    NSBundle *bundle = [NSBundle mainBundle];
    NSArray *backgroundModes = [bundle objectForInfoDictionaryKey:@"UIBackgroundModes"];
    BOOL hasBackgroundMode = NO;
    if (backgroundModes != nil) {
        WPLog(@"backgroundModes not nil : %@", backgroundModes);
        for (NSString *value in backgroundModes)
        {
            if ([value isEqual:@"remote-notification"])
            {
                hasBackgroundMode = YES;
            }
        }
    }

    [self trackNotificationReceived:notificationInformation];

    [self trackInternalEvent:@"@NOTIFICATION_OPENED" eventData:notificationInformation customData:nil];
}

+(void) handleNotificationReceivedInBackground:(NSDictionary *)userInfo
{
    UILocalNotification *notification = [[UILocalNotification alloc] init];
    if (![WPUtil currentApplicationIsInForeground]) {
        NSDictionary *aps = [userInfo objectForKey:@"aps"];
        notification.alertBody =  [aps objectForKey:@"alert"];
        notification.soundName = [aps objectForKey:@"sound"];
        notification.userInfo = userInfo;
        [[UIApplication sharedApplication] presentLocalNotificationNow:notification];
    }
    NSDictionary *wpData = [userInfo objectForKey:WP_PUSH_NOTIFICATION_KEY];
    if (!wpData)
    {
        // This notification is not targetted for WonderPush SDK consumption.
        return;
    }
    id campagnId      = [wpData objectForKey:@"c"];
    id notificationId = [wpData objectForKey:@"n"];
    NSMutableDictionary *notificationInformations = [NSMutableDictionary new];
    if (campagnId)      notificationInformations[@"campaignId"]     = campagnId;
    if (notificationId) notificationInformations[@"notificationId"] = notificationId;
    [WonderPush trackNotificationReceived:notificationInformations];
}

+ (void) trackNotificationReceived:(NSDictionary *) eventData
{
    id campaignId = [eventData objectForKey:@"campaignId"];

    if (campaignId && [[WPConfiguration sharedConfiguration] isInEventReceivedHistory:campaignId])
    {
        return;
    }

    [self trackInternalEvent:@"@NOTIFICATION_RECEIVED" eventData:eventData customData:nil];

    [[WPConfiguration sharedConfiguration] addToEventReceivedHistory:campaignId];
}

+(void) trackInternalEvent:(NSString *) type eventData:(NSDictionary *) data customData:(NSDictionary *) customData
{
    if ([type characterAtIndex:0] != '@')
    {
        @throw [NSException exceptionWithName:@"illegal argument" reason:@"This method must only be called for internal events, starting with an '@'" userInfo:nil];
    }

    [self trackEvent:type eventData:data customData:customData];
}

+ (void) trackEvent:(NSString *) type eventData:(NSDictionary *) data customData:(NSDictionary *) customData
{
    if (type == nil)
    {
        return;
    }
    NSString *eventEndPoint = @"/events";
    long long date = [WPUtil getServerDate];
    NSMutableDictionary *params = [[NSMutableDictionary alloc] initWithDictionary:@{@"type": type,
                            @"actionDate": [NSNumber numberWithLongLong:date]}];

    if (data != nil)
    {
        for (NSString *key in data)
        {
            [params setValue:[data objectForKey:key] forKey:key];
        }
    }

    if (customData != nil)
    {
        [params setValue:customData forKey:@"custom"];
    }

    CLLocation *location = [self location];
    if (location != nil)
    {
        [params setValue:[NSString stringWithFormat:@"%f,%f", location.coordinate.latitude, location.coordinate.longitude] forKey:@"location"];
    }

    NSError *err;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:params options:0 error:&err];
    NSString *eventString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    [self postEventually:eventEndPoint params:@{@"body":eventString} handler:
     ^(WPResponse *response, NSError *error) {

     }];

}

+ (void) trackEvent:(NSString*) type withData:(id)data
{
    [self trackEvent:type eventData:nil customData:data];
}

@end

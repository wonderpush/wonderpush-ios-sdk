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

#import "WPConfiguration.h"


static WPConfiguration *sharedConfiguration = nil;

@interface WPConfiguration ()

@property (nonatomic, strong) NSString *accessToken;

@end


@implementation WPConfiguration

@synthesize accessToken = _accessToken;
@synthesize deviceToken = _deviceToken;
@synthesize sid = _sid;
@synthesize userId = _userId;
@synthesize installationId = _installationId;
@synthesize timeOffset = _timeOffset;
@synthesize timeOffsetPrecision = _timeOffsetPrecision;

+ (void) initialize
{
    sharedConfiguration = [[self alloc] init];
}

+ (WPConfiguration *)sharedConfiguration
{
    return sharedConfiguration;
}


#pragma mark - Access token

- (NSURL *) baseURL
{
    return [NSURL URLWithString:PRODUCTION_API_URL];
}

- (NSString *)accessToken
{
    if (_accessToken)
        return _accessToken;

    _accessToken = [[NSUserDefaults standardUserDefaults] valueForKey:USER_DEFAULTS_ACCESS_TOKEN_KEY];
    return _accessToken;
}

- (NSString *)deviceToken
{
    if (_deviceToken)
        return _deviceToken;

    _deviceToken = [[NSUserDefaults standardUserDefaults] valueForKey:USER_DEFAULTS_DEVICE_TOKEN_KEY];
    return _deviceToken;
}

- (void) setDeviceToken:(NSString *)deviceToken
{
    _deviceToken = deviceToken;

    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    WPLog(@"Setting device token: %@", deviceToken);
    if (deviceToken)
        [defaults setValue:deviceToken forKey:USER_DEFAULTS_DEVICE_TOKEN_KEY];
    else
        [defaults removeObjectForKey:USER_DEFAULTS_DEVICE_TOKEN_KEY];

    [defaults synchronize];
}

- (void) setAccessToken:(NSString *)accessToken
{
    _accessToken = accessToken;

    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];

    WPLog(@"Setting access token: %@", accessToken);
    if (accessToken)
        [defaults setValue:accessToken forKey:USER_DEFAULTS_ACCESS_TOKEN_KEY];
    else
        [defaults removeObjectForKey:USER_DEFAULTS_ACCESS_TOKEN_KEY];

    [defaults synchronize];
}

-(void) setStoredClientId:(NSString *)clientId;
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    if (clientId) {
        [defaults setValue:clientId forKey:USER_DEFAULTS_CLIENT_ID_KEY];
    }
}

-(NSString *) getStoredClientId
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    return [defaults valueForKey:USER_DEFAULTS_CLIENT_ID_KEY];
}


#pragma mark - EVENT RECEIVED HISTORY

-(void) setEventReceivedHistory:(NSArray *)eventReceivedHistory
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    if (eventReceivedHistory)
        [defaults setValue:[eventReceivedHistory componentsJoinedByString:@","] forKey:USER_DEFAULTS_EVENT_RECEIVED_HISTORY];
    else
        [defaults removeObjectForKey:USER_DEFAULTS_EVENT_RECEIVED_HISTORY];
    [defaults synchronize];
}

-(NSArray *) getEventReceivedHistory
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];

    NSString *eventHistory = [defaults valueForKey:USER_DEFAULTS_EVENT_RECEIVED_HISTORY];
    if (eventHistory != nil) {
        return [eventHistory componentsSeparatedByString:@","];
    }
    return [[NSArray alloc] init];
}

-(void) addToEventReceivedHistory:(NSString *) campaignId
{
    if (!campaignId)
        return;

    NSArray *eventHistory = [self getEventReceivedHistory];
    NSMutableArray *editableHistory = [[NSMutableArray alloc] initWithArray:eventHistory];
    if ([editableHistory count] > EVENT_RECEIVED_HISTORY_SIZE) {
        [editableHistory removeObjectAtIndex:0];
    }
    [editableHistory addObject:campaignId];

    [self setEventReceivedHistory:editableHistory];
}

-(BOOL) isInEventReceivedHistory:(NSString *) campaignId
{
    if (!campaignId)
        return NO;

    NSArray *eventHistory = [self getEventReceivedHistory];
    for (NSString * notification in eventHistory)
    {
        if ([campaignId isEqualToString:notification])
        {
            return YES;
        }
    }
    return NO;
}


#pragma mark - INSTALLATION ID

-(NSString *) installationId
{
    if (_installationId)
        return _installationId;

    _installationId = [[NSUserDefaults standardUserDefaults] valueForKey:USER_DEFAULTS_INSTALLATION_ID];
    return _installationId;
}

-(void) setInstallationId:(NSString *)installationId
{
    _installationId = installationId;
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];

    if (installationId) {
        [defaults setValue:installationId forKeyPath:USER_DEFAULTS_INSTALLATION_ID];
    } else {
        [defaults removeObjectForKey:USER_DEFAULTS_INSTALLATION_ID];
    }

    [defaults synchronize];
}


#pragma mark - USER ID

-(NSString *) userId
{
    if (_userId)
        return _userId;

    _userId = [[NSUserDefaults standardUserDefaults] valueForKey:USER_DEFAULTS_USER_ID_KEY];
    return _userId;
}

-(void) setUserId:(NSString *) userId
{
    if ((userId == nil && self.userId != nil)
        || (userId != nil && ![userId isEqualToString:self.userId]))
    {
        // unlogging
        self.accessToken = nil;
        self.sid = nil;
    }
    _userId = userId;

    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    WPLog(@"Setting userId: %@", userId);
    if (userId)
        [defaults setValue:userId forKey:USER_DEFAULTS_USER_ID_KEY];
    else
        [defaults removeObjectForKey:USER_DEFAULTS_USER_ID_KEY];
    [defaults synchronize];
}


#pragma mark - SID

- (NSString *)sid
{
    if (_sid)
        return _sid;

    _sid = [[NSUserDefaults standardUserDefaults] valueForKey:USER_DEFAULTS_SID_KEY];
    return _sid;
}

- (void) setSid:(NSString *)sid
{
    _sid = sid;

    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    WPLog(@"Setting sid: %@", sid);
    if (sid)
        [defaults setValue:sid forKey:USER_DEFAULTS_SID_KEY];
    else
        [defaults removeObjectForKey:USER_DEFAULTS_SID_KEY];
    [defaults synchronize];
}

- (BOOL) usesSandbox
{
    return [[self.baseURL absoluteString] rangeOfString:PRODUCTION_API_URL].location == NSNotFound;
}

@end

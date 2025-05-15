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

#import "WPRequest.h"

@interface WPRequest ()

@property (nonatomic, strong, nonnull) NSString *requestId;

@end


@implementation WPRequest

- (instancetype _Nullable) init
{
    if (self = [super init]) {
        self.requestId = [[NSUUID UUID] UUIDString];
    }
    return self;
}

- (nonnull id)copyWithZone:(nullable NSZone *)zone
{
    WPRequest *copy = [[WPRequest allocWithZone:zone] init];
    copy.requestId = self.requestId;
    copy.userId = self.userId;
    copy.method = self.method;
    copy.handler = self.handler;
    copy.resource = self.resource;
    copy.params = [self.params copy];
    return copy;
}

- (instancetype _Nullable) initFromJSON:(NSDictionary *)dict
{
    if (self = [super init]) {
        id value;

        value = dict[@"requestId"];
        if ([value isKindOfClass:[NSString class]]) {
            self.requestId = value;
        } else {
            self.requestId = [[NSUUID UUID] UUIDString];
        }

        value = dict[@"userId"];
        if ([value isKindOfClass:[NSString class]]) {
            self.userId = value;
        } else {
            self.userId = nil;
        }

        value = dict[@"method"];
        if ([value isKindOfClass:[NSString class]]) {
            self.method = value;
        } else {
            return nil;
        }

        value = dict[@"resource"];
        if ([value isKindOfClass:[NSString class]]) {
            self.resource = value;
        } else {
            return nil;
        }

        value = dict[@"params"];
        if ([value isKindOfClass:[NSDictionary class]]) {
            self.params = value;
        } else {
            self.params = @{};
        }

        self.handler = nil;
    }
    return self;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<WPRequest requestId=%@ userId=%@ method=%@ resource=%@ params=%@", self.requestId, self.userId, self.method, self.resource, self.params];
}

- (BOOL) isEqual:(id)object
{
    if ([object isKindOfClass:[self class]]) {
        WPRequest *request = (WPRequest *)object;
        BOOL userId = (nil == self.userId && nil == request.userId) || [self.userId isEqual:request.userId];
        BOOL method = (nil == self.method && nil == request.method) || [self.method isEqual:request.method];
        BOOL params = (nil == self.params && nil == request.params) || [self.params isEqual:request.params];
        BOOL resource = (nil == self.resource && nil == request.resource) || [self.resource isEqual:request.resource];
        BOOL requestId = (nil == self.requestId && nil == request.requestId) || [self.requestId isEqual:request.requestId];
        return userId && method && params && resource && requestId;
    }
    return [super isEqual:object];
}

- (NSDictionary * _Nonnull) toJSON
{
    return @{
        @"requestId": self.requestId ?: [NSNull null],
        @"userId":    self.userId    ?: [NSNull null],
        @"method":    self.method    ?: [NSNull null],
        @"resource":  self.resource  ?: [NSNull null],
        @"params":    self.params    ?: [NSNull null],
    };
}



#pragma mark - Resource

- (void) setResource:(NSString * _Nonnull)resource
{
    // Remove any leading /
    if (resource && [resource rangeOfString:@"/"].location == 0)
        resource = resource.length > 1 ? [resource substringFromIndex:1] : @"";

    _resource = resource;
}

@end

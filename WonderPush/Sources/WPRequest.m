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

@property (nonatomic, strong) NSString *requestId;

@end


@implementation WPRequest

- (id) init
{
    if (self = [super init]) {
        self.requestId = [[NSUUID UUID] UUIDString];
    }
    return self;
}

- (id) copyWithZone:(NSZone *)zone
{
    WPRequest *copy = [[WPRequest allocWithZone:zone] init];
    copy.userId = self.userId;
    copy.method = self.method;
    copy.handler = self.handler;
    copy.resource = self.resource;
    copy.params = [self.params copy];
    return copy;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<WPRequest userId=%@ method=%@ resource=%@ params=%@", self.userId, self.method, self.resource, self.params];
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

- (void) encodeWithCoder:(NSCoder *)aCoder
{
    [aCoder encodeObject:self.resource];
    [aCoder encodeObject:self.params];
    [aCoder encodeObject:self.method];
    [aCoder encodeObject:self.requestId];
    [aCoder encodeObject:self.userId];
}

- (id) initWithCoder:(NSCoder *)aDecoder
{
    if (self = [self init]) {
        self.resource = [aDecoder decodeObject];
        self.params = [aDecoder decodeObject];
        self.method = [aDecoder decodeObject];
        self.requestId = [aDecoder decodeObject];
        self.userId = [aDecoder decodeObject];
    }
    return self;
}

- (NSDictionary *) toJSON
{
    return @{
             @"requestId": self.requestId ?: [NSNull null],
             @"userId": self.userId ?: [NSNull null],
             @"method": self.method ?: [NSNull null],
             @"resource": self.resource ?: [NSNull null],
             @"params": self.params ?: [NSNull null],
             };
}



#pragma mark - Resource

- (void) setResource:(NSString *)resource
{
    // Remove any leading /
    if (resource && [resource rangeOfString:@"/"].location == 0)
        resource = resource.length > 1 ? [resource substringFromIndex:1] : @"";

    _resource = resource;
}

@end

//
//  WPRequestSerializer.h
//  WonderPush
//
//  Created by Stéphane JAIS on 14/02/2019.
//  Copyright © 2019 WonderPush. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface WPRequestSerializer: NSObject
@property (strong, nonatomic) NSSet *HTTPMethodsEncodingParametersInURI;
@property (assign, nonatomic) NSStringEncoding stringEncoding;
+ (NSString *) percentEscapedStringFromString:(NSString *)string;
+ (NSString *) userAgentWithClientId:(NSString *)clientId;
+ (NSString *) wonderPushAuthorizationHeaderValueForRequest:(NSURLRequest *)request clientSecret:(NSString *)secret;
+ (NSString *) queryStringFromParameters:(NSDictionary *)parameters;
- (NSURLRequest *)requestBySerializingRequest:(NSURLRequest *)request
                               withParameters:(id)parameters
                                    clientId:(NSString *)clientId
                                 clientSecret:(NSString *)secret
                                        error:(NSError **)error;
@end



/*
 * Copyright 2017 Google
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#import "WPCore+InAppMessaging.h"
#import "WPIAMMessageContentData.h"
#import "WPIAMMessageContentDataWithImageURL.h"
#import "WPIAMSDKRuntimeErrorCodes.h"

static NSInteger const SuccessHTTPStatusCode = 200;

@interface WPIAMMessageContentDataWithImageURL ()
@property(nonatomic, readwrite, nonnull, copy) NSString *titleText;
@property(nonatomic, readwrite, nonnull, copy) NSString *bodyText;
@property(nonatomic, copy, nullable) NSString *actionButtonText;
@property(nonatomic, copy, nullable) NSString *secondaryActionButtonText;
@property(nonatomic, copy, nullable) WPAction *action;
@property(nonatomic, copy, nullable) WPAction *secondaryAction;
@property(nonatomic, nullable, copy) NSURL *imageURL;
@property(nonatomic, nullable, copy) NSURL *landscapeImageURL;
@property(nonatomic, readwrite) WPIAMCloseButtonPosition closeButtonPosition;
@property(nonatomic, readwrite) WPIAMEntryAnimation entryAnimation;
@property(nonatomic, readwrite) WPIAMExitAnimation exitAnimation;
@property(nonatomic, readwrite) WPIAMBannerPosition bannerPosition;
@property(readonly) NSURLSession *URLSession;
@end

@implementation WPIAMMessageContentDataWithImageURL
- (instancetype)initWithMessageTitle:(NSString *)title
                         messageBody:(NSString *)body
                    actionButtonText:(nullable NSString *)actionButtonText
           secondaryActionButtonText:(nullable NSString *)secondaryActionButtonText
                              action:(nullable WPAction *)action
                     secondaryAction:(nullable WPAction *)secondaryAction
                            imageURL:(nullable NSURL *)imageURL
                   landscapeImageURL:(nullable NSURL *)landscapeImageURL
                 closeButtonPosition:(WPIAMCloseButtonPosition)closeButtonPosition
                      bannerPosition:(WPIAMBannerPosition)bannerPosition
                      entryAnimation:(WPIAMEntryAnimation)entryAnimation
                       exitAnimation:(WPIAMExitAnimation)exitAnimation
                     usingURLSession:(nullable NSURLSession *)URLSession {
    if (self = [super init]) {
        _titleText = title;
        _bodyText = body;
        _imageURL = imageURL;
        _landscapeImageURL = landscapeImageURL;
        _actionButtonText = actionButtonText;
        _secondaryActionButtonText = secondaryActionButtonText;
        _action = action;
        _secondaryAction = secondaryAction;
        _closeButtonPosition = closeButtonPosition;
        _bannerPosition = bannerPosition;
        _entryAnimation = entryAnimation;
        _exitAnimation = exitAnimation;
        
        if (imageURL) {
            _URLSession = URLSession ? URLSession : [NSURLSession sharedSession];
        }
    }
    return self;
}

#pragma protocol WPIAMMessageContentData

- (NSString *)description {
    return [NSString stringWithFormat:@"Message content: title '%@',"
            "body '%@', imageURL '%@', action '%@'",
            self.titleText, self.bodyText, self.imageURL, self.action];
}

- (NSString *)getTitleText {
    return _titleText;
}

- (NSString *)getBodyText {
    return _bodyText;
}

- (nullable NSString *)getActionButtonText {
    return _actionButtonText;
}

- (void)loadImageDataWithBlock:(void (^)(NSData *_Nullable standardImageData,
                                         NSData *_Nullable landscapeImageData,
                                         NSError *_Nullable error))block {
    if (!block) {
        // no need for any further action if block is nil
        return;
    }
    
    if (!_imageURL && !_landscapeImageURL) {
        // no image data since image url is nil
        block(nil, nil, nil);
    } else if (!_landscapeImageURL) {
        // Only fetch standard image.
        [self fetchImageFromURL:_imageURL
                      withBlock:^(NSData *_Nullable imageData, NSError *_Nullable error) {
            block(imageData, nil, error);
        }];
    } else if (!_imageURL) {
        // Only fetch portrait image.
        [self fetchImageFromURL:_landscapeImageURL
                      withBlock:^(NSData *_Nullable imageData, NSError *_Nullable error) {
            block(nil, imageData, error);
        }];
    } else {
        // Fetch both images separately, call completion when they're both fetched.
        __block NSData *portrait = nil;
        __block NSData *landscape = nil;
        __block NSError *landscapeImageLoadError = nil;
        
        [self fetchImageFromURL:_imageURL
                      withBlock:^(NSData *_Nullable imageData, NSError *_Nullable error) {
            __weak WPIAMMessageContentDataWithImageURL *weakSelf = self;
            
            // If the portrait image fails to load, we treat this as a failure.
            if (error) {
                // Cancel landscape image fetch.
                [weakSelf.URLSession invalidateAndCancel];
                
                block(nil, nil, error);
                return;
            }
            
            portrait = imageData;
            if (landscape || landscapeImageLoadError) {
                block(portrait, landscape, nil);
            }
        }];
        
        [self fetchImageFromURL:_landscapeImageURL
                      withBlock:^(NSData *_Nullable imageData, NSError *_Nullable error) {
            if (error) {
                landscapeImageLoadError = error;
            } else {
                landscape = imageData;
            }
            
            if (portrait) {
                block(portrait, landscape, nil);
            }
        }];
    }
}

- (void)fetchImageFromURL:(NSURL *)imageURL
                withBlock:(void (^)(NSData *_Nullable imageData, NSError *_Nullable error))block {
    NSURLRequest *imageDataRequest = [NSURLRequest requestWithURL:imageURL];
    NSURLSessionDataTask *task = [_URLSession
                                  dataTaskWithRequest:imageDataRequest
                                  completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error) {
            WPLog( @"Error in fetching image: %@",
                          error);
            block(nil, error);
        } else {
            if ([response isKindOfClass:[NSHTTPURLResponse class]]) {
                NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
                if (httpResponse.statusCode == SuccessHTTPStatusCode) {
                    if (httpResponse.MIMEType == nil || ![httpResponse.MIMEType hasPrefix:@"image"]) {
                        NSString *errorDesc =
                        [NSString stringWithFormat:@"No image MIME type %@"
                         " detected for URL %@",
                         httpResponse.MIMEType, self.imageURL];
                        WPLog( @"%@", errorDesc);
                        
                        NSError *error =
                        [NSError errorWithDomain:kWonderPushInAppMessagingErrorDomain
                                            code:WPIAMSDKRuntimeErrorNonImageMimetypeFromImageURL
                                        userInfo:@{NSLocalizedDescriptionKey : errorDesc}];
                        block(nil, error);
                    } else {
                        block(data, nil);
                    }
                } else {
                    NSString *errorDesc =
                    [NSString stringWithFormat:@"Failed HTTP request to crawl image %@: "
                     "HTTP status code as %ld",
                     self->_imageURL, (long)httpResponse.statusCode];
                    WPLog( @"%@", errorDesc);
                    NSError *error = [NSError errorWithDomain:NSURLErrorDomain
                                                         code:httpResponse.statusCode
                                                     userInfo:@{NSLocalizedDescriptionKey : errorDesc}];
                    block(nil, error);
                }
            } else {
                NSString *errorDesc =
                [NSString stringWithFormat:@"Internal error: got a non HTTP response from "
                 @"fetching image for image URL as %@",
                 imageURL];
                WPLog( @"%@", errorDesc);
                NSError *error = [NSError errorWithDomain:NSURLErrorDomain
                                                     code:WPIAMSDKRuntimeErrorNonHTTPResponseForImage
                                                 userInfo:@{NSLocalizedDescriptionKey : errorDesc}];
                block(nil, error);
            }
        }
    }];
    [task resume];
}

@end

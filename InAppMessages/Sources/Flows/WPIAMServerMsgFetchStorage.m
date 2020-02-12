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
#import "WPIAMServerMsgFetchStorage.h"
@implementation WPIAMServerMsgFetchStorage
- (NSString *)determineCacheFilePath {
    NSString *cachePath =
    NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES)[0];
    NSString *filePath = [NSString stringWithFormat:@"%@/wonderpush-iam-messages-cache", cachePath];
    WPLogDebug(@"Persistent file path for fetch response data is %@", filePath);
    return filePath;
}

- (void)saveResponseDictionary:(NSDictionary *)response
                withCompletion:(void (^)(BOOL success))completion {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0ul), ^{
        NSError *error = nil;
        NSData *JSONData = [NSJSONSerialization dataWithJSONObject:response options:0 error:&error];
        if (error) {
            WPLog(@"Could not save response data: %@", error);
            completion(NO);
            return;
        }
        if ([JSONData writeToFile:[self determineCacheFilePath] atomically:YES]) {
            completion(YES);
        } else {
            completion(NO);
        }
    });
}

- (void)readResponseDictionary:(void (^)(NSDictionary *response, BOOL success))completion {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0ul), ^{
        NSString *storageFilePath = [self determineCacheFilePath];
        if ([[NSFileManager defaultManager] fileExistsAtPath:storageFilePath]) {
            NSData *JSONDataFromFile = [NSData dataWithContentsOfFile:[self determineCacheFilePath]];
            NSError *error = nil;
            if (JSONDataFromFile) {
                id JSONObject = [NSJSONSerialization JSONObjectWithData:JSONDataFromFile options:0 error:&error];
                if (!error && [JSONObject isKindOfClass:[NSDictionary class]]) {
                    WPLogDebug(@"Loaded response from fetch storage successfully.");
                    completion((NSDictionary *)JSONObject, YES);
                    return;
                }
            }
            WPLog(@"Not able to read response from fetch storage: %@", error ? error : @"unknown error");
            completion(nil, NO);
        } else {
            WPLogDebug(@"Local fetch storage file not existent yet: first time launch of the app.");
            completion(nil, YES);
        }
    });
}
@end

/*
 Copyright 2015 WonderPush

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

#import "WPLog.h"

#import <Foundation/Foundation.h>

static BOOL _loggingEnabled = NO;

void WPLogEnable(BOOL enabled)
{
    _loggingEnabled = enabled;
}

BOOL WPLogEnabled(void)
{
    return _loggingEnabled;
}

void WPLogv(NSString *format, va_list args)
{
    NSString *content = [[NSString alloc] initWithFormat:format arguments:args];
    if ([content length] < 900) {
        // Output seems to truncate with `<…>` after 1020 characters
        NSLog(@"[WonderPush] %@", content);
    } else {
        NSArray<NSString *> *lines = [content componentsSeparatedByString:@"\n"];
        NSInteger lineCount = [lines count];
        NSInteger maxLines = MIN(lineCount, 100);

        for (NSInteger i = 0; i < maxLines; i++) {
            NSString *leftChar = i == 0 ? @"┌" : (i == lineCount-1 ? @"└" : @"│");
            NSLog(@"[WonderPush] %@ %@", leftChar, lines[i]);
        }

        if (lineCount > 100) {
            NSLog(@"[WonderPush] └ … (%ld more lines truncated)", (long)(lineCount - 100));
        }
    }
}

void WPLogDebug(NSString *format, ...)
{
    if (!_loggingEnabled) return;
    va_list ap;
    va_start(ap, format);
    WPLogv(format, ap);
    va_end(ap);
}

void WPLog(NSString *format, ...)
{
    va_list ap;
    va_start(ap, format);
    WPLogv(format, ap);
    va_end(ap);
}

//
//  CASUtilities.m
//  CoreAstro
//
//  Copyright (c) 2012, Simon Taylor
// 
//  Permission is hereby granted, free of charge, to any person obtaining a copy 
//  of this software and associated documentation files (the "Software"), to deal 
//  in the Software without restriction, including without limitation the rights 
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell 
//  copies of the Software, and to permit persons to whom the Software is furnished 
//  to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in 
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR 
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, 
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL 
//  THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER 
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
//  FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
//  IN THE SOFTWARE.
//
//  CoreAstro framework header file

#import "CASUtilities.h"

NSString* CASCreateUUID()
{
    NSString* result = nil;
    CFUUIDRef uuid = CFUUIDCreate(NULL);
    result = (__bridge_transfer NSString *)CFUUIDCreateString(NULL, uuid);
    CFRelease(uuid);
    return result;
}

NSTimeInterval CASTimeBlock(void(^block)(void))
{
    NSTimeInterval result = 0;
    if (block){
        const NSTimeInterval start = [NSDate timeIntervalSinceReferenceDate];
        block();
        result = [NSDate timeIntervalSinceReferenceDate] - start;
    }
    return result;
}

void CASWithSuddenTerminationDisabled(void(^block)(void))
{
    if (block){
        [[NSProcessInfo processInfo] disableSuddenTermination];
        // disableAutomaticTermination ?
        @try {
            block();
        }
        @finally {
            [[NSProcessInfo processInfo] enableSuddenTermination];
            // enableAutomaticTermination ?
        }
    }
}

void CASThrowException(Class klass,NSString* message)
{
    @throw [NSException exceptionWithName:NSStringFromClass(klass) reason:message userInfo:nil];
}

void CASThrowOOMException(Class klass)
{
    @throw [NSException exceptionWithName:NSStringFromClass(klass) reason:NSLocalizedString(@"Out of memory", @"Exception reason message") userInfo:nil];
}

BOOL CASRunningInSandbox()
{
    return [[[NSProcessInfo processInfo] environment] objectForKey:@"APP_SANDBOX_CONTAINER_ID"] != nil;
}

BOOL CASSaveUrlToDefaults(NSURL* url,NSString* key)
{
    NSCParameterAssert(url);
    NSCParameterAssert(key);
    
    NSError* error;
    const NSURLBookmarkCreationOptions options = CASRunningInSandbox() ? NSURLBookmarkCreationWithSecurityScope : 0;
    NSData* bookmark = [url bookmarkDataWithOptions:options includingResourceValuesForKeys:nil relativeToURL:nil error:&error];
    if (error){
        NSLog(@"CASSaveUrlToDefaults: %@",error);
    }
    if (bookmark){
        [[NSUserDefaults standardUserDefaults] setObject:bookmark forKey:key];
    }
    return bookmark != nil;
}

NSURL* CASUrlFromDefaults(NSString* key)
{
    NSCParameterAssert(key);

    NSData* bookmark = [[NSUserDefaults standardUserDefaults] objectForKey:key];
    if ([bookmark length]){
        const NSURLBookmarkResolutionOptions options = CASRunningInSandbox() ? NSURLBookmarkResolutionWithSecurityScope : 0;
        NSURL* url = [NSURL URLByResolvingBookmarkData:bookmark options:options relativeToURL:nil bookmarkDataIsStale:nil error:nil];
        if (url){
            return url;
        }
    }
    return nil;
}

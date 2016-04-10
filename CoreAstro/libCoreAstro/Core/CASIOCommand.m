//
//  CASIOCommand.m
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

#import "CASIOCommand.h"
#import "CASIOTransport.h"

@interface CASIOCommand ()
@property (copy) void (^completion)(NSError*);
@end

@implementation CASIOCommand

- (NSData*)toDataRepresentation {
    return nil;
}

- (NSInteger) readSize {
    return 0;
}

- (BOOL) allowsUnderrun {
    return NO;
}

- (NSError*)fromDataRepresentation:(NSData*)data {
    return nil;
}

- (void)submit:(id<CASIOTransport>)transport block:(void (^)(NSError*))block {
    
    self.completion = block;
    
    //NSLog(@"submit: %@",self);
    NSError* error = [transport send:[self toDataRepresentation]];
    if (!error){
        const NSInteger readSize = [self readSize];
        if (readSize > 0){
            NSMutableData* responseData = [NSMutableData dataWithLength:readSize];
            // sleep/suspend in the case of expose ?
            //const NSTimeInterval start = [NSDate timeIntervalSinceReferenceDate];
            error = [transport receive:responseData];
            if (!error){
                //NSLog(@"Read %ld bytes in %f seconds",[responseData length],[NSDate timeIntervalSinceReferenceDate] - start);
                if ([responseData length] < readSize && !self.allowsUnderrun){
                    error = [NSError errorWithDomain:@"CASIOCommand" code:1 userInfo:[NSDictionary dictionaryWithObjectsAndKeys:[NSString stringWithFormat:@"CASIOCommand: requested %ld bytes, got %lu",readSize,[responseData length]],NSLocalizedDescriptionKey,nil]];
                }
                else {
                    [self fromDataRepresentation:responseData];
                }
            }
        }
    }
    
    if (self.completion){
        // the main operation queue doesn't run in the modal runloop mode so use -performSelectorOnMainThread: instead
        [self performSelectorOnMainThread:@selector(callCompletionBlock:) withObject:error waitUntilDone:NO modes:@[NSRunLoopCommonModes]];
    }
}

- (void)callCompletionBlock:(NSError*)error
{
    if (self.completion){
        self.completion(error);
        self.completion = nil;
    }
}

@end

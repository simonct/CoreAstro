//
//  CASIOTransport.m
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

#import "CASIOTransport.h"
#import "CASIOCommand.h"

@interface CASIOpendingCommand : NSObject
@property (nonatomic,strong) NSBlockOperation* commandOp;
@property (nonatomic,strong) NSDate* when;
@property (nonatomic,strong) NSTimer* timer;
@end

@implementation CASIOpendingCommand
@synthesize commandOp, when, timer;
@end

@interface CASIOTransport ()
@property (nonatomic,readonly) NSOperationQueue* ioq;
@property (nonatomic,strong) NSMutableOrderedSet* pending;
@end

@implementation CASIOTransport

@synthesize ioq = _ioq, pending = _pending;

- (id)init
{
    self = [super init];
    if (self) {
        self.pending = [NSMutableOrderedSet orderedSetWithCapacity:5];
    }
    return self;
}

- (void)dealloc {
    [self disconnect];
}

- (CASIOTransportType)type {
    return kCASTransportTypeNone;   
}

- (NSOperationQueue*)ioq {
    @synchronized(self){
        if (!_ioq){
            _ioq = [[NSOperationQueue alloc] init];
            _ioq.maxConcurrentOperationCount = 1; // create a serial queue
        }
    }
    return _ioq;
}

- (void)pendingTimerFired:(NSTimer*)timer {
    
    CASIOpendingCommand* pending = [[timer userInfo] objectForKey:@"pending"];
    if (pending){
        [self.ioq addOperation:pending.commandOp];
        [self.pending removeObject:pending];
    }
}

- (NSInteger)pendingThreshold {
    return 3;
}

- (void)submit:(CASIOCommand*)command block:(void (^)(NSError*))block {
 
    [self submit:command when:nil block:block];
}

- (void)submit:(CASIOCommand*)command when:(NSDate*)when block:(void (^)(NSError*))block {
    
    NSParameterAssert(block);
    NSParameterAssert(command);

    __weak NSBlockOperation* commandOp = nil;
    
    commandOp = [NSBlockOperation blockOperationWithBlock:^{
        
        if (![commandOp isCancelled]){
            
            // run the operation
            @try {
                [command submit:self block:block];
            }
            @catch (NSException *exception) {
                NSLog(@"*** Exception running command: %@",exception);
            }
        }
    }];
    
    if (when == [[NSDate date] laterDate:when]){
        
        // if when is in the future, enque in a pending list and start a timer
        CASIOpendingCommand* pending = [[CASIOpendingCommand alloc] init];
        pending.commandOp = commandOp;
        pending.when = when;
        pending.timer = [NSTimer scheduledTimerWithTimeInterval:[when timeIntervalSinceDate:[NSDate date]]
                                                          target:self
                                                        selector:@selector(pendingTimerFired:)
                                                        userInfo:[NSDictionary dictionaryWithObject:pending forKey:@"pending"]
                                                         repeats:NO];
        [self.pending addObject:pending];
    }
    else {
        
        // check it won't clash with a pending command
        NSDate* now = [NSDate date];
        for (CASIOpendingCommand* pending in self.pending){
            if ([pending.when timeIntervalSinceDate:now] < self.pendingThreshold){
                [commandOp addDependency:pending.commandOp];
                NSLog(@"Making command %@ dependent on %@",commandOp,pending.commandOp);
            }
        }
        
        // submit to the op queue
        [self.ioq addOperation:commandOp];
    }
}

- (NSError*)connect {
    return nil;
}

- (void)disconnect {
    if (_ioq){
        for (CASIOpendingCommand* pending in self.pending){
            [pending.timer invalidate];
        }
        [self.pending removeAllObjects];
        [_ioq cancelAllOperations];
        [_ioq waitUntilAllOperationsAreFinished];
        _ioq = nil;
    }
}

- (NSError*)send:(NSData*)data {
    return nil;    
}

- (NSError*)receive:(NSMutableData*)data {
    return nil;    
}

@end


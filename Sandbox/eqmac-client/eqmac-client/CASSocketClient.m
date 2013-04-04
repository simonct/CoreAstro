//
//  CASSocketClient.m
//  eqmac-client
//
//  Created by Simon Taylor on 4/4/13.
//  Copyright (c) 2013 Simon Taylor. All rights reserved.
//

#import "CASSocketClient.h"

@interface CASSocketClientRequest : NSObject
@property (nonatomic,strong) NSData* data;
@property (nonatomic,copy) void (^completion)(NSData*);
@property (nonatomic,assign) NSUInteger writtenCount;
@end

@implementation CASSocketClientRequest
@end

@interface CASSocketClient ()<NSStreamDelegate>
@property (nonatomic,assign) NSInteger openCount;
@property (nonatomic,strong) NSInputStream* inputStream;
@property (nonatomic,strong) NSOutputStream* outputStream;
@property (nonatomic,strong) NSError* error;
@end

@implementation CASSocketClient {
    NSMutableArray* _queue;
}

- (void)dealloc
{
    [self disconnect];
}

- (void)connect
{
    if (self.connected){
        return;
    }
    
    self.error = nil;
    
    NSHost* host = self.host;
    
    NSInputStream* is;
    NSOutputStream* os;
    [NSStream getStreamsToHost:host port:self.port inputStream:&is outputStream:&os];
    
    if (!is || !os){
        NSLog(@"Can't open connection to %@",host.name);
    }
    else {
        
        self.inputStream = is;
        self.outputStream = os;
        
        [self.inputStream setDelegate:self];
        [self.outputStream setDelegate:self];
        
        [self.inputStream scheduleInRunLoop:[NSRunLoop mainRunLoop] forMode:NSDefaultRunLoopMode];
        [self.outputStream scheduleInRunLoop:[NSRunLoop mainRunLoop] forMode:NSDefaultRunLoopMode];
        
        [self.inputStream open];
        [self.outputStream open];
    }
}

- (void)disconnect
{
    if (self.inputStream){
        [self.inputStream close];
        [self.inputStream removeFromRunLoop:[NSRunLoop mainRunLoop] forMode:NSDefaultRunLoopMode];
        self.inputStream = nil;
    }
    
    if (self.outputStream){
        [self.outputStream close];
        [self.outputStream removeFromRunLoop:[NSRunLoop mainRunLoop] forMode:NSDefaultRunLoopMode];
        self.outputStream = nil;
    }
    
    self.openCount = 0;
    
    // call completion blocks ?
}

- (BOOL)connected
{
    return (self.openCount == 2);
}

+ (NSSet*)keyPathsForValuesAffectingConnected
{
    return [NSSet setWithObject:@"openCount"];
}

- (void)stream:(NSStream *)aStream handleEvent:(NSStreamEvent)eventCode
{
    NSLog(@"stream: %@ handleEvent: %ld",aStream,eventCode);
    
    NSString* name;
    switch (eventCode) {
        case NSStreamEventNone:
            name = @"NSStreamEventNone";
            break;
        case NSStreamEventOpenCompleted:
            name = @"NSStreamEventOpenCompleted";
            self.openCount++;
            break;
        case NSStreamEventHasBytesAvailable:
            name = @"NSStreamEventHasBytesAvailable";
            [self read];
            break;
        case NSStreamEventHasSpaceAvailable:
            name = @"NSStreamEventHasSpaceAvailable";
            [self process];
            break;
        case NSStreamEventErrorOccurred:
            self.error = [aStream streamError];
            name = [NSString stringWithFormat:@"NSStreamEventErrorOccurred: %@",[aStream streamError]];
            [self disconnect];
            break;
        case NSStreamEventEndEncountered:
            name = @"NSStreamEventEndEncountered";
            [self disconnect];
            break;
        default:
            name = [NSString stringWithFormat:@"%ld",eventCode];
            break;
    }
    NSLog(@"%@: %@",aStream,name);
}

- (void)enqueue:(NSData*)data completion:(void (^)(NSData*))completion
{
    CASSocketClientRequest* request = [[CASSocketClientRequest alloc] init];
    
    request.data = data;
    request.completion = completion;
    
    if (!_queue){
        _queue = [[NSMutableArray alloc] initWithCapacity:5];
    }
    [_queue addObject:request];
    
    [self process];
}

- (void)process
{
    if ([_queue count]){
        
        if ([self.outputStream hasSpaceAvailable]){
            
            CASSocketClientRequest* request = [_queue lastObject];
            if (request.writtenCount < [request.data length]){
                
                const NSInteger count = [self.outputStream write:[request.data bytes] + request.writtenCount maxLength:[request.data length] - request.writtenCount];
                if (count < 0){
                    NSLog(@"Failed to write the whole packet"); // disconnect ?
                }
                else {
                    request.writtenCount += count;
                    NSLog(@"wrote %ld bytes",count);
                }
            }
        }
    }
}

- (void)read
{
    CASSocketClientRequest* request = [_queue lastObject];
    NSMutableData* data = [NSMutableData dataWithCapacity:1024];
    while ([self.inputStream hasBytesAvailable]){
        uint8_t byte[1024];
        const NSInteger count = [self.inputStream read:byte maxLength:sizeof(byte)];
        if (count > 0){
            [data appendBytes:byte length:count];
        }
    }
    
    NSLog(@"read %ld bytes",[data length]);
    
    if (request.completion){
        request.completion(data);
    }
    [_queue removeLastObject];
}

- (void)enqueueCommand:(uint8_t)cmd completion:(void (^)(NSData*))completion
{
    [self enqueue:[NSData dataWithBytes:&cmd length:sizeof(cmd)] completion:completion];
}

@end

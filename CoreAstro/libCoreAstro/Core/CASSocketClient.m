//
//  CASSocketClient.m
//  eqmac-client
//
//  Created by Simon Taylor on 4/4/13.
//  Copyright (c) 2013 Simon Taylor. All rights reserved.
//

#import "CASSocketClient.h"

@implementation CASSocketClientRequest

- (NSMutableData*) response
{
    if (!_response && self.readCount > 0){
        _response = [NSMutableData dataWithCapacity:self.readCount];
    }
    return _response;
}

- (BOOL)appendResponseData:(NSData*)data
{
    [self.response appendData:data];
    self.readCount -= MIN([data length], self.readCount);
    return (self.readCount == 0);
}

@end

@interface CASSocketClient ()<NSStreamDelegate>
@property (nonatomic,assign) BOOL connected;
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
    
    // close off any current requests - use a response of nil to indicate that the connection was dropped
    for (CASSocketClientRequest* request in _queue){
        if (request.completion){
            @try {
                request.completion(nil);
            }
            @catch (id ex) {
                NSLog(@"Exception calling request completion: %@",ex);
            }
        }
    }
    
    [_queue removeAllObjects];
}

- (BOOL)connected
{
    return (self.openCount == 2);
}

- (void)setOpenCount:(NSInteger)openCount
{
    _openCount = openCount;
    switch (_openCount) {
        case 0:
            self.connected = NO;
            break;
        case 2:
            self.connected = YES;
            break;
    }
}

- (CASSocketClientRequest*)makeRequest
{
    return [[CASSocketClientRequest alloc] init];
}

- (void)stream:(NSStream *)aStream handleEvent:(NSStreamEvent)eventCode
{
//    NSLog(@"stream: %@ handleEvent: %ld",aStream,eventCode);
    
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
//    NSLog(@"%@: %@",aStream,name);
}

- (void)enqueueRequest:(CASSocketClientRequest*)request
{
    NSParameterAssert(request);
    
    if (!_queue){
        _queue = [[NSMutableArray alloc] initWithCapacity:5];
    }
    [_queue insertObject:request atIndex:0];
    
    [self process];
}

- (void)enqueue:(NSData*)data readCount:(NSUInteger)readCount completion:(void (^)(NSData*))completion
{
    NSParameterAssert(data);

    CASSocketClientRequest* request = [self makeRequest];
    
    request.data = data;
    request.completion = completion;
    request.readCount = readCount;
    
    [self enqueueRequest:request];
}

- (void)process
{
    if ([_queue count] && [self.outputStream hasSpaceAvailable]){
        
        CASSocketClientRequest* request = [_queue lastObject];
        if (request.writtenCount < [request.data length]){
            
            const NSInteger count = [self.outputStream write:[request.data bytes] + request.writtenCount maxLength:[request.data length] - request.writtenCount];
            if (count < 0){
                NSLog(@"Failed to write the whole packet"); // disconnect ?
            }
            else {
                request.writtenCount += count;
//                NSLog(@"wrote %ld bytes",count);
            }
            
            // no response expected, all done
            if (!request.completion || !request.readCount){
                [_queue removeLastObject];
                [self process];
            }
        }
    }
}

- (void)read
{
    
    // need to check for a 0 read even if we don't have an outstanding request as it may be the remote peer disconnecting
    
    BOOL readComplete = NO;
    CASSocketClientRequest* request = nil;
    
    // read data while there's some available in the input buffer
    while ([self.inputStream hasBytesAvailable] && !readComplete){
        
        NSMutableData* buffer;
        if (!request.readCount){
            buffer = [NSMutableData dataWithLength:1]; // -hasBytesAvailable returned YES but we've no outstanding request, attempt to read 1 byte to check for disconnect
        }
        else {
            buffer = [NSMutableData dataWithLength:request.readCount];
        }

        const NSInteger count = [self.inputStream read:[buffer mutableBytes] maxLength:[buffer length]];
        if (count > 0){
            
            request = [_queue lastObject];
            if (request.readCount > 0){
                
                // resize the read buffer
                [buffer setLength:count];
                
                // pass the buffer to the request object; it will determine if we've read an entire message
                if ((readComplete = [request appendResponseData:buffer]) == YES){
                    break;
                }
            }
            else {
                
                NSLog(@"Read %ld bytes but there was no outstanding request to handle them",count);
                
                readComplete = YES;
            }
        }
        else {
            
            if (count == 0){
                // remote peer closed connection
                NSLog(@"peer disconnected");
            }
            else {
                // some other sort of error
                NSLog(@"read error ?");
            }
            readComplete = YES;
            break;
        }
        //            NSLog(@"read %ld bytes",[buffer length]);
        //            NSLog(@"read %@ -> %@",buffer,[[NSString alloc] initWithData:buffer encoding:NSASCIIStringEncoding]);
    }
    
    // check we've read everything we wanted, complete if we have
    if (readComplete){
        
        if (request.completion){
            @try {
                request.completion(request.response);
            }
            @catch (id ex) {
                NSLog(@"Exception calling request completion: %@",ex);
            }
        }
        [_queue removeLastObject];
        [self process];
    }
}

- (BOOL) hasBytesAvailable
{
    return self.inputStream.hasBytesAvailable;
}

- (NSInteger)read:(uint8_t *)buffer maxLength:(NSUInteger)len
{
    return [self.inputStream read:buffer maxLength:len];
}

@end

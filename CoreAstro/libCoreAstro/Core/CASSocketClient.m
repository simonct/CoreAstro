//
//  CASSocketClient.m
//  eqmac-client
//
//  Created by Simon Taylor on 4/4/13.
//  Copyright (c) 2013 Simon Taylor. All rights reserved.
//

#import "CASSocketClient.h"

#define CAS_DEBUG_XML 0

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
@property (nonatomic,readonly) BOOL hasBytesAvailable;
- (NSInteger)read:(uint8_t *)buffer maxLength:(NSUInteger)len;
@end

@implementation CASSocketClient {
    NSMutableArray* _queue;
}

- (void)dealloc
{
    [self disconnect];
}

- (BOOL)connect
{
    if (self.connected){
        return YES;
    }
    
    self.error = nil;
    
    NSHost* host = self.host;
    
    NSInputStream* is;
    NSOutputStream* os;
    if ([[NSStream class] respondsToSelector:@selector(getStreamsToHostWithName:port:inputStream:outputStream:)]){
        [NSStream getStreamsToHostWithName:host.name port:self.port inputStream:&is outputStream:&os];
    }
    else {
        #pragma clang diagnostic push
        #pragma clang diagnostic ignored "-Wdeprecated-declarations"
        [NSStream getStreamsToHost:host port:self.port inputStream:&is outputStream:&os];
        #pragma clang diagnostic pop
    }
    
    BOOL success = NO;
    
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
        
        success = YES;
    }
    
    return success;
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
            name = [NSString stringWithFormat:@"NSStreamEventErrorOccurred: %@",[aStream streamError]];
            [self disconnect];
            self.error = [aStream streamError]; // set this after disconnecting as when we return from this we could have been deallocated
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

@interface CASJSONRPCSocketClient ()
@property (nonatomic,strong) NSMutableData* buffer;
@property (nonatomic,strong) NSMutableData* readBuffer;
@property (nonatomic,strong) NSMutableDictionary* callbacks;
@end

@implementation CASJSONRPCSocketClient {
    NSInteger _id;
}

static const char CRLF[] = "\r\n";

- (void)enqueueCommand:(NSDictionary*)command completion:(void (^)(id))completion
{
    NSMutableDictionary* mcmd = [command mutableCopy];
    id msgID = @(++_id);
    [mcmd addEntriesFromDictionary:@{@"id":msgID}];
    
    // associate completion block with id
    if (!self.callbacks){
        self.callbacks = [NSMutableDictionary dictionaryWithCapacity:5];
    }
    if (completion){
        self.callbacks[msgID] = [completion copy];
    }
    
    NSError* error;
    NSData* data = [NSJSONSerialization dataWithJSONObject:mcmd options:0 error:&error];
    if (error){
        NSLog(@"enqueueCommand: %@",error);
    }
    else {
        
        NSMutableData* mdata = [data mutableCopy];
        [mdata appendBytes:CRLF length:2];
        [self enqueue:mdata readCount:0 completion:nil];
    }
}

- (void)read
{
    while ([self hasBytesAvailable]){
        
        // create the persistent read buffer
        if (!self.buffer){
            self.buffer = [NSMutableData dataWithCapacity:1024];
        }
        
        // create a transient read buffer
        if (!self.readBuffer){
            self.readBuffer = [NSMutableData dataWithLength:1024];
        }
        
        // read a buffer's worth of data from the stream
        const NSInteger count = [self read:[self.readBuffer mutableBytes] maxLength:[self.readBuffer length]];
        if (count > 0){
            
            // append the bytes we read to the end of the persistent buffer and reset the contents of the transient buffer
            [self.buffer appendBytes:[self.readBuffer mutableBytes] length:count];
            [self.readBuffer resetBytesInRange:NSMakeRange(0, [self.readBuffer length])];
            
            // search the persistent buffer for json separated by CRLF and keep going while we find any
            while (1) {
                
                // look for CRLF
                const NSRange range = [self.buffer rangeOfData:[NSData dataWithBytes:CRLF length:2] options:0 range:NSMakeRange(0, MIN(count, [self.buffer length]))];
                if (range.location == NSNotFound){
                    break;
                }
                
                // attempt to deserialise up to the CRLF
                NSRange jsonRange = NSMakeRange(0, range.location);
                id json = [NSJSONSerialization JSONObjectWithData:[self.buffer subdataWithRange:jsonRange] options:0 error:nil];
                
                // remove the json + CRLF from the front of the persistent buffer
                jsonRange.length += 2;
                [self.buffer replaceBytesInRange:jsonRange withBytes:nil length:0];
                
                if (!json){
                    break;
                }
                [self handleIncomingMessage:json];
            }
        }
    }
}

- (void)handleIncomingMessage:(NSDictionary*)message
{
    NSString* event = message[@"Event"];
    if ([event length]){
        [self.delegate client:self receivedNotification:message];
    }
    else {
        NSString* jsonrpc = message[@"jsonrpc"];
        if (![jsonrpc isEqualToString:@"2.0"]){
            NSLog(@"Unrecognised JSON-RPC version of %@",jsonrpc);
        }
        else{
            id msgID = message[@"id"];
            void(^callback)(id) = self.callbacks[msgID];
            if (!callback){
                NSLog(@"No callback for id %@",msgID);
            }
            else {
                @try {
                    callback(message[@"result"]);
                }
                @catch (NSException *exception) {
                    NSLog(@"*** %@",exception);
                }
                [self.callbacks removeObjectForKey:msgID];
            }
        }
    }
}

@end

@interface CASXMLSocketClient ()
@property (nonatomic,strong) NSMutableData* buffer;
@property (nonatomic,strong) NSMutableData* readBuffer;
@property (nonatomic,strong) NSMutableData* xmlBuffer;
@end

@implementation CASXMLSocketClient {
    BOOL _inBlob;
}

static const char LF[] = "\n";

- (void)read
{
    while ([self hasBytesAvailable]){
        
        // create the persistent read buffer
        if (!self.buffer){
            self.buffer = [NSMutableData dataWithCapacity:128*1024];
        }
        
        // create a transient read buffer
        if (!self.readBuffer){
            self.readBuffer = [NSMutableData dataWithLength:8*1024];
        }
        
        // read a buffer's worth of data from the stream
        const NSInteger count = [self read:[self.readBuffer mutableBytes] maxLength:[self.readBuffer length]];
        if (count > 0){
            
            // append the bytes we read to the end of the persistent buffer and reset the contents of the transient buffer
            [self.buffer appendBytes:[self.readBuffer mutableBytes] length:count];
            [self.readBuffer resetBytesInRange:NSMakeRange(0, count)];
            
            // search the persistent buffer linefeeds, passing them on to -processLine: as we find them and removing them from the buffer
            while (self.buffer.length > 0) {

                const NSRange range = [self.buffer rangeOfData:[NSData dataWithBytes:LF length:1] options:0 range:NSMakeRange(0, MIN(count, [self.buffer length]))];
                if (range.location == NSNotFound){
                    break;
                }
                
                // got a line, splice it out, process it and remove from the front of the persistent buffer
                const NSRange lineRange = NSMakeRange(0, range.location);
                [self processLine:[self.buffer subdataWithRange:lineRange]];
                [self.buffer replaceBytesInRange:NSMakeRange(lineRange.location, lineRange.length + 1) withBytes:nil length:0];
            }
        }
    }
}

- (void)processLine:(NSData*)line
{
#if CAS_DEBUG_XML
        NSLog(@"processLine: '%@'",[[NSString alloc] initWithData:line encoding:NSASCIIStringEncoding]);
#endif
    
    // look for blob start
    const NSRange startBlobRange = [line rangeOfData:[@"<setBLOBVector " dataUsingEncoding:NSASCIIStringEncoding] options:0 range:NSMakeRange(0, line.length)];
    if (startBlobRange.location != NSNotFound){
        _inBlob = YES;
    }
    else if (_inBlob) {
        
        // look for blob end
        const NSRange endBlobRange = [line rangeOfData:[@"</setBLOBVector>" dataUsingEncoding:NSASCIIStringEncoding] options:0 range:NSMakeRange(0, line.length)];
        if (endBlobRange.location != NSNotFound){
            _inBlob = NO;
        }
    }
    
    // accumulate lines until we can parse an xml document
    if (!self.xmlBuffer){
        self.xmlBuffer = [NSMutableData dataWithCapacity:8*1024];
    }
    [self.xmlBuffer appendData:line];

    // check for an xml document unless we're processing a blob - if we get one pass it onto the delegate and reset the xml buffer
    if (!_inBlob){

        NSError* error;
        NSXMLDocument* xml = [[NSXMLDocument alloc] initWithData:self.xmlBuffer options:0 error:&error];
        if (xml){
#if CAS_DEBUG_XML
            NSLog(@"xml: %@",xml);
#endif
            [self.delegate client:self receivedDocument:xml];
            self.xmlBuffer = nil;
        }
    }
}

- (void)enqueue:(NSData *)data
{
    CASSocketClientRequest* request = [CASSocketClientRequest new];
    request.data = data;
    [self enqueueRequest:request];
}

@end

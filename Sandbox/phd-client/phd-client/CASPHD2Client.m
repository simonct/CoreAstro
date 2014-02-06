//
//  CASPHD2Client.m
//  phd-client
//
//  Created by Simon Taylor on 06/02/2014.
//  Copyright (c) 2014 Simon Taylor. All rights reserved.
//

#import "CASPHD2Client.h"

@class CASPHD2SocketClient;

@interface CASPHD2Client ()
@property (nonatomic,strong) CASPHD2SocketClient* client;
@property (nonatomic,assign) CASPHD2ClientState state;
@property (nonatomic,strong) NSMutableDictionary* callbacks;
- (void)handleIncomingMessage:(NSDictionary*)message;
@end

@interface CASPHD2SocketClient : CASSocketClient
@property (nonatomic,weak) CASPHD2Client* owner;
@property (nonatomic,strong) NSMutableData* buffer;
@property (nonatomic,strong) NSMutableData* readBuffer;
@end

@implementation CASPHD2SocketClient

static const char CRLF[] = "\r\n";

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
            
//            NSLog(@"Read: %@",[[NSString alloc] initWithBytes:[self.readBuffer mutableBytes] length:count encoding:NSUTF8StringEncoding]);
            
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
                [self.owner handleIncomingMessage:json];
            }
        }
    }
}

@end

@implementation CASPHD2Client {
    NSInteger _id; // persist this ?
}

- (id)init
{
    self = [super init];
    if (self) {
        self.client = [[CASPHD2SocketClient alloc] init];\
        self.client.owner = self;
        self.client.host = [NSHost hostWithAddress:@"127.0.0.1"];
        self.client.port = 4400;
        [self.client connect];
    }
    return self;
}

- (void)handleIncomingMessage:(NSDictionary*)message
{
    NSString* event = message[@"Event"];
    if ([event length]){
        [self handleIncomingEvent:message];
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

- (void)handleIncomingEvent:(NSDictionary*)message
{
    // Version
    // StarSelected
    // LockPositionSet
    // CalibrationComplete
    // StartGuiding
    // AppState
    // Settling
    // SettleDone, result 1/0
    // GuideStep
    // Paused
    // Resumed
    // GuidingDithered
    NSLog(@"%@",message[@"Event"]);
    if ([@"SettleDone" isEqualToString:message[@"Event"]]){
        NSLog(@"%@",message);
    }
}

- (void)enqueueCommand:(NSDictionary*)cmd completion:(void(^)(id))completion
{
    NSMutableDictionary* mcmd = [cmd mutableCopy];
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
        NSLog(@"error: %@",error);
    }
    else {
        
        NSMutableData* mdata = [data mutableCopy];
        [mdata appendBytes:CRLF length:2];
        
        //NSLog(@"Sending: %@",[[NSString alloc] initWithData:mdata encoding:NSUTF8StringEncoding]);
        
        [self.client enqueue:mdata readCount:0 completion:nil];
    }
}

- (void)start
{
    [self enqueueCommand:@{@"method":@"guide",@"params":@[@{@"pixels":@(1.5),@"time":@(10),@"timeout":@(60)},@(NO)]} completion:^(id result) {
        NSLog(@"start: %@",result);
    }];
}

- (void)stop
{
    [self enqueueCommand:@{@"method":@"stop_capture"} completion:^(id result) {
        NSLog(@"stop: %@",result);
    }];
}

- (void)pause
{
    [self enqueueCommand:@{@"method":@"set_paused",@"params":@[@YES]} completion:^(id result) {
        NSLog(@"pause: %@",result);
    }];
}

- (void)resume
{
    [self enqueueCommand:@{@"method":@"set_paused",@"params":@[@NO]} completion:^(id result) {
        NSLog(@"resume: %@",result);
    }];
}

- (void)ditherByPixels:(NSInteger)pixels inRAOnly:(BOOL)raOnly
{
    [self enqueueCommand:@{@"method":@"dither",@"params":@[@(pixels),@(raOnly),@{@"pixels":@(1.5),@"time":@(10),@"timeout":@(60)}]} completion:^(id result) {
        NSLog(@"ditherByPixels: %@",result);
    }];
}

@end

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
@property (nonatomic,strong) NSMutableDictionary* callbacks;
@property (nonatomic,assign) BOOL guiding;
- (void)handleIncomingMessage:(NSDictionary*)message;
@end

@interface CASPHD2SocketClient : CASSocketClient
@property (nonatomic,weak) CASPHD2Client* owner;
@property (nonatomic,strong) NSMutableData* buffer;
@property (nonatomic,strong) NSMutableData* readBuffer;
@end

static const char CRLF[] = "\r\n";

@implementation CASPHD2SocketClient

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
                [self.owner handleIncomingMessage:json];
            }
        }
    }
}

@end

@implementation CASPHD2Client {
    NSInteger _id;
    BOOL _settling;
}

static void* kvoContext;

- (id)init
{
    self = [super init];
    if (self) {
        [self setupClient];
    }
    return self;
}

- (void)dealloc
{
    [_client removeObserver:self forKeyPath:@"error" context:&kvoContext];
}

- (void)setupClient
{
    if (!self.client){
        self.client = [[CASPHD2SocketClient alloc] init];
        self.client.owner = self;
        self.client.host = [NSHost hostWithAddress:@"127.0.0.1"];
        self.client.port = 4400;
        [self.client connect];
    }
}

- (void)setClient:(CASPHD2SocketClient *)client
{
    if (client != _client){
        [_client removeObserver:self forKeyPath:@"error" context:&kvoContext];
        _client = client;
        if (!_client){
            self.guiding = NO;
        }
        [_client addObserver:self forKeyPath:@"error" options:0 context:&kvoContext];
    }
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if (context == &kvoContext) {
        if (self.client.error){
            NSLog(@"error: %@",self.client.error);
            self.client = nil;
        }
    } else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
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
    
    NSString* event = message[@"Event"];
    
    if ([@"AppState" isEqualToString:event]){
        if ([message[@"State"] isEqualToString:@"Guiding"]){
            _settling = NO;
            self.guiding = YES;
        }
    }
    
    if ([@"SettleDone" isEqualToString:event]){
        _settling = NO;
        if ([message[@"Status"] integerValue] == 0){
            self.guiding = YES;
        }
        else {
            NSLog(@"Settling failed %@",message);
        }
    }
    
    if ([@[@"Settling",@"StartGuiding"] containsObject:event]){
        self.guiding = NO;
        _settling = YES;
    }

    if ([@[@"StartGuiding",@"GuideStep"] containsObject:event]){
        self.guiding = !_settling;
    }
    
    if ([@[@"GuidingStopped"] containsObject:event]){
        self.guiding = NO;
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
        NSLog(@"enqueueCommand: %@",error);
    }
    else {
        
        NSMutableData* mdata = [data mutableCopy];
        [mdata appendBytes:CRLF length:2];
        [self.client enqueue:mdata readCount:0 completion:nil];
    }
}

- (NSDictionary*)settleParam
{
    return @{@"pixels":@(1.5),@"time":@(10),@"timeout":@(60)};
}

- (void)start
{
    [self setupClient];
    [self enqueueCommand:@{@"method":@"guide",@"params":@[[self settleParam],@(NO)]} completion:^(id result) {
        if ([result integerValue] == 0){
            NSLog(@"Started");
        }
        else{
            NSLog(@"Start failed: %@",result);
        }
    }];
}

- (void)stop
{
    [self enqueueCommand:@{@"method":@"stop_capture"} completion:^(id result) {
        if ([result integerValue] == 0){
            NSLog(@"Stopped");
            self.guiding = NO;
        }
        else {
            NSLog(@"Stop failed: %@",result);
        }
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
    self.guiding = NO;
    [self enqueueCommand:@{@"method":@"dither",@"params":@[@(pixels),@(raOnly),[self settleParam]]} completion:^(id result) {
        if ([result integerValue] == 0){
            NSLog(@"Dithering...");
        }
        else {
            NSLog(@"Dither failed: %@",result);
        }
    }];
}

@end

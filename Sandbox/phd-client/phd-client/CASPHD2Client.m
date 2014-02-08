//
//  CASPHD2Client.m
//  phd-client
//
//  Created by Simon Taylor on 06/02/2014.
//  Copyright (c) 2014 Simon Taylor. All rights reserved.
//

#import "CASPHD2Client.h"

@interface CASPHD2Client ()<CASJSONRPCSocketClientDelegate>
@property (nonatomic,strong) CASJSONRPCSocketClient* client;
@property (nonatomic,assign) BOOL guiding;
@property (nonatomic,assign) BOOL connected;
@end

@implementation CASPHD2Client {
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
    [_client removeObserver:self forKeyPath:@"connected" context:&kvoContext];
}

- (void)setupClient
{
    if (!self.client){
        self.client = [[CASJSONRPCSocketClient alloc] init];
        self.client.delegate = self;
        self.client.host = [NSHost hostWithAddress:@"127.0.0.1"];
        self.client.port = 4400;
        [self.client connect];
    }
}

- (void)setClient:(CASJSONRPCSocketClient *)client
{
    if (client != _client){
        [_client removeObserver:self forKeyPath:@"error" context:&kvoContext];
        [_client removeObserver:self forKeyPath:@"connected" context:&kvoContext];
        _client = client;
        if (!_client){
            // always set these to NO ?
            self.guiding = NO;
            self.connected = NO;
        }
        [_client addObserver:self forKeyPath:@"error" options:0 context:&kvoContext];
        [_client addObserver:self forKeyPath:@"connected" options:0 context:&kvoContext];
    }
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if (context == &kvoContext) {
        if (self.client.error){
            NSLog(@"error: %@",self.client.error);
            self.client = nil;
        }
//        else if (!self.client.connected){
//            NSLog(@"disconnected");
//            self.client = nil;
//        }
    } else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
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

- (NSDictionary*)settleParam
{
    return @{@"pixels":@(1.5),@"time":@(10),@"timeout":@(60)};
}

- (void)start
{
    [self setupClient];
    [self.client enqueueCommand:@{@"method":@"guide",@"params":@[[self settleParam],@(NO)]} completion:^(id result) {
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
    [self.client enqueueCommand:@{@"method":@"stop_capture"} completion:^(id result) {
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
    [self.client enqueueCommand:@{@"method":@"set_paused",@"params":@[@YES]} completion:^(id result) {
        NSLog(@"pause: %@",result);
    }];
}

- (void)resume
{
    [self.client enqueueCommand:@{@"method":@"set_paused",@"params":@[@NO]} completion:^(id result) {
        NSLog(@"resume: %@",result);
    }];
}

- (void)ditherByPixels:(NSInteger)pixels inRAOnly:(BOOL)raOnly
{
    self.guiding = NO;
    [self.client enqueueCommand:@{@"method":@"dither",@"params":@[@(pixels),@(raOnly),[self settleParam]]} completion:^(id result) {
        if ([result integerValue] == 0){
            NSLog(@"Dithering...");
        }
        else {
            NSLog(@"Dither failed: %@",result);
        }
    }];
}

@end

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
@property (nonatomic,copy) void(^connectCompletion)();
@property (nonatomic,copy) void(^settleCompletion)(BOOL);
@end

@implementation CASPHD2Client {
    BOOL _settling;
}

static void* kvoContext;

- (void)dealloc
{
    [_client removeObserver:self forKeyPath:@"error" context:&kvoContext];
    [_client removeObserver:self forKeyPath:@"connected" context:&kvoContext];
}

- (void)connectWithCompletion:(void(^)())completion
{
    if (self.connected){
        if (completion){
            completion();
        }
    }
    else {
        self.connectCompletion = completion;
        [self setupClient];
    }
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

- (void)client:(CASJSONRPCSocketClient*)client receivedNotification:(NSDictionary*)message
{
    if (client != self.client){
        return;
    }
    
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
    // NSLog(@"%@",message[@"Event"]);
    
    NSString* event = message[@"Event"];
    
    if ([@"AppState" isEqualToString:event]){
        if ([message[@"State"] isEqualToString:@"Guiding"]){
            _settling = NO;
            self.guiding = YES;
        }
        if (self.connectCompletion){
            self.connectCompletion();
            self.connectCompletion = nil;
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
        if (self.settleCompletion){
            self.settleCompletion(self.guiding);
            self.settleCompletion = nil;
        }
    }
    
    if ([@[@"Settling",@"StartGuiding"] containsObject:event]){
        self.guiding = NO;
        _settling = YES;
    }

    if ([@[@"StartGuiding",@"GuideStep"] containsObject:event]){ // is inclusion of GuideStep correct - shouldn't that indicate self.guiding = YES; ?
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

- (void)guideWithCompletion:(void(^)(BOOL))completion
{
    [self setupClient];
    self.settleCompletion = completion;
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
    [self setupClient];
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

- (void)ditherByPixels:(float)pixels inRAOnly:(BOOL)raOnly completion:(void(^)(BOOL))completion
{
    if (!self.guiding){
        // todo; this can happen if this is called before we've got the AppState event after connecting, queue the request up ?
        NSLog(@"Attempting to dither while not guiding");
        if (completion){
            completion(NO);
        }
        return;
    }
    [self setupClient];
    if (!self.client){
        NSLog(@"Attempting to dither while not connected");
        if (completion){
            completion(NO);
        }
        return;
    }
    self.guiding = NO;
    self.settleCompletion = completion;
    [self.client enqueueCommand:@{@"method":@"dither",@"params":@[@(pixels),@(raOnly),[self settleParam]]} completion:^(id result) {
        if ([result integerValue] == 0){
            NSLog(@"Dithering %.1f pixels...",pixels);
        }
        else {
            NSLog(@"Dither failed: %@",result);
        }
    }];
}

- (void)cancel
{
    if (self.settleCompletion){
        self.settleCompletion(NO);
        self.settleCompletion = nil;
    }
}

@end

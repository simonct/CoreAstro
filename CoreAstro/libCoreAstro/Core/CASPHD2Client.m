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

- (void)callConnectCompletion
{
    if (self.connectCompletion){
        self.connectCompletion();
        self.connectCompletion = nil;
    }
}

- (void)setupClient
{
    if (!self.client){
        self.client = [[CASJSONRPCSocketClient alloc] init];
        self.client.delegate = self;
        self.client.host = [NSHost hostWithAddress:@"127.0.0.1"];
        self.client.port = 4400;
        if (![self.client connect]){
            [self callConnectCompletion];
        }
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
            [self callConnectCompletion];
        }
        if ([@"connected" isEqualToString:keyPath]){
            self.connected = _client.connected;
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
    NSLog(@"%@",message[@"Event"]);
    
    NSString* event = message[@"Event"];
    
    if ([@"AppState" isEqualToString:event]){
        if ([message[@"State"] isEqualToString:@"Guiding"]){
            _settling = NO;
            self.guiding = YES;
        }
        [self callConnectCompletion];
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
    
    if ([@[@"Settling"] containsObject:event]){
        self.guiding = NO;
        _settling = YES;
    }

    if ([@[@"GuideStep"] containsObject:event]){
        self.guiding = !_settling;
    }
    
    if ([@"StartGuiding" isEqualToString:event]){
        _settling = NO;
        self.guiding = YES;
    }
    
    if ([@[@"GuidingStopped"] containsObject:event]){
        _settling = NO;
        self.guiding = NO;
    }
}

- (NSDictionary*)settleParam
{
    return @{@"pixels":@(2),@"time":@(10),@"timeout":@(300)};
}

- (void)guideWithCompletion:(void(^)(BOOL))completion
{
    [self setupClient];
    
    self.settleCompletion = completion;
    
    // connect everything up, assume profile is set on the app
    [self.client enqueueCommand:@{@"method":@"set_connected",@"params":@[@YES]} completion:^(id result,NSError* error) {
        if (error){
            NSLog(@"Connect failed: %@",error);
            completion(NO);
        }
        else{
            NSLog(@"Connected");
            [self.client enqueueCommand:@{@"method":@"guide",@"params":@[[self settleParam],@(NO)]} completion:^(id result,NSError* error) {
                if (error){
                    NSLog(@"Start failed: %@",error);
                    completion(NO);
                }
                else{
                    NSLog(@"Started"); // self.settleCompletion will be called when SettleDone is received
                }
            }];
        }
    }];
}

- (void)flipWithCompletion:(void(^)(BOOL))completion
{
    [self.client enqueueCommand:@{@"method":@"flip_calibration"} completion:^(id _,NSError* error) {
        if (error){
            NSLog(@"Flip failed %@",error);
            completion(NO);
        }
        else {
            [self guideWithCompletion:completion];
        }
    }];
}

- (void)stop
{
    [self setupClient];
    [self.client enqueueCommand:@{@"method":@"stop_capture"} completion:^(id result,NSError* error) {
        if (error){
            NSLog(@"Stop failed: %@",error);
        }
        else {
            NSLog(@"Stopped");
            self.guiding = NO;
        }
    }];
}

- (void)ditherByPixels:(float)pixels inRAOnly:(BOOL)raOnly completion:(void(^)(BOOL))completion
{
    if (!self.guiding){
        // todo; this can happen if this is called before we've got the AppState event after connecting, queue the request up ?
        NSLog(@"Attempting to dither while not guiding"); // always getting this after stopping and starting guiding
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
    [self.client enqueueCommand:@{@"method":@"dither",@"params":@[@(pixels),@(raOnly),[self settleParam]]} completion:^(id result,NSError* error) {
        if (error){
            NSLog(@"Dither failed: %@",result);
            if (completion){
                completion(NO);
            }
        }
        else {
            NSLog(@"Dithering %.1f pixels...",pixels);
            // start a timer that resumes exposures if we never hear back from PHD2
            [self performSelector:@selector(ditherTimeout) withObject:nil afterDelay:120];
        }
    }];
}

- (void)ditherTimeout
{
    NSLog(@"ditherTimeout");
    // stop/start phd client ?
}

- (void)cancel
{
    if (self.settleCompletion){
        self.settleCompletion(NO);
        self.settleCompletion = nil;
    }
}

@end

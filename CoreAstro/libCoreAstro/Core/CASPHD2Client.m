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
@property (nonatomic,copy) NSString* lastEvent;
@property (nonatomic,copy) void(^connectCompletion)();
@property (nonatomic,copy) void(^settleCompletion)(BOOL);
@end

@implementation CASPHD2Client {
    BOOL _settling;
    NSTimeInterval _starLostTime;
}

static void* kvoContext;

- (void)dealloc
{
    [_client removeObserver:self forKeyPath:@"error" context:&kvoContext];
    [_client removeObserver:self forKeyPath:@"connected" context:&kvoContext];
    [self disconnect];
}

- (void)disconnect
{
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(ditherTimeout) object:nil];
    [self.client disconnect];
    self.client = nil;
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

- (void)callSettleCompletionWithGuiding:(BOOL)guiding
{
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(ditherTimeout) object:nil];

    // todo; just call the delegate with guiding failed ?
    
    if (self.settleCompletion){
        void(^settleCompletion)(BOOL) = [self.settleCompletion copy]; // grab the original dither completion block
        self.settleCompletion = nil;
        settleCompletion(guiding);
    }
}

- (void)setupClient
{
    if (!self.client){
        self.client = [[CASJSONRPCSocketClient alloc] init];
        self.client.delegate = self;
        self.client.host = [NSHost hostWithAddress:@"127.0.0.1"];
        self.client.port = 4400;
        NSLog(@"PHD2: Opening socket to PHD2 on port %ld",(long)self.client.port);
        if (![self.client connect]){
            NSLog(@"PHD2: failed to connect");
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
            NSLog(@"PHD2: client error: %@",self.client.error);
            self.client = nil;
            [self callConnectCompletion];
        }
        if ([@"connected" isEqualToString:keyPath]){
            self.connected = _client.connected;
            NSLog(@"PHD2: client connected: %d",self.connected);
            // if (self.connected) [self callConnectCompletion]; // ??
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
    // NSLog(@"PHD2 client event: %@",message[@"Event"]);
    
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
            NSLog(@"PHD2: Settling failed %@",message);
        }
        [self callSettleCompletionWithGuiding:self.guiding];
    }
    
    if ([@[@"Settling"] containsObject:event]){
        self.guiding = NO;
        _settling = YES;
    }

    if ([@[@"GuideStep"] containsObject:event]){
        _starLostTime = 0;
        self.guiding = !_settling;
        // ErrorCode ?
    }
    
    if ([@"StartGuiding" isEqualToString:event]){
        _starLostTime = 0;
        _settling = NO;
        self.guiding = YES;
        [self.delegate guidingStarted];
    }
    
    if ([@[@"GuidingStopped"] containsObject:event]){
        _settling = NO;
        self.guiding = NO;
    }
    
    if ([@[@"StarLost"] containsObject:event]){
        NSLog(@"PHD2: star lost");
        const NSTimeInterval now = [NSDate timeIntervalSinceReferenceDate];
        if (!_starLostTime){
            _starLostTime = now;
        }
        if (now - _starLostTime > 30){
            [self.delegate guidingFailedWithError:[NSError errorWithDomain:@"PHD"
                                                                      code:1
                                                                  userInfo:@{NSLocalizedDescriptionKey:@"Star was lost for more that 30s"}]];
        }
    }

    self.lastEvent = event;

    // CalibrationFailed
    // StarLost, accumulate a count and then fail if it exceeds some threshold
    // Alert.error ?
    
    // ideally, if star lost notify the client and then restart when its re-aquired
}

- (NSInteger)defaultDitherTimeout
{
    return 300;
}

- (NSDictionary*)settleParam
{
    return @{@"pixels":@(2),@"time":@(10),@"timeout":@([self defaultDitherTimeout])};
}

- (void)guideWithCompletion:(void(^)(BOOL))completion
{
    NSLog(@"PHD2: guideWithCompletion"); // todo; check/handle this being called re-entrantly
    
    [self setupClient];
    
    self.settleCompletion = completion;
    
    // connect everything up, assume profile is set on the app
    [self.client enqueueCommand:@{@"method":@"set_connected",@"params":@[@YES]} completion:^(id result,NSError* error) {
        
        if (error){
            NSLog(@"PHD2: Connect failed: %@",error);
            completion(NO);
        }
        else{

            // after a slew the chances are that the original guide star is nowhere near its original position so make sure it
            // is cleared to prevent PHD2 from attempting to reaquire it. This will force an auto-select when the guide command is sent
            [self.client enqueueCommand:@{@"method":@"deselect_star"} completion:^(id _,NSError* error) {
                
                if (error){
                    NSLog(@"PHD2: Deselect star failed: %@",error);
                    completion(NO);
                }
                else {
                    
                    [self.client enqueueCommand:@{@"method":@"guide",@"params":@[[self settleParam],@(NO)]} completion:^(id result,NSError* error) {
                        
                        // sometimes get an 'already guiding' error here so need to check -guideWithCompletion: isn't being called re-entrantly
                        
                        if (error){
                            NSLog(@"PHD2: Start guiding failed: %@",error);
                            completion(NO);
                        }
                        else{
                            NSLog(@"PHD2: Started guiding"); // self.settleCompletion will be called when SettleDone is received
                        }
                    }];
                }
            }];
        }
    }];
}

- (void)flipWithCompletion:(void(^)(BOOL))completion
{
    [self.client enqueueCommand:@{@"method":@"flip_calibration"} completion:^(id _,NSError* error) {
        if (error){
            NSLog(@"PHD2: Flip calibration failed %@",error);
            completion(NO);
        }
        else {
            completion(YES);
        }
    }];
}

- (void)clearWithCompletion:(void(^)(BOOL))completion
{
    [self.client enqueueCommand:@{@"method":@"clear_calibration"} completion:^(id _,NSError* error) {
        if (error){
            NSLog(@"PHD2: Clear calibration failed %@",error);
            completion(NO);
        }
        else {
            completion(YES);
        }
    }];
}

- (void)stop
{
    [self setupClient];
    [self.client enqueueCommand:@{@"method":@"stop_capture"} completion:^(id result,NSError* error) {
        if (error){
            NSLog(@"PHD2: Stop guiding failed: %@",error);
        }
        else {
            NSLog(@"PHD2: Stopped guiding");
            self.guiding = NO;
        }
    }];
}

- (void)handleFailedDither
{
    // restart guiding and call the original settle completion block
    void(^settleCompletion)(BOOL) = [self.settleCompletion copy]; // grab the original dither completion block

    [self disconnect];
    [self connectWithCompletion:^{
        
        if (!self.connected){
            if (settleCompletion){
                settleCompletion(NO);
            }
            self.settleCompletion = nil;
        }
        else {
            [self guideWithCompletion:^(BOOL guiding) {
                if (settleCompletion){
                    settleCompletion(guiding);
                }
                self.settleCompletion = nil;
            }];
        }
    }];
}

- (void)ditherByPixels:(float)pixels inRAOnly:(BOOL)raOnly completion:(void(^)(BOOL))completion
{
    NSLog(@"PHD2: ditherByPixels %f, raOnly: %d",pixels,raOnly); // todo; check/handle this being called re-entrantly

    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(ditherTimeout) object:nil];

    if (!self.guiding){
        // todo; this can happen if this is called before we've got the AppState event after connecting, queue the request up ?
        NSLog(@"PHD2: Attempting to dither while not guiding"); // always getting this after stopping and starting guiding
        if (completion){
            completion(NO);
        }
        return;
    }
    [self setupClient];
    if (!self.client){
        NSLog(@"PHD2: Attempting to dither while not connected");
        if (completion){
            completion(NO);
        }
        return;
    }
    self.guiding = NO;
    self.settleCompletion = completion;
    [self.client enqueueCommand:@{@"method":@"dither",@"params":@[@(pixels),@(raOnly),[self settleParam]]} completion:^(id result,NSError* error) {
        if (error){
            NSLog(@"PHD2: Dither failed with error %@, attempting to restart guiding",result);
            [self handleFailedDither];
        }
        else {
            NSLog(@"PHD2: Dithering %.1f pixels...",pixels);
            // start a timer that resumes exposures if we never hear back from PHD2
            [self performSelector:@selector(ditherTimeout) withObject:nil afterDelay:[self defaultDitherTimeout] + 10];
        }
    }];
}

- (void)ditherTimeout
{
    NSLog(@"PHD2: Dither timeout fired, attempting to restart guiding");
    [self handleFailedDither];
}

- (void)cancel
{
    [self callSettleCompletionWithGuiding:NO];
}

@end

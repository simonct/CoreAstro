//
//  CASCameraServer.m
//  SX IO
//
//  Created by Simon Taylor on 26/10/2014.
//  Copyright (c) 2014 Simon Taylor. All rights reserved.
//
//  Start with MPC, could add aditional protocols such as JSON-RPC, WebSockets

#import "CASCameraServer.h"
#import "NSApplication+CASScripting.h"
#import <CoreAstro/CoreAstro.h>
#import <MultipeerConnectivity/MultipeerConnectivity.h>

@interface CASCameraServer ()<MCSessionDelegate>
@property (nonatomic,strong) MCPeerID* peerID;
@property (nonatomic,strong) MCSession* session;
@property (nonatomic,strong) MCAdvertiserAssistant* assistant;
@property (nonatomic,strong) NSMutableDictionary* exposures;
@end

@implementation CASCameraServer

static void* kvoContext;

+ (instancetype)sharedServer {
    static CASCameraServer* server;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        server = [CASCameraServer new];
    });
    return server;
}

- (void)dealloc
{
    [self stop];
}

- (NSArray*)statusKeyPaths
{
    return @[@"progress",@"state",@"lastExposure"];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if (context == &kvoContext) {
        
        if (object == [CASDeviceManager sharedManager]){
            
            switch ([[change objectForKey:NSKeyValueChangeKindKey] integerValue]) {
                    
                case NSKeyValueChangeSetting:
                case NSKeyValueChangeInsertion:{
                    [[change objectForKey:NSKeyValueChangeNewKey] enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                        if ([obj isKindOfClass:[CASCameraController class]]){
                            CASCameraController* camera = obj;
                            for (NSString* keyPath in [self statusKeyPaths]){
                                [obj addObserver:self forKeyPath:keyPath options:0 context:&kvoContext];
                                NSDictionary* cameraConnected = @{@"cmd":@"camera-connected",@"id":camera.uniqueID,@"status":[self cameraStatus:camera]};
                                [self respondToCommand:nil withReply:cameraConnected toPeers:self.session.connectedPeers completion:nil];
                            }
                        }
                    }];
                }
                    break;
                    
                case NSKeyValueChangeRemoval:{
                    [[change objectForKey:NSKeyValueChangeOldKey] enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                        if ([obj isKindOfClass:[CASCameraController class]]){
                            CASCameraController* camera = obj;
                            for (NSString* keyPath in [self statusKeyPaths]){
                                [obj removeObserver:self forKeyPath:keyPath context:&kvoContext];
                                NSDictionary* cameraDisconnected = @{@"cmd":@"camera-disconnected",@"id":camera.uniqueID};
                                [self respondToCommand:nil withReply:cameraDisconnected toPeers:self.session.connectedPeers completion:nil];
                            }
                        }
                    }];
                }
                    break;
                default:
                    break;
            }
        }
        else if ([object isKindOfClass:[CASCameraController class]]){
            CASCameraController* camera = object;
            NSDictionary* statusChanged = @{@"cmd":@"status-changed",@"id":camera.uniqueID,@"status":[self cameraStatus:camera]};
            [self respondToCommand:nil withReply:statusChanged toPeers:self.session.connectedPeers completion:nil];
        }
        
    } else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

- (BOOL)multiPeerAvailable
{
    return ([MCPeerID class] != nil);
}

- (void)start
{
    if (![self multiPeerAvailable] || self.peerID){
        return;
    }
    
    [[CASDeviceManager sharedManager] addObserver:self forKeyPath:@"cameraControllers" options:NSKeyValueObservingOptionNew|NSKeyValueObservingOptionOld|NSKeyValueObservingOptionInitial context:&kvoContext];

    self.peerID = [[MCPeerID alloc] initWithDisplayName:[NSProcessInfo processInfo].hostName]; // no, want sharing name
    self.session = [[MCSession alloc] initWithPeer:self.peerID];
    self.session.delegate = self;
    
    self.assistant = [[MCAdvertiserAssistant alloc] initWithServiceType:@"sxio-server" discoveryInfo:nil session:self.session];
    [self.assistant start];
}

- (void)stop
{
    if (![self multiPeerAvailable] || !self.peerID){
        return;
    }
    
    [self.assistant stop];
    self.assistant = nil;
    [self.session disconnect];
    self.session = nil;
    self.peerID = nil;
}

- (void)session:(MCSession *)session peer:(MCPeerID *)peerID didChangeState:(MCSessionState)state
{
    NSLog(@"didChangeState: %ld",state);
}

- (void)respondToCommand:(NSDictionary*)command withReply:(NSDictionary*)reply toPeers:(NSArray*)peers completion:(void(^)(NSError*,NSDictionary*))completion
{
    if (!reply){
        reply = @{};
    }
    NSError* error;
    NSMutableDictionary* mutableReply = [reply mutableCopy];
    NSString* uuid = command[@"uuid"];
    if (uuid){
        mutableReply[@"uuid"] = uuid;
    }
    NSLog(@"respondToCommand: %@",mutableReply);
    NSData* data = [NSJSONSerialization dataWithJSONObject:mutableReply options:0 error:&error];
    if (!data){
        NSLog(@"dataWithJSONObject: %@",error);
    }
    const BOOL success = [self.session sendData:data toPeers:peers withMode:MCSessionSendDataReliable error:&error];
    if (!success){
        NSLog(@"sendData: %@",error);
    }
}

- (void)respondToCommand:(NSDictionary*)command withReply:(NSDictionary*)reply toPeer:(MCPeerID*)peerID completion:(void(^)(NSError*,NSDictionary*))completion
{
    [self respondToCommand:command withReply:reply toPeers:@[peerID] completion:completion];
}

- (CASCameraController*)locateCamera:(NSDictionary*)msg
{
    CASCameraController* camera;
    NSArray* cameras = [NSApp cameraControllers];
    NSString* ident = [msg[@"id"] description];
    for (CASCameraController* c in cameras){
        if ([ident isEqualToString:[c.uniqueID description]]){
            camera = c;
            break;
        }
    }
    return camera;
}

- (NSDictionary*)cameraStatus:(CASCameraController*)camera
{
    NSParameterAssert(camera);
    
    NSMutableDictionary* props = [NSMutableDictionary dictionaryWithCapacity:5];
    props[@"name"] = camera.device.deviceName;
    props[@"id"] = camera.uniqueID;
    props[@"state"] = @(camera.state); // todo; map to a string ?
    props[@"progress"] = @(camera.progress);
    NSString* uuid = camera.lastExposure.uuid;
    if (uuid){
        props[@"last-exposure"] = uuid;
    }
    NSArray* modes = camera.camera.binningModes;
    if (modes){
        props[@"binning-modes"] = modes;
    }
    props[@"binning"] = @(camera.settings.binning);
    props[@"continuous"] = @(camera.settings.continuous);
    props[@"seconds"] = camera.settings.exposureUnits ? @(camera.settings.exposureDuration/1000.0) : @(camera.settings.exposureDuration);
    if (!CGRectEqualToRect(camera.settings.subframe, NSZeroRect)){
        props[@"subframe"] = NSStringFromRect(camera.settings.subframe);
    }
    return [props copy];
}

- (void)session:(MCSession *)session didReceiveData:(NSData *)data fromPeer:(MCPeerID *)peerID
{
    dispatch_async(dispatch_get_main_queue(), ^{
        
        NSDictionary* msg = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:nil];
        NSLog(@"didReceiveData: %@",msg); // unpack json and dispatch
        if ([msg isKindOfClass:[NSDictionary class]]){
            
            NSString* const cmd = msg[@"cmd"];
            
            if ([cmd isEqualToString:@"ping"]){
                [self respondToCommand:msg withReply:nil toPeer:peerID completion:nil];
            }
            else if ([cmd isEqualToString:@"list-cameras"]){
                
                NSArray* cameras = [NSApp cameraControllers];
                NSMutableArray* response = [NSMutableArray arrayWithCapacity:[cameras count]];
                for (CASCameraController* camera in cameras){
                    [response addObject:[self cameraStatus:camera]];
                }
                [self respondToCommand:msg withReply:@{@"devices":response} toPeer:peerID completion:nil];
            }
            else if ([cmd isEqualToString:@"start-capture"]){
                
                CASCameraController* camera = [self locateCamera:msg];
                if (!camera){
                    [self respondToCommand:msg withReply:@{@"error":@"No such camera"} toPeer:peerID completion:nil];
                }
                else {
                    if (camera.state != CASCameraControllerStateNone){
                        [self respondToCommand:msg withReply:@{@"error":@"Camera is busy"} toPeer:peerID completion:nil];
                    }
                    else {
                        
                        [self respondToCommand:msg withReply:@{@"status":@"ok"} toPeer:peerID completion:nil];
                        
                        [CASPowerMonitor sharedInstance].disableSleep = YES;
                        
                        [camera captureWithBlock:^(NSError *error, CASCCDExposure *exposure) {
                            if (!camera.capturing){
                                [CASPowerMonitor sharedInstance].disableSleep = NO;
                            }
                        }];
                    }
                }
            }
            else if ([cmd isEqualToString:@"cancel-capture"]){
                
                CASCameraController* camera = [self locateCamera:msg];
                if (!camera){
                    // error
                }
                else {
                    [camera cancelCapture];
                    [self respondToCommand:msg withReply:nil toPeer:peerID completion:nil];
                }
            }
            else if ([cmd isEqualToString:@"camera-status"]){
                
                CASCameraController* camera = [self locateCamera:msg];
                if (!camera){
                    // error
                }
                else {
                    [self respondToCommand:msg withReply:@{@"status":[self cameraStatus:camera]} toPeer:peerID completion:nil];
                }
            }
            else if ([cmd isEqualToString:@"get-exposure"]){
                
                // sends latest image from the given camera to the peer, however it was captured
                // send a png, it's only for preview on the remote device
                
                CASCameraController* camera = [self locateCamera:msg];
                if (!camera){
                    [self respondToCommand:msg withReply:@{@"error":@"No such camera"} toPeer:peerID completion:nil];
                }
                else {
                    NSData* data = [[camera.lastExposure newImage] dataForUTType:(id)kUTTypePNG options:nil];
                    if (!data){
                        [self respondToCommand:msg withReply:@{@"error":@"No current exposure"} toPeer:peerID completion:nil];
                    }
                    else {
                        // send data to peer
                        NSString* path = [NSTemporaryDirectory() stringByAppendingPathComponent:camera.lastExposure.uuid];
                        [data writeToFile:path atomically:YES];
                        [self.session sendResourceAtURL:[NSURL fileURLWithPath:path] withName:camera.lastExposure.uuid toPeer:peerID withCompletionHandler:^(NSError *error) {
                            [[NSFileManager defaultManager] removeItemAtPath:path error:nil];
                        }];
                    }
                }
            }
            else if ([cmd isEqualToString:@"get-thumbnail"]){ // or flag to get-image
            }
        }
    });
}

- (void)session:(MCSession *)session didReceiveStream:(NSInputStream *)stream withName:(NSString *)streamName fromPeer:(MCPeerID *)peerID
{
    NSLog(@"didReceiveStream");
}

- (void)session:(MCSession *)session didStartReceivingResourceWithName:(NSString *)resourceName fromPeer:(MCPeerID *)peerID withProgress:(NSProgress *)progress
{
    NSLog(@"didStartReceivingResourceWithName");
}

- (void)session:(MCSession *)session didFinishReceivingResourceWithName:(NSString *)resourceName fromPeer:(MCPeerID *)peerID atURL:(NSURL *)localURL withError:(NSError *)error
{
    NSLog(@"didFinishReceivingResourceWithName");
}

@end

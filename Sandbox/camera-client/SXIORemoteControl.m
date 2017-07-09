//
//  SXIORemoteControl.m
//  camera-client
//
//  Created by Simon Taylor on 27/10/2014.
//  Copyright (c) 2014 Simon Taylor. All rights reserved.
//

#import "SXIORemoteControl.h"
@import MultipeerConnectivity;

@interface SXIORemoteControl ()<MCSessionDelegate>
@property (nonatomic,strong) NSMutableDictionary* completions;
@property (nonatomic,strong) MCPeerID* peerID;
@property (nonatomic,strong) MCSession* session;
@property (nonatomic,strong) MCNearbyServiceBrowser* browser;
@property (nonatomic,copy) void(^exposureCompletion)(NSProgress* progress,NSError *error, NSData *response);
@end

@implementation SXIORemoteControl

NSString* const kSXIORemoteControlConnectionLostNotification = @"kSXIORemoteControlConnectionLostNotification";
NSString* const kSXIORemoteControlConnectedNotification = @"kSXIORemoteControlConnectedNotification";

NSString* const kSXIORemoteControlCameraStatusChangedNotification = @"kSXIORemoteControlCameraStatusChangedNotification";
NSString* const kSXIORemoteControlCameraConnectedNotification = @"kSXIORemoteControlCameraConnectedNotification";
NSString* const kSXIORemoteControlCameraDisconnectedNotification = @"kSXIORemoteControlCameraDisconnectedNotification";

NSString* const kSXIORemoteControlMountStatusChangedNotification = @"kSXIORemoteControlMountStatusChangedNotification";
NSString* const kSXIORemoteControlMountConnectedNotification = @"kSXIORemoteControlMountConnectedNotification";
NSString* const kSXIORemoteControlMountDisconnectedNotification = @"kSXIORemoteControlMountDisconnectedNotification";

+ (instancetype)sharedControl
{
    static SXIORemoteControl* remote = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        remote = [SXIORemoteControl new];
    });
    return remote;
}

- (void)start
{
    if (!self.peerID){
        self.peerID = [[MCPeerID alloc] initWithDisplayName:[UIDevice currentDevice].name];
        self.session = [[MCSession alloc] initWithPeer:self.peerID securityIdentity:nil encryptionPreference:MCEncryptionNone];
        self.session.delegate = self;
        self.browser = [[MCNearbyServiceBrowser alloc] initWithPeer:self.peerID serviceType:@"sxio-server"];
    }
}

- (void)listCameras:(void(^)(NSError*,NSDictionary*))completion
{
    NSDictionary* listCameras = @{@"cmd":@"list-cameras"};
    [[SXIORemoteControl sharedControl] sendCommand:listCameras completion:completion];
}

- (void)listMounts:(void(^)(NSError*,NSDictionary*))completion
{
    NSDictionary* listMounts = @{@"cmd":@"list-mounts"};
    [[SXIORemoteControl sharedControl] sendCommand:listMounts completion:completion];
}

- (void)cameraStatusWithCamera:(NSString*)cameraID completion:(void(^)(NSError*,NSDictionary*))completion
{
    NSDictionary* cameraStatus = @{@"cmd":@"camera-status",@"id":cameraID};
    [[SXIORemoteControl sharedControl] sendCommand:cameraStatus completion:completion];
}

- (void)mountStatusWithMount:(NSString*)mountID completion:(void(^)(NSError*,NSDictionary*))completion
{
    NSDictionary* mountStatus = @{@"cmd":@"mount-status",@"id":mountID};
    [[SXIORemoteControl sharedControl] sendCommand:mountStatus completion:completion];
}

- (void)moveMount:(NSString*)mountID inDirection:(NSInteger)direction
{
    NSDictionary* moveMount = @{@"cmd":@"mount-move",@"id":mountID,@"direction":@(direction)};
    [[SXIORemoteControl sharedControl] sendCommand:moveMount completion:nil];
}

- (void)stopMountMove:(NSString*)mountID
{
    NSDictionary* moveMount = @{@"cmd":@"stop-mount-move",@"id":mountID};
    [[SXIORemoteControl sharedControl] sendCommand:moveMount completion:nil];
}

- (void)setMount:(NSString*)mountID moveRate:(NSInteger)moveRate
{
    NSDictionary* command = @{@"cmd":@"set-mount-move-rate",@"id":mountID,@"rate":@(moveRate)};
    [[SXIORemoteControl sharedControl] sendCommand:command completion:nil];
}

- (void)startCaptureWithCamera:(NSString*)cameraID completion:(void(^)(NSError*,NSDictionary*))completion
{
    NSDictionary* startCapture = @{@"cmd":@"start-capture",@"id":cameraID};
    [[SXIORemoteControl sharedControl] sendCommand:startCapture completion:completion];
}

- (void)getLastExposureWithCamera:(NSString*)cameraID completion:(void(^)(NSProgress*,NSError*,NSData*))completion
{
    NSParameterAssert(completion);
    self.exposureCompletion = completion; // may need a map of these
    NSDictionary* getExposure = @{@"cmd":@"get-exposure",@"id":cameraID};
    [[SXIORemoteControl sharedControl] sendCommand:getExposure completion:^(NSError *error, NSDictionary *response) {
        if (self.exposureCompletion){
            if (error || response[@"error"]){
                self.exposureCompletion(nil,error?:[NSError errorWithDomain:NSStringFromClass([self class])
                                                                       code:1
                                                                   userInfo:@{NSLocalizedFailureReasonErrorKey:response[@"error"]}],nil);
                self.exposureCompletion = nil;
            }
        }
    }];
}

- (void)sendCommand:(NSDictionary*)command completion:(void(^)(NSError*,NSDictionary*))completion
{
    NSError* error;
    NSMutableDictionary* mutableCommand = [command mutableCopy];
    mutableCommand[@"uuid"] = [NSUUID UUID].UUIDString;
    NSData* data = [NSJSONSerialization dataWithJSONObject:mutableCommand options:0 error:&error];
    if (!data){
        // error
    }
    else {
        if (completion){
            if (!self.completions){
                self.completions = [NSMutableDictionary dictionaryWithCapacity:5];
            }
            self.completions[mutableCommand[@"uuid"]] = [completion copy];
        }
        const BOOL success = [self.session sendData:data toPeers:self.session.connectedPeers withMode:MCSessionSendDataReliable error:&error];
        if (!success){
            // error
            [self.completions removeObjectForKey:mutableCommand[@"uuid"]];
        }
    }
}

- (void)session:(MCSession *)session peer:(MCPeerID *)peerID didChangeState:(MCSessionState)state
{
    NSLog(@"didChangeState: %ld",state);
    
    if (state == MCSessionStateNotConnected){
        [[NSNotificationCenter defaultCenter] postNotificationName:kSXIORemoteControlConnectionLostNotification object:nil];
    }
    if (state == MCSessionStateConnected || state == MCSessionStateConnecting){
        [[SXIORemoteControl sharedControl].browser stopBrowsingForPeers];
    }
    if (state == MCSessionStateConnected){
        [[NSNotificationCenter defaultCenter] postNotificationName:kSXIORemoteControlConnectedNotification object:nil];
    }
}

- (void)session:(MCSession *)session didReceiveData:(NSData *)data fromPeer:(MCPeerID *)peerID
{
    NSDictionary* msg = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:nil];
    NSLog(@"didReceiveData: %@",msg); // unpack json and dispatch
    if ([msg isKindOfClass:[NSDictionary class]]){
        dispatch_async(self.queue ?: dispatch_get_main_queue(), ^{
            NSString* const uuid = msg[@"uuid"];
            void(^completion)(NSError*,NSDictionary*) = self.completions[uuid];
            if (completion){
                completion(nil,msg);
                [self.completions removeObjectForKey:uuid];
            }
            if ([msg[@"cmd"] isEqualToString:@"camera-status-changed"]){
                [[NSNotificationCenter defaultCenter] postNotificationName:kSXIORemoteControlCameraStatusChangedNotification object:self userInfo:msg[@"status"]];
            }
            if ([msg[@"cmd"] isEqualToString:@"mount-status-changed"]){
                [[NSNotificationCenter defaultCenter] postNotificationName:kSXIORemoteControlMountStatusChangedNotification object:self userInfo:msg[@"status"]];
            }
            else if ([msg[@"cmd"] isEqualToString:@"camera-connected"]){
                [[NSNotificationCenter defaultCenter] postNotificationName:kSXIORemoteControlCameraConnectedNotification object:self userInfo:msg];
            }
            else if ([msg[@"cmd"] isEqualToString:@"camera-disconnected"]){
                [[NSNotificationCenter defaultCenter] postNotificationName:kSXIORemoteControlCameraDisconnectedNotification object:self userInfo:msg];
            }
        });
    }
}

- (void)session:(MCSession *)session didReceiveStream:(NSInputStream *)stream withName:(NSString *)streamName fromPeer:(MCPeerID *)peerID
{
    NSLog(@"didReceiveStream");
}

- (void)session:(MCSession *)session didStartReceivingResourceWithName:(NSString *)resourceName fromPeer:(MCPeerID *)peerID withProgress:(NSProgress *)progress
{
    //NSLog(@"didStartReceivingResourceWithName: %@",resourceName);
    dispatch_async(self.queue ?: dispatch_get_main_queue(), ^{
        if (self.exposureCompletion){
            self.exposureCompletion(progress,nil,nil);
        }
    });
}

- (void)session:(MCSession *)session didFinishReceivingResourceWithName:(NSString *)resourceName fromPeer:(MCPeerID *)peerID atURL:(NSURL *)localURL withError:(NSError *)error
{
    //NSLog(@"didFinishReceivingResourceWithName: %@",resourceName);
    dispatch_async(self.queue ?: dispatch_get_main_queue(), ^{
        if (self.exposureCompletion){
            self.exposureCompletion(nil,error,[NSData dataWithContentsOfURL:localURL]);
            [[NSFileManager defaultManager] removeItemAtURL:localURL error:nil];
            self.exposureCompletion = nil;
        }
    });
}

@end

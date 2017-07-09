//
//  SXIORemoteControl.h
//  camera-client
//
//  Created by Simon Taylor on 27/10/2014.
//  Copyright (c) 2014 Simon Taylor. All rights reserved.
//

#import <UIKit/UIKit.h>
@import MultipeerConnectivity;

@interface SXIORemoteControl : NSObject
+ (instancetype)sharedControl;

- (void)start;

- (void)listCameras:(void(^)(NSError*,NSDictionary*))completion;

- (void)cameraStatusWithCamera:(NSString*)cameraID completion:(void(^)(NSError*,NSDictionary*))completion;
- (void)startCaptureWithCamera:(NSString*)cameraID completion:(void(^)(NSError*,NSDictionary*))completion;
- (void)getLastExposureWithCamera:(NSString*)cameraID completion:(void(^)(NSProgress*,NSError*,NSData*))completion;

- (void)listMounts:(void(^)(NSError*,NSDictionary*))completion;
- (void)mountStatusWithMount:(NSString*)mountID completion:(void(^)(NSError*,NSDictionary*))completion;
- (void)moveMount:(NSString*)mountID inDirection:(NSInteger)direction;
- (void)stopMountMove:(NSString*)mountID;
- (void)setMount:(NSString*)mountID moveRate:(NSInteger)moveRate;

@property (nonatomic,strong,readonly) MCSession* session;
@property (nonatomic,strong,readonly) MCNearbyServiceBrowser* browser;
@property (nonatomic,strong) dispatch_queue_t queue;

extern NSString* const kSXIORemoteControlConnectedNotification;
extern NSString* const kSXIORemoteControlConnectionLostNotification;

extern NSString* const kSXIORemoteControlCameraStatusChangedNotification;
extern NSString* const kSXIORemoteControlCameraConnectedNotification;
extern NSString* const kSXIORemoteControlCameraDisconnectedNotification;

extern NSString* const kSXIORemoteControlMountStatusChangedNotification;
extern NSString* const kSXIORemoteControlMountConnectedNotification;
extern NSString* const kSXIORemoteControlMountConnectedNotification;

@end

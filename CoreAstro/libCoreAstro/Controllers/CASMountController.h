//
//  CASMountController.h
//  CoreAstro
//
//  Created by Simon Taylor on 1/9/16.
//  Copyright © 2016 Simon Taylor. All rights reserved.
//
//  This will eventually absorb most of the mount handling functionality
//  scattered about the app but for now its mainly just to enable scripting

#import "CASDeviceController.h"
#import "CASMount.h"
#import "CASCameraController.h"

@interface CASMountController : CASDeviceController

- (instancetype)initWithMount:(CASMount*)mount;

@property BOOL usePlateSolving;
@property (nonatomic,readonly) BOOL busy;
@property (nonatomic,readonly) BOOL synchronising;
@property (nonatomic,readonly,strong) CASDevice<CASMount>* mount;
@property (nonatomic,readonly,copy) NSString* status;
@property (nonatomic,strong) CASCameraController* cameraController;

- (void)setTargetRA:(double)raDegs dec:(double)decDegs completion:(void(^)(NSError*))completion;
- (void)slewToTargetWithCompletion:(void(^)(NSError*))completion;

- (void)slewToBookmark:(NSDictionary*)bookmark plateSolve:(BOOL)plateSolve completion:(void(^)(NSError*))completion;
- (void)parkMountWithCompletion:(void(^)(NSError*))completion;

- (void)stop;

extern NSString* kCASMountControllerCapturedSyncExposureNotification;
extern NSString* kCASMountControllerSolvedSyncExposureNotification;
extern NSString* kCASMountControllerCompletedSyncNotification;

@end

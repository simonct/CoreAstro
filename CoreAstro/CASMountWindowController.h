//
//  CASMountWindowController.h
//  ieq-test
//
//  Created by Simon Taylor on 1/26/14.
//  Copyright (c) 2014 Simon Taylor. All rights reserved.
//

#import <CoreAstro/CoreAstro.h>

@class CASCameraController;
@class CASMountController;
@class CASMountWindowController;

@interface CASMountWindowController : NSWindowController
@property (nonatomic,readonly) double separation;
@property (nonatomic,strong) CASCameraController* cameraController;
@property (nonatomic,strong,readonly) CASMountController* mountController;
@end

@interface CASMountWindowController (Global)
- (void)connectToMount:(void(^)())completion;
- (void)connectToMountAtPath:(NSString*)path completion:(void(^)(NSError*,CASMountController*))completion;
+ (instancetype)sharedMountWindowController;
@end

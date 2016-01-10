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

@protocol CASMountWindowControllerDelegate <NSObject>
- (CASPlateSolveSolution*)plateSolveSolution;
- (void)mountWindowController:(CASMountWindowController*)windowController didCaptureExposure:(CASCCDExposure*)exposure;
- (void)mountWindowController:(CASMountWindowController*)windowController didSolveExposure:(CASPlateSolveSolution*)solution;
- (void)mountWindowController:(CASMountWindowController*)windowController didCompleteWithError:(NSError*)error;
- (void)mountWindowControllerDidClose:(CASMountWindowController*)windowController;
@end

@interface CASMountWindowController : NSWindowController
@property (nonatomic,weak) CASCameraController* cameraController; // override the popup menu with a designated camera controller
@property (nonatomic,weak) id<CASMountWindowControllerDelegate> mountWindowDelegate;
@property (nonatomic,readonly) double separation;
@property (nonatomic,strong,readonly) CASMount* mount;
@property (nonatomic,strong,readonly) CASMountSynchroniser* mountSynchroniser; // tmp for flipping
@property (nonatomic) BOOL usePlateSolving;
- (void)connectToMount:(CASMount*)mount completion:(void(^)(NSError*))completion;
- (void)setTargetRA:(double)raDegs dec:(double)decDegs;
@end

@interface CASMountWindowController (Sequence)
- (void)slewToBookmarkWithName:(NSString*)name completion:(void(^)(NSError*))completion;
@end

@interface CASMountWindowController (Global)
- (void)connectToMount:(void(^)())completion;
- (void)connectToMountAtPath:(NSString*)path completion:(void(^)(NSError*,CASMountController*))completion;
+ (instancetype)sharedMountWindowController;
@end
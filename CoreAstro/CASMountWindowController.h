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
- (void)mountWindowControllerWillClose:(CASMountWindowController*)windowController;
@end

@interface CASMountWindowController : NSWindowController
@property (nonatomic,weak) CASCameraController* cameraController; // override the popup menu with a designated camera controller
@property (nonatomic,weak) id<CASMountWindowControllerDelegate> mountWindowDelegate;
@property (nonatomic,readonly) double separation;
@property (nonatomic,strong,readonly) CASMountController* mountController;
@end

@interface CASMountWindowController (Global)
- (void)connectToMount:(void(^)())completion;
- (void)connectToMountAtPath:(NSString*)path completion:(void(^)(NSError*,CASMountController*))completion;
+ (instancetype)sharedMountWindowController;
@end
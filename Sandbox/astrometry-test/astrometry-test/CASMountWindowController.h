//
//  CASMountWindowController.h
//  ieq-test
//
//  Created by Simon Taylor on 1/26/14.
//  Copyright (c) 2014 Simon Taylor. All rights reserved.
//

#import <CoreAstro/CoreAstro.h>

@class CASMountWindowController;

@protocol CASMountWindowControllerDelegate <NSObject>
- (void)mountWindowController:(CASMountWindowController*)windowController didCaptureExposure:(CASCCDExposure*)exposure;
- (void)mountWindowController:(CASMountWindowController*)windowController didSolveExposure:(CASPlateSolveSolution*)solution;
@end

@interface CASMountWindowController : NSWindowController
@property (nonatomic,weak) id<CASMountWindowControllerDelegate> mountWindowDelegate;
- (void)connectToMount:(CASMount*)mount completion:(void(^)(NSError*))completion;
- (void)startSlewTo:(double)ra dec:(double)dec;
@end

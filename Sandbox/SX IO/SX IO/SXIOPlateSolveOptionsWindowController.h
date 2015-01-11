//
//  SXIOPlateSolveOptionsWindowController.h
//  SX IO
//
//  Created by Simon Taylor on 2/21/14.
//  Copyright (c) 2014 Simon Taylor. All rights reserved.
//

#import <CoreAstro/CoreAstro.h>
#import "CASAuxWindowController.h"

@interface SXIOPlateSolveOptionsWindowController : CASAuxWindowController

@property (nonatomic,readonly) float focalLength;
@property (nonatomic,readonly) float pixelSize;
@property (nonatomic,readonly) float sensorWidth;
@property (nonatomic,readonly) float sensorHeight;
@property (nonatomic,readonly) NSInteger binning;
@property (nonatomic,readonly) CGSize fieldSizeDegrees;
@property (nonatomic,readonly) float arcsecsPerPixel;
@property (nonatomic,readonly) BOOL enableFieldSize;
@property (nonatomic,readonly) BOOL enablePixelSize;

@property (nonatomic,weak) CASCCDExposure* exposure;
@property (nonatomic,weak) CASCameraController* cameraController;
//@property (nonatomic,copy) void (^completion)(BOOL);
@end

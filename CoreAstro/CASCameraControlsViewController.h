//
//  CASCameraControlsViewController.h
//  CoreAstro
//
//  Created by Simon Taylor on 6/2/13.
//  Copyright (c) 2013 Mako Technology Ltd. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class CASCCDExposure;
@class CASCameraController;

@interface CASCameraControlsViewController : NSViewController
@property (nonatomic,strong) CASCCDExposure* exposure;
@property (nonatomic,strong) CASCameraController* cameraController;
@end

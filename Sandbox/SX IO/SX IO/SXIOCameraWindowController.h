//
//  SXIOCameraWindowController.h
//  SX IO
//
//  Created by Simon Taylor on 7/21/13.
//  Copyright (c) 2013 Simon Taylor. All rights reserved.
//

#import <CoreAstro/CoreAstro.h>

#import "CASExposureView.h"

@interface SXIOCameraWindowController : NSWindowController
@property (weak) IBOutlet CASExposureView *exposureView;
@property (nonatomic,strong) CASCameraController* cameraController;
@end

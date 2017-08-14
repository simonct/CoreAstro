//
//  SXIOCameraWindowController.h
//  SX IO
//
//  Created by Simon Taylor on 7/21/13.
//  Copyright (c) 2013 Simon Taylor. All rights reserved.
//

#import <CoreAstro/CoreAstro.h>

#import "CASExposureView.h"
#import "SXIOSequenceEditorWindowController.h"

@interface SXIOCameraWindowController : NSWindowController<SXIOSequenceTarget>
@property (weak) IBOutlet CASExposureView *exposureView;
@property (nonatomic,weak) CASCameraController* cameraController;
@property (nonatomic,weak) CASMountController* mountController;
@property (nonatomic,copy,readonly) NSString* cameraDeviceID;
- (BOOL)openExposureAtPath:(NSString*)path;
@end

//
//  SXIOSequenceEditorWindowController.h
//  SX IO
//
//  Created by Simon Taylor on 1/5/15.
//  Copyright (c) 2015 Simon Taylor. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class CASCameraController;

@interface SXIOSequenceEditorWindowController : NSWindowController

@property (nonatomic,weak) CASCameraController* cameraController;

+ (instancetype)loadSequenceEditor;

@end

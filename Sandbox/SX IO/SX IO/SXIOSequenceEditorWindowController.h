//
//  SXIOSequenceEditorWindowController.h
//  SX IO
//
//  Created by Simon Taylor on 1/5/15.
//  Copyright (c) 2015 Simon Taylor. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "CASAuxWindowController.h"

@class CASCameraController;
@class CASFilterWheelController;
@class CASMountController;

@protocol SXIOSequenceTarget <NSObject>
@required
@property (nonatomic,readonly) CASCameraController* sequenceCameraController;
@property (nonatomic,readonly) CASFilterWheelController* sequenceFilterWheelController;
@property (nonatomic,readonly) CASMountController* sequenceMountController;
- (BOOL)prepareToStartSequenceWithError:(NSError**)error;
- (void)captureWithCompletion:(void(^)(NSError*))completion;
- (void)slewToBookmark:(NSDictionary*)bookmark completion:(void(^)(NSError*))completion;
- (void)endSequence;
@end

@interface SXIOSequenceEditorWindowController : CASAuxWindowController

@property (nonatomic,weak) id<SXIOSequenceTarget> target;

@end

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
@property (nonatomic,readonly) CASMountController* sequenceMountController; // tmp
@property (nonatomic,readonly) CASCameraController* sequenceCameraController; // tmp
- (BOOL)prepareToStartSequenceWithError:(NSError**)error;
- (void)captureWithCompletion:(void(^)(NSError*))completion;
- (void)slewToBookmark:(NSDictionary*)bookmark plateSolve:(BOOL)plateSolve completion:(void(^)(NSError*))completion;
- (void)parkMountWithCompletion:(void(^)(NSError*))completion;
- (void)endSequence;
@end

@interface CASSequence : NSObject<NSCoding>
@end

@interface SXIOSequenceEditorWindowController : CASAuxWindowController

@property (nonatomic,strong) CASSequence* sequence;
@property (nonatomic,weak) id<SXIOSequenceTarget> target;
@property (nonatomic,readonly) BOOL stopped;

- (BOOL)openURL:(NSURL*)url doubleClicked:(BOOL)doubleClicked;

+ (instancetype)sharedWindowController;

@end

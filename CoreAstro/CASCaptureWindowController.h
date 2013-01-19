//
//  CASCaptureWindowController.h
//  CoreAstro
//
//  Created by Simon Taylor on 1/19/13.
//  Copyright (c) 2013 Mako Technology Ltd. All rights reserved.
//

#import "CASAuxWindowController.h"

@class CASImageProcessor;
@class CASCameraController;

@interface CASCaptureModel : NSObject
@property (nonatomic,assign) NSInteger captureCount;
enum {
    kCASCaptureModelModeDark,
    kCASCaptureModelModeBias,
    kCASCaptureModelModeFlat
};
@property (nonatomic,assign) NSInteger captureMode;
@property (nonatomic,assign) NSInteger exposureSeconds;
enum {
    kCASCaptureModelCombineNone,
    kCASCaptureModelCombineAverage
};
@property (nonatomic,assign) NSInteger combineMode;
@property (nonatomic,assign) BOOL keepOriginals;
@property (nonatomic,assign) BOOL matchHistograms;
@end

@interface CASCaptureWindowController : CASAuxWindowController
@property (nonatomic,strong) CASCaptureModel* model;
@end

@interface CASCaptureController : NSObject
@property (nonatomic,strong) CASCaptureModel* model;
@property (nonatomic,strong) CASCameraController* cameraController;
@property (nonatomic,strong) CASImageProcessor* imageProcessor;
- (void)captureWithBlock:(void(^)(NSError* error))block;
+ (CASCaptureController*)captureControllerWithWindowController:(CASCaptureWindowController*)cwc;
@end
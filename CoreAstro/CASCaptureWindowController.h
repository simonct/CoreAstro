//
//  CASCaptureWindowController.h
//  CoreAstro
//
//  Created by Simon Taylor on 1/19/13.
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is furnished
//  to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
//  THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
//  FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
//  IN THE SOFTWARE.
//

#import "CASAuxWindowController.h"

@class CASCCDExposure;
@class CASImageProcessor;
@class CASCameraController;
@class CASExposuresController;

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
@property (nonatomic,assign) BOOL keepOriginals, showKeepOriginals;
@property (nonatomic,assign) BOOL matchHistograms, showMatchHistograms;
@end

@class CASCaptureWindowController;

@protocol CASCaptureWindowControllerDelegate <NSObject>
- (BOOL)captureWindow:(CASCaptureWindowController*)captureWindow didCapture:(CASCCDExposure*)exposure mode:(NSInteger)mode;
- (void)captureWindowDidComplete:(CASCaptureWindowController*)captureWindow;
@end

@interface CASCaptureWindowController : CASAuxWindowController
@property (nonatomic,strong) CASCaptureModel* model;
@property (nonatomic,weak) CASCameraController* cameraController;
@property (nonatomic,strong) CASImageProcessor* imageProcessor;
@property (nonatomic,weak) id<CASCaptureWindowControllerDelegate> delegate;

- (void)presentRelativeToWindow:(NSWindow*)window;

@end

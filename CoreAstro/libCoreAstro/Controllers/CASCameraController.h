//
//  CASCameraController.h
//  CoreAstro
//
//  Copyright (c) 2012, Simon Taylor
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

#import "CASScriptableObject.h"
#import "CASCCDExposure.h"

@class CASCCDDevice;
@class CASImageProcessor;
@class CASGuideAlgorithm;
@class CASGuiderController;
@class CASCCDExposure;
@class CASMovieExporter;

@interface CASCameraController : CASScriptableObject

@property (nonatomic,readonly,strong) CASCCDDevice* camera;

typedef NS_ENUM(NSInteger, CASCameraControllerState) {
    CASCameraControllerStateNone,
    CASCameraControllerStateWaitingForTemperature,
    CASCameraControllerStateExposing, // or downloading
    CASCameraControllerStateWaitingForNextExposure
};
@property (nonatomic,readonly) CASCameraControllerState state;
@property (nonatomic,readonly) float progress;

@property (nonatomic,readonly) BOOL capturing;
@property (nonatomic,readonly) BOOL waitingForNextCapture;

@property (nonatomic,assign) BOOL temperatureLock;
@property (nonatomic,assign) BOOL continuous;
@property (nonatomic,assign) NSInteger captureCount;
@property (nonatomic,assign) NSInteger currentCaptureIndex;
@property (nonatomic,readonly) NSTimeInterval continuousNextExposureTime;

@property (nonatomic,assign) NSInteger exposure; // -> exposureTime/exposureDuration
@property (nonatomic,assign) NSInteger exposureUnits;
@property (nonatomic,assign) NSInteger binningIndex;
@property (nonatomic,assign) NSInteger exposureInterval;
@property (nonatomic,assign) CGRect subframe;
@property (nonatomic,assign) CASCCDExposureType exposureType;
@property (nonatomic,strong) NSDate* exposureStart;

@property (nonatomic,strong) CASCCDExposure* lastExposure;

@property (nonatomic,strong) CASGuiderController* guider;
@property (nonatomic,strong) CASImageProcessor* imageProcessor;
@property (nonatomic,strong) CASGuideAlgorithm* guideAlgorithm;

@property (nonatomic,strong) CASMovieExporter* movieExporter;

- (id)initWithCamera:(CASCCDDevice*)camera;

- (void)connect:(void(^)(NSError*))block;
- (void)disconnect;

- (void)captureWithBlock:(void(^)(NSError*,CASCCDExposure*))block;

- (void)cancelCapture;

@end

extern NSString* const kCASCameraControllerGuideErrorNotification;
extern NSString* const kCASCameraControllerGuideCommandNotification;
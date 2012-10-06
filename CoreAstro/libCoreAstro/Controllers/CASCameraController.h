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

@class CASCCDDevice;
@class CASImageProcessor;
@class CASGuideAlgorithm;
@class CASCCDExposure;
@class CASGuiderController;

@interface CASCameraController : CASScriptableObject

@property (nonatomic,readonly,strong) CASCCDDevice* camera;

@property (nonatomic,readonly) BOOL capturing;
@property (nonatomic,assign) BOOL continuous;
@property (nonatomic,assign) NSInteger captureCount;
@property (nonatomic,assign) NSInteger currentCaptureIndex;
@property (nonatomic,readonly) NSTimeInterval continuousNextExposureTime;

@property (nonatomic,assign) NSInteger exposure;
@property (nonatomic,assign) NSInteger exposureUnits;
@property (nonatomic,assign) NSInteger binningIndex;
@property (nonatomic,assign) NSInteger interval;
@property (nonatomic,assign) CGRect subframe;
@property (nonatomic,strong) NSDate* exposureStart;

@property (nonatomic,assign) BOOL guiding;
@property (nonatomic,strong) CASGuiderController* guider;
@property (nonatomic,strong) CASImageProcessor* imageProcessor;
@property (nonatomic,strong) CASGuideAlgorithm* guideAlgorithm;

- (id)initWithCamera:(CASCCDDevice*)camera;

- (void)connect:(void(^)(NSError*))block;
- (void)disconnect;

- (void)captureWithBlock:(void(^)(NSError*,CASCCDExposure*))block;

@end
//
//  CASSequence.h
//  CoreAstro
//
//  Created by Simon Taylor on 1/11/14.
//  Copyright (c) 2014 Mako Technology Ltd. All rights reserved.
//

#import "CASScriptableObject.h"
#import "CASCCDExposure.h"

@class CASCameraController;

@interface CASExposureSettings : CASScriptableObject

@property (nonatomic,weak) CASCameraController* cameraController;

@property (nonatomic,assign) BOOL continuous;

@property (nonatomic,assign) NSInteger captureCount;
@property (nonatomic,readonly) NSInteger currentCaptureIndex;

@property (nonatomic,assign) NSInteger exposureDuration;
@property (nonatomic,assign) NSInteger exposureUnits;
@property (nonatomic,assign) NSInteger exposureInterval;

@property (nonatomic,assign) CGRect subframe;
@property (nonatomic,assign) NSInteger binning;

@property (nonatomic,assign) CASCCDExposureType exposureType;

@property (nonatomic,assign) BOOL ditherEnabled;
@property (nonatomic,assign) float ditherPixels;

@end

@interface CASExposureSettings (Bindings)
@property (nonatomic,assign) NSInteger binningIndex;
@end

@interface CASExposureSettings (CASScripting)
@property (nonatomic,strong) NSNumber* scriptingSequenceCount;
@property (nonatomic,readonly) NSNumber* scriptingSequenceIndex;
@property (nonatomic,strong) NSNumber* scriptingInterval;
@property (nonatomic,strong) NSNumber* scriptingDitherPixels;
@property (nonatomic,strong) NSNumber* scriptingBinning;
@property (nonatomic,strong) NSNumber* scriptingDuration;
@end

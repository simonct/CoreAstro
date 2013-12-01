//
//  CASFilterPipeline.h
//  CoreAstro
//
//  Created by Simon Taylor on 11/30/13.
//  Copyright (c) 2013 Mako Technology Ltd. All rights reserved.
//

#import "CASCCDExposure.h"
#import "CASImageDebayer.h"
#import "CASImageProcessor.h"

@interface CASFilterPipeline : NSObject
@property (nonatomic,assign) BOOL equalise;
@property (nonatomic,assign) NSInteger debayerMode;

@property (nonatomic) BOOL invert;
@property (nonatomic) BOOL medianFilter;
@property (nonatomic) BOOL contrastStretch;
@property (nonatomic) float stretchMin, stretchMax, stretchGamma; // contrast stretch 0->1
//@property (nonatomic) BOOL debayer;
//@property (nonatomic) CGRect extent;
@property (nonatomic) BOOL flipVertical, flipHorizontal;

- (CASCCDExposure*)preprocessedExposureWithExposure:(CASCCDExposure*)exposure;
- (CIImage*)filteredImageWithExposure:(CASCCDExposure*)exposure;
- (CVPixelBufferRef)pixelBufferWithExposure:(CASCCDExposure*)exposure;
@end

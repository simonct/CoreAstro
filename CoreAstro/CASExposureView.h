//
//  CASExposureView.h
//  CoreAstro
//
//  Created by Simon Taylor on 02/12/12.
//  Copyright (c) 2012 Mako Technology Ltd. All rights reserved.
//

#import "CASImageView.h"

@class CASCCDExposure;
@class CASImageProcessor;

@interface CASExposureView : CASImageView
@property (nonatomic,assign) BOOL showReticle;
@property (nonatomic,assign) CGPoint starLocation;
@property (nonatomic,assign) CGPoint lockLocation;
@property (nonatomic,assign) CGFloat searchRadius;
@property (nonatomic,strong) CASCCDExposure* exposure;
@property (nonatomic,assign) BOOL showHistogram;
@property (nonatomic,assign) BOOL scaleSubframe;
@property (nonatomic,strong) CASImageProcessor* imageProcessor;
@end

extern const CGPoint kCASImageViewInvalidStarLocation;


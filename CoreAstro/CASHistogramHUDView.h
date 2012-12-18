//
//  CADHistogramHUDView.h
//  CoreAstro
//
//  Created by Simon Taylor on 12/18/12.
//  Copyright (c) 2012 Mako Technology Ltd. All rights reserved.
//

#import "CASHUDView.h"

@class CASCCDExposure;
@class CASImageProcessor;

@interface CASHistogramHUDView : CASHUDView
@property (nonatomic,strong) CASImageProcessor* imageProcessor;
@property (nonatomic,weak) CASCCDExposure* exposure;
@end

//
//  CASPlateSolvedObject+Drawing.h
//  CoreAstro
//
//  Created by Simon Taylor on 6/8/13.
//  Copyright (c) 2013 Mako Technology Ltd. All rights reserved.
//

#import "CASPlateSolver.h"
#include <QuartzCore/QuartzCore.h>

@interface CASAnnotationLayer : CALayer
@property (nonatomic,weak) CATextLayer* textLayer;
@property (nonatomic,weak) CASPlateSolvedObject* object;
@end

@interface CASPlateSolvedObject (Drawing)
- (CASAnnotationLayer*)createLayerInLayer:(CALayer*)annotationLayer withFont:(NSFont*)font andColour:(CGColorRef)colour scaling:(NSInteger)scaling;
@end

//
//  CASPlateSolveImageView.h
//  astrometry-test
//
//  Created by Simon Taylor on 6/9/13.
//  Copyright (c) 2013 Simon Taylor. All rights reserved.
//

#import "CASImageView.h"
#import <QuartzCore/QuartzCore.h>

@class CASLX200IPClient;

@interface CASPlateSolveImageView : CASImageView
@property (nonatomic,assign) BOOL acceptDrop;
@property (nonatomic,strong) CALayer* annotationLayer;
@property (nonatomic,strong) NSArray* annotations;
@property (nonatomic,strong) NSFont* annotationsFont;
@property (nonatomic,strong) CATextLayer* draggingAnnotation;
@property (nonatomic,strong) CATextLayer* eqMacAnnotation;
@property (nonatomic,weak) CASLX200IPClient* ipMountClient;
- (void)createAnnotations;
- (void)updateAnnotations;
@end

//
//  CASPlateSolveImageView.h
//  astrometry-test
//
//  Created by Simon Taylor on 6/9/13.
//  Copyright (c) 2013 Simon Taylor. All rights reserved.
//

#import "CASImageView.h"
#import <QuartzCore/QuartzCore.h>
#import <CoreAstro/CoreAstro.h>

@class CASMount;

@interface CASPlateSolveImageView : CASImageView
@property (nonatomic,assign) BOOL acceptDrop;
@property (nonatomic,strong) CALayer* annotationLayer;
@property (nonatomic,strong) NSArray* annotations;
@property (nonatomic,strong) NSFont* annotationsFont;
@property (nonatomic,strong) CATextLayer* draggingAnnotation;
@property (nonatomic,strong) CATextLayer* eqMacAnnotation;
@property (nonatomic,weak) CASMount* mount;
+ (NSData*)imageDataFromExposurePath:(NSString*)path error:(NSError**)error;
- (void)createAnnotations;
- (void)updateAnnotations;
@end

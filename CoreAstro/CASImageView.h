//
//  CASImageView.h
//  CoreAstro
//
//  Created by Simon Taylor on 9/22/12.
//  Copyright (c) 2012 Mako Technology Ltd. All rights reserved.
//

#import <Quartz/Quartz.h>

@interface CASImageView : IKImageView
- (CGRect)selectionRect;
@property (nonatomic,assign) BOOL showReticle;
@property (nonatomic,assign) CGPoint starLocation;
@property (nonatomic,assign) CGPoint lockLocation;
@property (nonatomic,assign) CGFloat searchRadius;
@end

extern const CGPoint kCASImageViewInvalidStarLocation;


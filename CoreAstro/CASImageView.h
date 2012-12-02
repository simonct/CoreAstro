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
- (void)disableAnimations:(void(^)(void))block;
@end


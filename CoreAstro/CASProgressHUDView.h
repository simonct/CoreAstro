//
//  CASProgressHUDView.h
//  CoreAstro
//
//  Created by Simon Taylor on 12/18/12.
//  Copyright (c) 2012 Mako Technology Ltd. All rights reserved.
//

#import "CASHUDView.h"

@interface CASProgressHUDView : CASHUDView
- (CGFloat)progress;
- (void)setProgress:(CGFloat)progress label:(NSString*)label;
@end

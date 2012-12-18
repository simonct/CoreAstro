//
//  CASStarInfoHUDView.h
//  CoreAstro
//
//  Created by Simon Taylor on 12/18/12.
//  Copyright (c) 2012 Mako Technology Ltd. All rights reserved.
//

#import "CASHUDView.h"

@class CASCCDExposure;

@interface CASStarInfoHUDView : CASHUDView
- (void)setExposure:(CASCCDExposure*)exposure starPosition:(NSPoint)position;
@end

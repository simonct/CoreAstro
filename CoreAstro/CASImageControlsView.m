//
//  CASImageControlsView.m
//  CoreAstro
//
//  Created by Simon Taylor on 9/22/12.
//  Copyright (c) 2012 Mako Technology Ltd. All rights reserved.
//

#import "CASImageControlsView.h"

@implementation CASImageControlsView

- (void)drawRect:(NSRect)dirtyRect
{
    [[NSColor colorWithCalibratedRed:0.9 green:0.9 blue:0.9 alpha:1] set];
    NSRectFill(dirtyRect);
}

@end

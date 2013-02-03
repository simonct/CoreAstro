//
//  CASPlateSolutionHUDView.m
//  CoreAstro
//
//  Created by Simon Taylor on 03/02/13.
//  Copyright (c) 2013 Mako Technology Ltd. All rights reserved.
//

#import "CASPlateSolutionHUDView.h"

@interface CASPlateSolutionHUDView ()
@end

@implementation CASPlateSolutionHUDView

- (void)setSolution:(CASPlateSolveSolution *)solution
{
    if (_solution != solution){
        _solution = solution;
        [self setNeedsDisplay:YES];
    }
}

// display

@end

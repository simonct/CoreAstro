//
//  CASPlateSolutionHUDView.m
//  CoreAstro
//
//  Created by Simon Taylor on 03/02/13.
//  Copyright (c) 2013 Mako Technology Ltd. All rights reserved.
//

#import "CASPlateSolutionHUDView.h"

@interface CASPlateSolutionHUDView ()
@property (weak) IBOutlet NSObjectController *solutionController;
@end

@implementation CASPlateSolutionHUDView

- (void)viewDidMoveToSuperview
{
    [super viewDidMoveToSuperview];
    
    if (![self superview]){
        self.solutionController.content = nil;
    }
    else {
        self.solutionController.content = self.solution;
    }
}

@end

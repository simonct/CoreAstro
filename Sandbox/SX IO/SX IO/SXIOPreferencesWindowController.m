//
//  SXIOPreferencesWindowController.m
//  SX IO
//
//  Created by Simon Taylor on 1/7/14.
//  Copyright (c) 2014 Simon Taylor. All rights reserved.
//

#import "SXIOPreferencesWindowController.h"
#import <CoreAstro/CoreAstro.h>

@interface SXIOPreferencesWindowController ()
@property (nonatomic,strong) CASPlateSolver* solver;
@end

@implementation SXIOPreferencesWindowController

- (id)initWithWindow:(NSWindow *)window
{
    self = [super initWithWindow:window];
    if (self) {
        self.solver = [CASPlateSolver plateSolverWithIdentifier:nil];
    }
    return self;
}

@end

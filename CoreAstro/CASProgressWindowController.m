//
//  CASProgressWindowController.m
//  CoreAstro
//
//  Created by Simon Taylor on 11/3/12.
//  Copyright (c) 2012 Mako Technology Ltd. All rights reserved.
//

#import "CASProgressWindowController.h"

@interface CASProgressWindowController ()
@end

@implementation CASProgressWindowController

- (void)windowDidLoad
{
    [super windowDidLoad];
    
    self.label.stringValue = @"";
    self.progressBar.indeterminate = YES;
    self.progressBar.usesThreadedAnimation = YES;
    [self.progressBar startAnimation:nil];
}

- (void)beginSheetModalForWindow:(NSWindow*)window
{
    [super beginSheetModalForWindow:window completionHandler:^(NSInteger code) {
        [self.progressBar stopAnimation:nil];
    }];
}

- (void)configureWithRange:(NSRange)range label:(NSString*)label
{
    self.label.stringValue = label;
    self.progressBar.doubleValue = 0;
    self.progressBar.minValue = range.location;
    self.progressBar.maxValue = range.length;
    self.progressBar.indeterminate = NO;
}

@end

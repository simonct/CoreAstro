//
//  CASLibraryBrowserView.m
//  CoreAstro
//
//  Created by Simon Taylor on 11/4/12.
//  Copyright (c) 2012 Mako Technology Ltd. All rights reserved.
//

#import "CASLibraryBrowserView.h"

@interface CASLibraryBrowserView ()
@property (nonatomic,unsafe_unretained) NSViewController* viewController;
@end

@implementation CASLibraryBrowserView

@synthesize viewController = _viewController;

- (void)keyDown:(NSEvent *)theEvent
{
    [self interpretKeyEvents:[NSArray arrayWithObject:theEvent]];
}

- (void)setNextResponder:(NSResponder *)aResponder
{
    if (aResponder && self.viewController && aResponder != self.viewController){
        [self.viewController setNextResponder:aResponder];
        aResponder = self.viewController;
    }
    [super setNextResponder:aResponder];
}

- (void)setViewController:(NSViewController *)viewController
{
    if (viewController != _viewController){
        _viewController = viewController;
        self.nextResponder = self.nextResponder;
    }
}

@end

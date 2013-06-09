//
//  CASConfigureIPMountWindowController.m
//  astrometry-test
//
//  Created by Simon Taylor on 6/8/13.
//  Copyright (c) 2013 Simon Taylor. All rights reserved.
//

#import "CASConfigureIPMountWindowController.h"

@interface CASConfigureIPMountWindowController ()

@end

@implementation CASConfigureIPMountWindowController

- (id)initWithWindow:(NSWindow *)window
{
    self = [super initWithWindow:window];
    if (self) {
        // Initialization code here.
    }
    
    return self;
}

- (void)windowDidLoad
{
    [super windowDidLoad];
    
    // Implement this method to handle any initialization after your window controller's window has been loaded from its nib file.
}

- (IBAction)done:(id)sender {
    [self endSheetWithCode:NSOKButton];
}

@end

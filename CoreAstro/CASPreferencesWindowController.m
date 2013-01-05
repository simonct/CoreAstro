//
//  CASPreferencesController.m
//  CoreAstro
//
//  Created by Simon Taylor on 1/5/13.
//  Copyright (c) 2013 Mako Technology Ltd. All rights reserved.
//

#import "CASPreferencesWindowController.h"

@interface CASPreferencesWindowController ()

@end

@implementation CASPreferencesWindowController

+ (void)initialize
{
    if (self == [CASPreferencesWindowController class]){
        [[NSUserDefaults standardUserDefaults] registerDefaults:@{@"CASDefaultScopeAperture":@(101),@"CASDefaultScopeFNumber":@(5.4)}];
    }
}

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

- (IBAction)close:(id)sender {
    [self close];
}

@end

//
//  SXIOBookmarkWindowController.m
//  SX IO
//
//  Created by Simon Taylor on 09/09/2015.
//  Copyright (c) 2015 Simon Taylor. All rights reserved.
//

#import "SXIOBookmarkWindowController.h"

@interface SXIOBookmarkWindowController ()
@end

@implementation SXIOBookmarkWindowController

- (void)windowDidLoad {
    [super windowDidLoad];
    
    self.bookmarkName = @"Bookmark";
}

- (IBAction)ok:(id)sender {
    
    NSLog(@"self.bookmarkName");
    
    [self endSheetWithCode:NSOKButton];
}

- (IBAction)cancel:(id)sender {
    [self endSheetWithCode:NSCancelButton];
}

@end

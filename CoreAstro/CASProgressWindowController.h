//
//  CASProgressWindowController.h
//  CoreAstro
//
//  Created by Simon Taylor on 11/3/12.
//  Copyright (c) 2012 Mako Technology Ltd. All rights reserved.
//

#import "CASAuxWindowController.h"

@interface CASProgressWindowController : CASAuxWindowController
@property (weak) IBOutlet NSTextField *label;
@property (weak) IBOutlet NSProgressIndicator *progressBar;
- (void)beginSheetModalForWindow:(NSWindow*)window;
- (void)configureWithRange:(NSRange)range label:(NSString*)label;
@end

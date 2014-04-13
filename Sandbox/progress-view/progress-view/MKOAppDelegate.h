//
//  MKOAppDelegate.h
//  progress-view
//
//  Created by Simon Taylor on 11/21/12.
//  Copyright (c) 2012 Simon Taylor. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class CASProgressView;

@interface MKOAppDelegate : NSObject <NSApplicationDelegate>

@property (assign) IBOutlet NSWindow *window;
@property (weak) IBOutlet CASProgressView *progressView;

@end

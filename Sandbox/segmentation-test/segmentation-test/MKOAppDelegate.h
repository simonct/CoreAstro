//
//  MKOAppDelegate.h
//  segmentation-test
//
//  Created by Simon Taylor on 11/11/12.
//  Copyright (c) 2012 Simon Taylor. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface MKOAppDelegate : NSObject <NSApplicationDelegate>

@property (weak) IBOutlet NSProgressIndicator *spinner;
@property (assign) IBOutlet NSWindow *window;
@property (weak) IBOutlet NSImageView *imageView;

- (IBAction)segment:(id)sender;

@end

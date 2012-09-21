//
//  MKOAppDelegate.h
//  gpusb-test
//
//  Created by Simon Taylor on 9/18/12.
//  Copyright (c) 2012 Simon Taylor. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface MKOAppDelegate : NSObject <NSApplicationDelegate>

@property (assign) IBOutlet NSWindow *window;

- (IBAction)pulse:(id)sender;

@end

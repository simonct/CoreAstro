//
//  AppDelegate.h
//  stack-test
//
//  Created by Simon Taylor on 21/11/2012.
//  Copyright (c) 2012 Simon Taylor. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class CASExposuresView;

@interface AppDelegate : NSObject <NSApplicationDelegate>

@property (assign) IBOutlet NSWindow *window;
@property (weak) IBOutlet CASExposuresView *imageView;

@end

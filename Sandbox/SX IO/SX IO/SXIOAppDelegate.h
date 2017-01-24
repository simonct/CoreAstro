//
//  CASAppDelegate.h
//  SX IO
//
//  Created by Simon Taylor on 7/20/13.
//  Copyright (c) 2013 Simon Taylor. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class CASDeviceController;

@interface SXIOAppDelegate : NSObject <NSApplicationDelegate>

- (void)addWindowToWindowMenu:(NSWindowController*)windowController;
- (void)removeWindowFromWindowMenu:(NSWindowController*)windowController;
- (void)updateWindowInWindowMenu:(NSWindowController*)windowController;

- (NSWindowController*)findDeviceWindowController:(CASDeviceController*)controller;

+ (instancetype)sharedInstance;

@end

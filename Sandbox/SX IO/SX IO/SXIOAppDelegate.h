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

- (void)addWindowToMenus:(NSWindowController*)windowController;
- (void)removeWindowFromMenus:(NSWindowController*)windowController;
- (void)updateWindowInMenus:(NSWindowController*)windowController;

- (NSWindowController*)findDeviceWindowController:(CASDeviceController*)controller;

+ (instancetype)sharedInstance;

@end

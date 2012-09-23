//
//  MKOAppDelegate.h
//  guide-test
//
//  Created by Simon Taylor on 9/23/12.
//  Copyright (c) 2012 Simon Taylor. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class GuideImageView;

@interface MKOAppDelegate : NSObject <NSApplicationDelegate>

@property (assign) IBOutlet NSWindow *window;
@property (weak) IBOutlet GuideImageView *imageView;

@end

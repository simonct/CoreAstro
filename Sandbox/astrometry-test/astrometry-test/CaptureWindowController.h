//
//  CaptureWindowController.h
//  astrometry-test
//
//  Created by Simon Taylor on 5/29/15.
//  Copyright (c) 2015 Simon Taylor. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <CoreAstro/CoreAstro.h>

@class CaptureWindowController;

@protocol CaptureWindowControllerDelegate <NSObject>
- (void)captureWindow:(CaptureWindowController*)captureWindow didCapture:(NSData*)exposure;
@end

@interface CaptureWindowController : NSWindowController

@property (strong) CASINDIContainer* container;
@property (weak) id<CaptureWindowControllerDelegate> captureDelegate;

- (void)beginSheet:(NSWindow*)window completionHandler:(void(^)(NSModalResponse))completion;

+ (instancetype)loadWindow;

@end

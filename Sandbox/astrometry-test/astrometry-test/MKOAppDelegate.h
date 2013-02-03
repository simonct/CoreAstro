//
//  MKOAppDelegate.h
//  astrometry-test
//
//  Created by Simon Taylor on 12/24/12.
//  Copyright (c) 2012 Simon Taylor. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class CASPlateSolveImageView;

@interface MKOAppDelegate : NSObject <NSApplicationDelegate>

@property (unsafe_unretained) IBOutlet NSWindow *window;
@property (unsafe_unretained) IBOutlet CASPlateSolveImageView *imageView;
@property (unsafe_unretained) IBOutlet NSProgressIndicator *spinner;
@property (unsafe_unretained) IBOutlet NSButton *solveButton;
@property (unsafe_unretained) IBOutlet NSPanel *outputLogPanel;
@property (unsafe_unretained) IBOutlet NSTextView *outputLogTextView;
@property (unsafe_unretained) IBOutlet NSTextField *solutionRALabel;
@property (unsafe_unretained) IBOutlet NSTextField *solutionDecLabel;
@property (unsafe_unretained) IBOutlet NSTextField *solutionAngleLabel;
@property (weak) IBOutlet NSTextField *pixelScaleLabel;
@property (weak) IBOutlet NSTextField *fieldWidthLabel;
@property (weak) IBOutlet NSTextField *fieldHeightLabel;

- (IBAction)solve:(id)sender;
- (IBAction)showFontPanel:(id)sender;

@end

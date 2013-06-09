//
//  AppDelegate.h
//  phd-client
//
//  Created by Simon Taylor on 29/01/2013.
//  Copyright (c) 2013 Simon Taylor. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface AppDelegate : NSObject <NSApplicationDelegate>

@property (assign) IBOutlet NSWindow *window;

- (IBAction)pause:(id)sender;
- (IBAction)resume:(id)sender;

- (IBAction)move1:(id)sender;
- (IBAction)move2:(id)sender;
- (IBAction)move3:(id)sender;
- (IBAction)move4:(id)sender;
- (IBAction)move5:(id)sender;

- (IBAction)requestDistance:(id)sender;

- (IBAction)autoFindStar:(id)sender;

- (IBAction)setLockPosition:(id)sender;

- (IBAction)filpRACalibration:(id)sender;

- (IBAction)getStatus:(id)sender;

- (IBAction)stop:(id)sender;
- (IBAction)loop:(id)sender;

- (IBAction)startGuiding:(id)sender;

- (IBAction)loopFrameCount:(id)sender;

- (IBAction)clearCalibration:(id)sender;

@end

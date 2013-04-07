//
//  AppDelegate.h
//  eqmac-client
//
//  Created by Simon Taylor on 29/01/2013.
//  Copyright (c) 2013 Simon Taylor. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface AppDelegate : NSObject <NSApplicationDelegate>

@property (assign) IBOutlet NSWindow *window;
@property (weak) IBOutlet NSImageView *connectStatusImage;
@property (weak) IBOutlet NSTextField *connectStatusLabel;
@property (weak) IBOutlet NSTextField *receiveTextLabel;

- (IBAction)connectOrDisconnect:(id)sender;
- (IBAction)send:(id)sender;
- (IBAction)slew:(id)sender;
- (IBAction)halt:(id)sender;

@end

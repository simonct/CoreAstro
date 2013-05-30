//
//  AppDelegate.m
//  phd-client
//
//  Created by Simon Taylor on 29/01/2013.
//  Copyright (c) 2013 Simon Taylor. All rights reserved.
//

#import "AppDelegate.h"
#import "CASPHDClient.h"

@interface AppDelegate ()
@property (nonatomic,strong) CASPHDClient* client;
@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    self.client = [CASPHDClient new];
}

- (IBAction)pause:(id)sender {
    [self.client pause];
}

- (IBAction)resume:(id)sender {
    [self.client resume];
}

- (IBAction)move1:(id)sender {
    [self.client move1];
}

- (IBAction)move2:(id)sender {
    [self.client move2];
}

- (IBAction)move3:(id)sender {
    [self.client move3];
}

- (IBAction)move4:(id)sender {
    [self.client move4];
}

- (IBAction)move5:(id)sender {
    [self.client move5];
}

- (IBAction)requestDistance:(id)sender {
    [self.client requestDistance];
}

- (IBAction)autoFindStar:(id)sender {
    [self.client autoFindStar];
}

- (IBAction)setLockPosition:(id)sender {
//    [self.client setLockPosition];
}

- (IBAction)filpRACalibration:(id)sender {
    [self.client flipRACalibration];
}

- (IBAction)getStatus:(id)sender {
    [self.client getStatus];
}

- (IBAction)stop:(id)sender {
    [self.client stop];
}

- (IBAction)loop:(id)sender {
    [self.client loop];
}

- (IBAction)startGuiding:(id)sender {
    [self.client startGuiding];
}

- (IBAction)loopFrameCount:(id)sender {
    [self.client loopFrameCount];
}

- (IBAction)clearCalibration:(id)sender {
    [self.client clearCalibration];
}

@end

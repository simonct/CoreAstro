//
//  AppDelegate.m
//  phd-client
//
//  Created by Simon Taylor on 29/01/2013.
//  Copyright (c) 2013 Simon Taylor. All rights reserved.
//

#import "AppDelegate.h"
#import "CASPHDClient.h"
#import "CASPHD2Client.h"

@interface AppDelegate ()
@property (nonatomic,strong) CASPHD2Client* client;
@property (assign) NSInteger x, y;
@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    self.client = [CASPHD2Client new];
}

- (void)setNilValueForKey:(NSString *)key
{
    if ([@[@"x",@"y"] containsObject:key]){
        return;
    }
    [super setNilValueForKey:key];
}

- (BOOL)no {
    return NO;
}

- (IBAction)start:(id)sender {
    [self.client guideWithCompletion:^(BOOL success) {
        if (success){
            NSLog(@"Guiding started");
        }
        else {
            NSLog(@"Guiding failed");
        }
    }];
}

- (IBAction)stop:(id)sender {
    [self.client stop];
}

- (IBAction)dither:(id)sender {
    [self.client ditherByPixels:15 inRAOnly:NO completion:^(BOOL success) {
        if (success){
            NSLog(@"Dither complete");
        }
        else {
            NSLog(@"Dither failed");
        }
    }];
}

@end

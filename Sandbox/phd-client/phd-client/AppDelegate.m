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
    if (!self.client){
        NSLog(@"Failed to connect");
    }
}

- (IBAction)resume:(id)sender {
    [self.client resume];
}

@end

//
//  SXIOAppDelegate.m
//  fli-test
//
//  Created by Simon Taylor on 29/11/2013.
//  Copyright (c) 2013 Simon Taylor. All rights reserved.
//

#import "SXIOAppDelegate.h"
#import "FLISDK.h"

@interface SXIOAppDelegate ()
@property (weak) IBOutlet NSTableView *tableView;
@property (weak) IBOutlet NSArrayController *devicesArrayController;
@property (strong) FLISDK* sdk;
@end

@implementation SXIOAppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)notification
{
    self.sdk = [FLISDK new];
    
    __weak __typeof (self) weakSelf = self;
    self.sdk.deviceAdded = ^(NSString* path,CASDevice* device){
        [weakSelf.devicesArrayController addObject:device];
        [device connect:^(NSError* error) {
            NSLog(@"connect: %@",error);
            dispatch_async(dispatch_get_main_queue(), ^{
                [NSApp presentError:error];
            });
        }];
    };
    
    [self.sdk scan];
}

- (void)applicationWillTerminate:(NSNotification *)notification
{
    [self.devicesArrayController.arrangedObjects makeObjectsPerformSelector:@selector(disconnect)];
}

@end

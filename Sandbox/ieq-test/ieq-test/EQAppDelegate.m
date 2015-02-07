//
//  CASAppDelegate.m
//  ieq-test
//
//  Created by Simon Taylor on 1/26/14.
//  Copyright (c) 2014 Simon Taylor. All rights reserved.
//

#import "EQAppDelegate.h"
#import "ORSSerialPort.h"
#import "ORSSerialPortManager.h"
#import "iEQMount.h"
#import "CASMountWindowController.h"

@interface EQAppDelegate ()
@property (nonatomic,weak) ORSSerialPort* selectedSerialPort;
@property (nonatomic,strong) ORSSerialPortManager* serialPortManager;
@property (nonatomic,strong) CASMountWindowController* windowController;
@end

@implementation EQAppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    self.serialPortManager = [ORSSerialPortManager sharedSerialPortManager];
    
    // select the first port if there are any available
    self.selectedSerialPort = [self.serialPortManager.availablePorts firstObject];
}

- (IBAction)connect:(id)sender
{
    if (!self.selectedSerialPort){
        NSLog(@"No selected port");
        return;
    }
    
    if (self.selectedSerialPort.isOpen){
        NSLog(@"Selected port is open");
        return;
    }
    
    self.windowController = [[CASMountWindowController alloc] initWithWindowNibName:@"CASMountWindowController"];
    iEQMount* mount = [[iEQMount alloc] initWithSerialPort:self.selectedSerialPort];
    [self.windowController connectToMount:mount];
}

@end

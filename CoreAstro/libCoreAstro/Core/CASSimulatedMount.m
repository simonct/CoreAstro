//
//  CASSimulatedMount
//  CoreAstro
//
//  Created by Simon Taylor on 17/08/17.
//  Copyright (c) 2017 Simon Taylor. All rights reserved.
//

#import "CASSimulatedMount.h"

@interface CASSimulatedMount ()
@end

@implementation CASSimulatedMount

- (void)dealloc
{
    NSLog(@"[CASSimulatedMount dealloc]");
}

- (NSString*)vendorName
{
    return @"Simulated Mount";
}

- (void)initialiseMount
{
    self.name = [self vendorName];
    
    self.connected = YES;
    
    self.ra = @(180);
    self.dec = @(45);

    self.alt = @(45);
    self.az = @(180);
    
    [self callConnectionCompletion:nil];
}

- (NSViewController*)configurationViewController
{
    return nil;
}

@end

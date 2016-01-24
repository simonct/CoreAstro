//
//  CASMountController.m
//  CoreAstro
//
//  Created by Simon Taylor on 1/9/16.
//  Copyright © 2016 Simon Taylor. All rights reserved.
//

#import "CASMountController.h"
#import "CASCameraController.h"
#import "CASLX200Commands.h"
#import "CASObjectLookup.h"

@interface CASMountController ()
@property (nonatomic,strong) CASMount* mount;
@property (nonatomic,weak) CASCameraController* camera;
@property (strong) NSScriptCommand* slewCommand;
@end

@implementation CASMountController

- (id)initWithMount:(CASMount*)mount
{
    self = [super init];
    if (self){
        self.mount = mount;
    }
    return self;
}

- (void)dealloc
{
    NSLog(@"[CASMountController dealloc]");
}

- (CASDevice*) device
{
    return self.mount;
}

@end

@implementation CASMountController (CASScripting)

static void* kvoContext;

- (NSString*)containerAccessor
{
    return @"mountControllers";
}

- (NSString*)scriptingRightAscension
{
    return [CASLX200Commands highPrecisionRA:self.mount.ra.doubleValue];
}

- (NSString*)scriptingDeclination
{
    return [CASLX200Commands highPrecisionDec:self.mount.dec.doubleValue];
}

- (NSString*)scriptingAltitude
{
    return [CASLX200Commands highPrecisionDec:self.mount.alt.doubleValue];
}

- (NSString*)scriptingAzimuth
{
    return [CASLX200Commands highPrecisionDec:self.mount.az.doubleValue];
}

- (NSNumber*)scriptingSlewing
{
    return @(self.mount.slewing);
}

- (CASCameraController*)scriptingCamera
{
    return self.camera;
}

- (void)setScriptingCamera:(CASCameraController*)cameraController
{
    self.camera = cameraController;
}

- (void)scriptingSlewTo:(NSScriptCommand*)command
{
    // get the object param, look up in simbad, slew to location
    NSString* object = command.arguments[@"object"];
    if (!object.length){
        command.scriptErrorNumber = paramErr;
        command.scriptErrorString = NSLocalizedString(@"You must specify the name of the object to slew to", nil);
        return;
    }
    
    [command suspendExecution];
    
    [[CASObjectLookup new] lookupObject:object withCompletion:^(BOOL success, NSString *objectName, double ra, double dec) {
        if (!success){
            command.scriptErrorNumber = paramErr;
            command.scriptErrorString = [NSString stringWithFormat:NSLocalizedString(@"Couldn't locate the object '%@'", nil),object];
            [command resumeExecutionWithResult:nil];
        }
        else {
            [self.mount startSlewToRA:ra dec:dec completion:^(CASMountSlewError error) {
                if (error != CASMountSlewErrorNone){
                    command.scriptErrorNumber = paramErr;
                    command.scriptErrorString = NSLocalizedString(@"Failed to start slewing to that object. It may be below the local horizon.", nil);
                    [command resumeExecutionWithResult:nil];
                }
                else {
                    // wait until it stops slewing and then resume the command
                    self.slewCommand = command;
                    [self.mount addObserver:self forKeyPath:@"slewing" options:0 context:&kvoContext];
                }
            }];
        }
    }];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if (context == &kvoContext) {
        if ([@"slewing" isEqualToString:keyPath] && object == self.mount){
            if (!self.mount.slewing){
                [self.mount removeObserver:self forKeyPath:@"slewing" context:&kvoContext];
                if (self.slewCommand){
                    [self.slewCommand resumeExecutionWithResult:nil];
                    self.slewCommand = nil;
                }
            }
        }
    }
}

- (void)scriptingStop:(NSScriptCommand*)command
{
    [self.mount halt];
}

@end

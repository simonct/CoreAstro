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

@interface CASMountController ()
@property (nonatomic,strong) CASMount* mount;
@property (nonatomic,weak) CASCameraController* camera;
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
    NSLog(@"scriptingSlewTo");
}

- (void)scriptingStop:(NSScriptCommand*)command
{
    NSLog(@"scriptingStop");
}

@end

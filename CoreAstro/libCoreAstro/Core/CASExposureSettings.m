//
//  CASSequence.m
//  CoreAstro
//
//  Created by Simon Taylor on 1/11/14.
//  Copyright (c) 2014 Mako Technology Ltd. All rights reserved.
//

#import "CASExposureSettings.h"
#import "CASCameraController.h"
#import "CASCCDDevice.h"

@interface CASExposureSettings ()
@property (nonatomic,assign) NSInteger currentCaptureIndex;
@end

@implementation CASExposureSettings

- (id)init
{
    self = [super init];
    if (self) {
        self.exposureDuration = 1;
        self.exposureUnits = 0; // seconds
        self.exposureType = kCASCCDExposureLightType;
        self.captureCount = 1;
        self.binning = 1;
    }
    return self;
}

- (NSInteger) binningIndex
{
    return self.binning - 1;
}

- (void)setBinningIndex:(NSInteger)binningIndex
{
    self.binning = binningIndex + 1;
}

- (void)setNilValueForKey:(NSString *)key
{
    if ([@[@"temperatureLock",@"targetTemperature",@"exposureDuration"] containsObject:key]){
        return;
    }
    [super setNilValueForKey:key];
}

@end

@implementation CASExposureSettings (CASScripting)

- (NSString*)containerAccessor
{
	return @"sequence";
}

- (NSScriptObjectSpecifier*)containerSpecifier
{
	return self.cameraController.objectSpecifier;
}

- (NSScriptClassDescription*)containerDescription
{
	return (NSScriptClassDescription *)[CASCameraController classDescription];
}

- (NSScriptObjectSpecifier*)objectSpecifier
{
    //
    
    NSScriptObjectSpecifier * s = [[NSPropertySpecifier alloc] initWithContainerSpecifier:[self containerSpecifier]
                                                                                             key:[self containerAccessor]];
    return s;

//    NSScriptObjectSpecifier * s = [[NSUniqueIDSpecifier alloc] initWithContainerClassDescription:[self containerDescription]
//                                                       containerSpecifier:[self containerSpecifier]
//                                                                      key:[self containerAccessor]
//                                                                 uniqueID:[self uniqueID]];
//    return s;
}

- (NSNumber*)scriptingSequenceCount
{
    return [NSNumber numberWithInteger:self.captureCount];
}

- (void)setScriptingSequenceCount:(NSNumber*)count
{
    self.captureCount = MIN(10000,MAX(0,[count integerValue]));
}

- (NSNumber*)scriptingStartIndex
{
    NSString* cameraID = self.cameraController.camera.uniqueID;
    if (!cameraID){
        return nil;
    }
    return [[NSUserDefaults standardUserDefaults] objectForKey:[@"SavedImageSequence" stringByAppendingString:cameraID]];
}

- (void)setScriptingStartIndex:(NSNumber*)startIndex
{
    if (!startIndex){
        return;
    }
    NSString* cameraID = self.cameraController.camera.uniqueID;
    if (!cameraID){
        return;
    }
    if (startIndex.integerValue < 1){
        return;
    }
    [[NSUserDefaults standardUserDefaults] setObject:@(startIndex.integerValue - 1) forKey:[@"SavedImageSequence" stringByAppendingString:cameraID]];
}

- (NSNumber*)scriptingSequenceIndex
{
    return [NSNumber numberWithInteger:self.currentCaptureIndex + 1];
}

- (NSNumber*)scriptingInterval
{
    return [NSNumber numberWithInteger:self.exposureInterval];
}

- (void)setScriptingInterval:(NSNumber*)interval
{
    self.exposureInterval = MIN(1000,MAX(0,[interval integerValue]));
}

- (NSNumber*)scriptingDitherPixels
{
    return @(self.ditherPixels);
}

- (void)setScriptingDitherPixels:(NSNumber*)ditherPixels
{
    self.ditherPixels = MIN(100,MAX(0,[ditherPixels floatValue]));
    self.ditherEnabled = (self.ditherPixels > 0);
}

- (NSNumber*)scriptingBinning
{
    return @(self.binning);
}

- (void)setScriptingBinning:(NSNumber*)binning
{
    self.binning = MIN(4,MAX(1,[binning integerValue]));
}

- (NSNumber*)scriptingDuration
{
    return @(self.exposureDuration);
}

- (void)setScriptingDuration:(NSNumber*)duration
{
    self.exposureUnits = 0;
    self.exposureDuration = MAX(0,[duration integerValue]);
}

- (NSNumber*)scriptingTemperatureLock
{
    return @(self.temperatureLock);
}

- (void)setScriptingTemperatureLock:(NSNumber*)temperatureLock
{
    self.temperatureLock = temperatureLock.boolValue;
}

- (NSNumber*)scriptingTargetTemperature
{
    return @(self.targetTemperature);
}

- (void)setScriptingTargetTemperature:(NSNumber*)targetTemperature
{
    self.targetTemperature = targetTemperature.floatValue;
}

@end

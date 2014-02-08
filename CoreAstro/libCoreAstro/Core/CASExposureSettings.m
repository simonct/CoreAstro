//
//  CASSequence.m
//  CoreAstro
//
//  Created by Simon Taylor on 1/11/14.
//  Copyright (c) 2014 Mako Technology Ltd. All rights reserved.
//

#import "CASExposureSettings.h"
#import "CASCameraController.h"

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
    if ([@"exposureDuration" isEqualToString:key]){
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
    self.captureCount = MIN(1000,MAX(0,[count integerValue]));
}

- (NSNumber*)scriptingSequenceIndex
{
    return [NSNumber numberWithInteger:self.currentCaptureIndex + 1];
}

- (NSNumber*)scriptingSequenceInterval
{
    return [NSNumber numberWithInteger:self.exposureInterval];
}

- (void)setScriptingSequenceInterval:(NSNumber*)interval
{
    self.exposureInterval = MIN(1000,MAX(0,[interval integerValue]));
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

@end

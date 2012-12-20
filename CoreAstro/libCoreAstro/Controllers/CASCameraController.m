//
//  CASCameraController.m
//  CoreAstro
//
//  Copyright (c) 2012, Simon Taylor
// 
//  Permission is hereby granted, free of charge, to any person obtaining a copy 
//  of this software and associated documentation files (the "Software"), to deal 
//  in the Software without restriction, including without limitation the rights 
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell 
//  copies of the Software, and to permit persons to whom the Software is furnished 
//  to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in 
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR 
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, 
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL 
//  THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER 
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
//  FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
//  IN THE SOFTWARE.
//

#import "CASCameraController.h"
#import "CASCCDExposureLibrary.h"
#import "CASGuiderController.h"
#import "CASAutoGuider.h"
#import "CASCCDDevice.h"

NSString* const kCASCameraControllerGuideCommandNotification = @"kCASCameraControllerGuideCommandNotification";

@interface CASCameraController ()
@property (nonatomic,assign) BOOL capturing;
@property (nonatomic,strong) CASCCDDevice* camera;
@property (nonatomic) NSTimeInterval continuousNextExposureTime;
@end

@implementation CASCameraController {
    BOOL _cancel:1;
    BOOL _waitingForDevice:1;
}

- (id)initWithCamera:(CASCCDDevice*)camera
{
    self = [super init];
    if (self){
        self.exposure = 1;
        self.exposureUnits = 0; // seconds
        self.camera = camera;
    }
    return self;
}

- (void)connect:(void(^)(NSError*))block
{
    [self.camera connect:^(NSError *error) {
        
        if (error){
            if (block){
                block(error);
            }
        }
        else {
            
            [self.camera flush:^(NSError *error) {
                
                if (block){
                    block(error);
                }
            }];
        }
    }];
}

- (void)disconnect
{
    [self.camera disconnect];
    self.camera = nil;
}

- (void)captureWithBlockImpl:(void(^)(NSError*,CASCCDExposure*))block
{
    void (^endCapture)(NSError*,CASCCDExposure*) = ^(NSError* error,CASCCDExposure* exp){
        
        // remember the last exposure
        self.lastExposure = exp;
        
        // figure out if we need to go round again
        if (!error && (self.continuous || ++self.currentCaptureIndex < self.captureCount) && !_cancel){
            
            void (^scheduleNextCapture)(NSTimeInterval) = ^(NSTimeInterval t) {
                
                self.continuousNextExposureTime = [NSDate timeIntervalSinceReferenceDate] + self.interval; // add on guide pulse duration
                [self performSelector:_cmd withObject:block afterDelay:self.interval inModes:@[NSRunLoopCommonModes]];
            };
            
            if (self.guiding){
                
                // update the guide algorithm with this exposure
                [self.guideAlgorithm updateWithExposure:exp guideCallback:^(NSError *error, CASGuiderDirection direction, NSInteger duration) {
                    
                    // todo; record the guide command against the current exposure
                    
                    if (error){
                        NSLog(@"Guide error: %@",error); // e.g. lost star, etc
                        if (block){
                            block(error,nil);
                        }
                    }
                    else{
                        
                        // post a notification so that the UI can update using both the contents of the notification and the state of the guide algorithm
                        [[NSNotificationCenter defaultCenter] postNotificationName:kCASCameraControllerGuideCommandNotification
                                                                            object:self
                                                                          userInfo:@{@"direction":@(direction),@"@duration":@(duration)}];
                        
                        if (direction == kCASGuiderDirection_None || duration < 1){
                            
                            // nothing to do, figure out the next exposure time
                            scheduleNextCapture([NSDate timeIntervalSinceReferenceDate] + self.interval); // add on guide pulse duration
                        }
                        else{
                            
                            // need a correction, pulse the guider
                            [self.guider pulse:direction duration:duration block:^(NSError *pulseError) {
                                
                                if (pulseError){
                                    NSLog(@"Pulse error: %@",pulseError); // pulse failed, device gone away ?
                                    if (block){
                                        block(pulseError,nil);
                                    }
                                }
                                else {
                                    
                                    // need to wait several seconds before the next exposure...
                                    // have a minimum interval for guide exposures e.g. 10s ?
                                    
                                    // pulse complete, figure out the next exposure time
                                    scheduleNextCapture([NSDate timeIntervalSinceReferenceDate] + self.interval); // add on guide pulse duration
                                }
                            }];
                        }
                    }
                }];
            }
            else {
                
                // not guiding, figure out the next exposure time
                scheduleNextCapture([NSDate timeIntervalSinceReferenceDate] + self.interval);
            }
        }
        else {
            self.capturing = NO;
        }
        self.exposureStart = nil;

        if (block){
            block(error,exp);
        }
    };
        
    self.capturing = YES;
    
    const BOOL saveExposure = !self.continuous;
        
    CASExposeParams exp;
    bzero(&exp, sizeof exp);
    
    const NSInteger xBin = self.binningIndex + 1;
    const NSInteger yBin = self.binningIndex + 1;
    const NSInteger exposureMS = (self.exposureUnits == 0) ? self.exposure * 1000 : self.exposure;
    const CGRect subframe = self.subframe;
    
    if (CGRectIsEmpty(subframe)){
        exp = CASExposeParamsMake(self.camera.sensor.width, self.camera.sensor.height, 0, 0, self.camera.sensor.width, self.camera.sensor.height, xBin, yBin, self.camera.sensor.bitsPerPixel,exposureMS);
    }
    else {
        exp = CASExposeParamsMake(subframe.size.width, subframe.size.height, subframe.origin.x, subframe.origin.y, self.camera.sensor.width, self.camera.sensor.height, xBin, yBin, self.camera.sensor.bitsPerPixel,exposureMS);
    }
    
    self.exposureStart = [NSDate date];
    
    _waitingForDevice = YES;
    
    [self.camera exposeWithParams:exp type:kCASCCDExposureLightType block:^(NSError *error, CASCCDExposure *exposure) {
    
        _waitingForDevice = NO;
        
        if (error){
            endCapture(error,nil);
        }
        else {
            
            exposure.type = kCASCCDExposureLightType; // no, need to feed in from window controller
            
            if (!saveExposure && !_cancel){
                endCapture(error,exposure);
            }
            else{
                
                dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                    
                    [[CASCCDExposureLibrary sharedLibrary] addExposure:exposure save:YES block:^(NSError* saveError,NSURL* url) {
                        
                        dispatch_async(dispatch_get_main_queue(), ^{
                            endCapture(saveError,exposure);
                        });
                    }];
                });
            }
        }
    }];
}

- (void)captureWithBlock:(void(^)(NSError*,CASCCDExposure*))block
{
    if (self.capturing){
        block([NSError errorWithDomain:@"CASCameraController"
                                  code:1
                              userInfo:[NSDictionary dictionaryWithObjectsAndKeys:NSLocalizedFailureReasonErrorKey,@"Can't have multiple capture sessions",nil]],nil);
        return;
    }
    
    _cancel = NO;

    self.currentCaptureIndex = 0;
    
    [self captureWithBlockImpl:block];
}

- (void)cancelCapture
{
    _cancel = YES;
    self.continuous = NO;
    
    if (_waitingForDevice){
        // ask the device to cancel the exposure and wait for it to complete to clear the capturing flag, don't save any resulting exposure
    }
    else {
        // if we're waiting for the next exposure, stop the timer and clear the capturing flag
        self.capturing = NO;
        [NSObject cancelPreviousPerformRequestsWithTarget:self];
    }
}

- (BOOL)waitingForNextCapture
{
    return (self.continuous || (self.captureCount > 1 && self.currentCaptureIndex < self.captureCount));
}

- (void)setGuider:(CASGuiderController*)guider
{
    _guider = guider;
}

- (void)setNilValueForKey:(NSString *)key
{
    if ([@"exposure" isEqualToString:key]){
        return;
    }
    [super setNilValueForKey:key];
}

@end

@implementation CASCameraController (CASScripting)

- (NSString*)containerAccessor
{
	return @"cameraControllers";
}

- (id)scriptingDeviceName
{
    return self.camera.deviceName;
}

- (id)scriptingVendorName
{
    return self.camera.vendorName;
}

- (void)scriptingCapture:(NSScriptCommand*)command
{
    [command performDefaultImplementation];
}

- (NSNumber*)scriptingTemperature
{
    return [NSNumber numberWithFloat:self.camera.temperature];
}

- (void)setScriptingTemperature:(NSNumber*)temperature
{
    self.camera.targetTemperature = [temperature floatValue];
}

- (NSNumber*)scriptingSequenceCount
{
    return [NSNumber numberWithInteger:self.captureCount];
}

- (void)setScriptingSequenceCount:(NSNumber*)count
{
    if (self.capturing){
        [[NSScriptCommand currentCommand] setScriptErrorNumber:-50];
        [[NSScriptCommand currentCommand] setScriptErrorString:NSLocalizedString(@"You can't set the sequence count while the camera is busy", @"Scripting error message")];
        return;
    }
    self.captureCount = MIN(1000,MAX(0,[count integerValue]));
}

- (NSNumber*)scriptingSequenceIndex
{
    if (!self.capturing){
        return [NSNumber numberWithInteger:0];
    }
    return [NSNumber numberWithInteger:self.currentCaptureIndex + 1];
}

- (NSNumber*)scriptingIsCapturing
{
    return [NSNumber numberWithBool:self.capturing];
}

- (NSNumber*)scriptingSequenceInterval
{
    return [NSNumber numberWithInteger:self.interval];
}

- (void)setScriptingSequenceInterval:(NSNumber*)interval
{
    if (self.capturing){
        [[NSScriptCommand currentCommand] setScriptErrorNumber:-50];
        [[NSScriptCommand currentCommand] setScriptErrorString:NSLocalizedString(@"You can't set the sequence interval while the camera is busy", @"Scripting error message")];
        return;
    }
    self.interval = MIN(1000,MAX(0,[interval integerValue]));
}

@end

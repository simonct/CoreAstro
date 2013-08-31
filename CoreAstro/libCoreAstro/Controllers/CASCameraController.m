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
#import "CASMovieExporter.h"

NSString* const kCASCameraControllerGuideErrorNotification = @"kCASCameraControllerGuideErrorNotification";
NSString* const kCASCameraControllerGuideCommandNotification = @"kCASCameraControllerGuideCommandNotification";

@interface CASCameraController ()
@property (nonatomic,assign) BOOL capturing;
@property (nonatomic,strong) CASCCDDevice* camera;
@property (nonatomic) NSTimeInterval continuousNextExposureTime;
@property (nonatomic) CASCameraControllerState state;
@property (nonatomic) float progress;
@end

@implementation CASCameraController {
    BOOL _cancelled:1;
    BOOL _waitingForDevice:1;
    CASExposeParams _expParams;
}

- (id)initWithCamera:(CASCCDDevice*)camera
{
    self = [super init];
    if (self){
        self.exposure = 1;
        self.exposureUnits = 0; // seconds
        self.camera = camera;
        self.temperatureLock = YES;
        self.exposureType = kCASCCDExposureLightType;
        self.autoSave = YES;
        self.captureCount = 1;
    }
    return self;
}

- (void)connect:(void(^)(NSError*))block
{
    [self.camera connect:^(NSError *error) {
        
        if (block){
            block(error);
        }
    }];
}

- (void)disconnect
{
    [self.camera disconnect];
    self.camera = nil;
}

- (void)setState:(CASCameraControllerState)state
{
    if (state != _state){
        _state = state;
//        NSLog(@"Changed state to %ld",_state);
    }
}

- (void)updateProgress
{
    if (self.state == CASCameraControllerStateNone || self.state == CASCameraControllerStateWaitingForTemperature){
        self.progress = 0;
        return;
    }
    
    if (self.state == CASCameraControllerStateExposing){
        
        // progress counts up from 0 to 1
        const NSTimeInterval interval = [NSDate timeIntervalSinceReferenceDate] - [self.exposureStart timeIntervalSinceReferenceDate];
        self.progress = MIN(1,(interval * 1000.0)/(double)_expParams.ms);
//        NSLog(@"Exposing progress: %f",self.progress);
    }
    else if (self.state == CASCameraControllerStateWaitingForNextExposure){
        
        // progress counts down from 1 to 0
        const NSTimeInterval interval = self.continuousNextExposureTime - [NSDate timeIntervalSinceReferenceDate];
        self.progress = MAX(0,interval/self.exposureInterval);
//        NSLog(@"Waiting progress: %f",self.progress);
    }

    const NSTimeInterval updateInterval = MAX(0.25,_expParams.ms/1000.0/100.0); // reduce further on battery ?
    [self performSelector:_cmd withObject:nil afterDelay:updateInterval];
}

- (void)captureWithBlockImpl:(void(^)(NSError*,CASCCDExposure*))block
{
    void (^scheduleNextCapture)(NSTimeInterval) = ^(NSTimeInterval t) {
        
        self.continuousNextExposureTime = [NSDate timeIntervalSinceReferenceDate] + t;
        [self performSelector:_cmd withObject:block afterDelay:t inModes:@[NSRunLoopCommonModes]];
    };
    
    void (^endCapture)(NSError*,CASCCDExposure*) = ^(NSError* error,CASCCDExposure* exp){
        
        // remember the last exposure
        self.lastExposure = exp;
        
        // figure out if we need to go round again
        if (!error && !_cancelled && (self.continuous || ++self.currentCaptureIndex < self.captureCount) ){
            
            self.state = CASCameraControllerStateWaitingForNextExposure;

            if (!self.guider || !self.guideAlgorithm){
                
                // not guiding, figure out the next exposure time
                scheduleNextCapture(self.exposureInterval);
            }
            else {
                
                // update the guide algorithm with this exposure
                [self.guideAlgorithm updateWithExposure:exp guideCallback:^(NSError *error, CASGuiderDirection direction, NSInteger duration) {
                    
                    // todo; record the guide command against the current exposure
                    
                    if (error){
                        
                        NSLog(@"Guide error: %@",error); // e.g. lost star, etc
                        
                        [[NSNotificationCenter defaultCenter] postNotificationName:kCASCameraControllerGuideErrorNotification
                                                                            object:self
                                                                          userInfo:@{@"error":error}];
                    }
                    else{
                        
                        // post a notification so that the UI can update using both the contents of the notification and the state of the guide algorithm
                        [[NSNotificationCenter defaultCenter] postNotificationName:kCASCameraControllerGuideCommandNotification
                                                                            object:self
                                                                          userInfo:@{@"direction":@(direction),@"@duration":@(duration)}];
                        
                        const NSTimeInterval nextExposureTimeInterval = MAX(self.exposureInterval,ceil((float)duration/1000.0));
                        
                        if (direction == kCASGuiderDirection_None || duration < 1){
                            
                            // nothing to do, figure out the next exposure time
                            scheduleNextCapture(nextExposureTimeInterval);
                        }
                        else{
                            
                            // need a correction, pulse the guider (assuming this returns immediately)
                            [self.guider pulse:direction duration:duration block:^(NSError *pulseError) {
                                
                                if (pulseError){
                                    
                                    NSLog(@"Pulse error: %@",pulseError); // pulse failed, device gone away ?

                                    [[NSNotificationCenter defaultCenter] postNotificationName:kCASCameraControllerGuideErrorNotification
                                                                                        object:self
                                                                                      userInfo:@{@"pulseError":error}];
                                }
                                else {
                                    
                                    // need to wait several seconds before the next exposure...
                                    // have a minimum interval for guide exposures e.g. 10s ?
                                    
                                    // pulse complete, figure out the next exposure time
                                    scheduleNextCapture(nextExposureTimeInterval);
                                }
                            }];
                        }
                    }
                }];                
            }
        }
        else {
            
            self.capturing = NO;
            self.state = CASCameraControllerStateNone;
        }
        self.exposureStart = nil;

        if (block){
            block(error,exp);
        }
    };
    
    // check cancel flag
    if (_cancelled){
        return;
    }
    
    self.capturing = YES;

    // if the temperature lock is on, check the camera's cooled down enough
    if (self.temperatureLock && self.camera.hasCooler){
        
        const CGFloat temperatureLatitude = 0.5;
        const NSInteger temperatureWaitInterval = 5;

        const CGFloat temperature = self.camera.temperature;
        const CGFloat targetTemperature = self.camera.targetTemperature;
        if (MIN(temperature,targetTemperature) == targetTemperature && fabs(targetTemperature - temperature) > temperatureLatitude){
            
            self.state = CASCameraControllerStateWaitingForTemperature;

            // todo; give up and alert user if we've waited in excess of some limit ?
            // todo; min capture interval in temp lock mode to allow temp commands to run

            NSLog(@"Camera temperature of %.1f is above target temperature of %.1f, waiting %ld seconds...",temperature,targetTemperature,temperatureWaitInterval);
            scheduleNextCapture(temperatureWaitInterval);
            return;
        }
        else {
            
            NSLog(@"Camera temperature of %.1f relative to target temperature of %.1f, capturing...",temperature,targetTemperature);
        }
    }
    
    self.state = CASCameraControllerStateExposing;
    
    const BOOL saveExposure = !self.continuous;
        
    bzero(&_expParams, sizeof _expParams);
    
    const NSInteger xBin = self.binningIndex + 1;
    const NSInteger yBin = self.binningIndex + 1;
    const NSInteger exposureMS = (self.exposureUnits == 0) ? self.exposure * 1000 : self.exposure;
    const CGRect subframe = self.subframe;
    
    if (CGRectIsEmpty(subframe)){
        _expParams = CASExposeParamsMake(self.camera.sensor.width, self.camera.sensor.height, 0, 0, self.camera.sensor.width, self.camera.sensor.height, xBin, yBin, self.camera.sensor.bitsPerPixel,exposureMS);
    }
    else {
        _expParams = CASExposeParamsMake(subframe.size.width, subframe.size.height, subframe.origin.x, subframe.origin.y, self.camera.sensor.width, self.camera.sensor.height, xBin, yBin, self.camera.sensor.bitsPerPixel,exposureMS);
    }
    
    self.exposureStart = [NSDate date];
    
    self.progress = 0;
    [self updateProgress];

    _waitingForDevice = YES;
    
    [self.camera exposeWithParams:_expParams type:self.exposureType block:^(NSError *error, CASCCDExposure *exposure) {
    
        self.progress = 1;

        _waitingForDevice = NO;
        
        if (error){
            endCapture(error,nil);
        }
        else {
            
            // no exposure means it was cancelled
            if (!exposure){
                endCapture(nil,nil);
            }
            else {
                
                if (self.movieExporter){
                    NSError* movieError = nil;
                    // todo; option to match histograms across exposures
                    if (![self.movieExporter addExposure:exposure error:&movieError]){
                        self.movieExporter = nil;
                        dispatch_async(dispatch_get_main_queue(), ^{
                            [NSApp presentError:movieError]; // no; might be running in something with no NSApp instance
                        });
                    }
                }
                
                exposure.type = self.exposureType;
                
                if (!saveExposure && !_cancelled){
                    endCapture(error,exposure);
                }
                else{
                    
                    if (!self.autoSave){
                        
                        endCapture(nil,exposure);
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
    
    _cancelled = NO;

    self.currentCaptureIndex = 0;
    
    [self captureWithBlockImpl:block];
}

- (void)cancelCapture
{
    _cancelled = YES;
    self.continuous = NO;
    
    [self.camera cancelExposure];
    
    if (_waitingForDevice){
        // ask the device to cancel the exposure and wait for it to complete to clear the capturing flag, don't save any resulting exposure
    }
    else {
        // if we're waiting for the next exposure, stop the timer and clear the capturing flag
        self.capturing = NO;
        self.state = CASCameraControllerStateNone;
        [NSObject cancelPreviousPerformRequestsWithTarget:self];
    }
    
    if (self.movieExporter){
        [self.movieExporter complete];
        self.movieExporter = nil;
    }
}

- (BOOL) cancelled
{
    return _cancelled;
}

- (BOOL)waitingForNextCapture
{
    return (self.state == CASCameraControllerStateWaitingForNextExposure);
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
    return [NSNumber numberWithInteger:self.exposureInterval];
}

- (void)setScriptingSequenceInterval:(NSNumber*)interval
{
    if (self.capturing){
        [[NSScriptCommand currentCommand] setScriptErrorNumber:-50];
        [[NSScriptCommand currentCommand] setScriptErrorString:NSLocalizedString(@"You can't set the sequence interval while the camera is busy", @"Scripting error message")];
        return;
    }
    self.exposureInterval = MIN(1000,MAX(0,[interval integerValue]));
}

@end

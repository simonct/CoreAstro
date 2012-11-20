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

NSString* const kCASCameraControllerGuideCommandNotification = @"kCASCameraControllerGuideCommandNotification";

@interface CASCameraController ()
@property (nonatomic,assign) BOOL capturing;
@property (nonatomic,strong) CASCCDDevice* camera;
@property (nonatomic) NSTimeInterval continuousNextExposureTime;
@end

@implementation CASCameraController

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
        
        if (!error && (self.continuous || ++self.currentCaptureIndex < self.captureCount)){
            
            void (^scheduleNextCapture)(NSTimeInterval) = ^(NSTimeInterval t) {
                
                self.continuousNextExposureTime = [NSDate timeIntervalSinceReferenceDate] + self.interval; // add on guide pulse duration
                [self performSelector:_cmd withObject:block afterDelay:self.interval];
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
                        
                        // post a notification
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
                scheduleNextCapture([NSDate timeIntervalSinceReferenceDate] + self.interval); // add on guide pulse duration
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
    
    [self.camera exposeWithParams:exp block:^(NSError *error, CASCCDExposure *exposure) {
        
        if (error){
            endCapture(error,nil);
        }
        else {
            
            exposure.type = kCASCCDExposureLightType;
            
            if (!saveExposure){
                endCapture(error,exposure);
            }
            else{
                
                [[CASCCDExposureLibrary sharedLibrary] addExposure:exposure save:YES block:^(NSError* saveError,NSURL* url) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        endCapture(saveError,exposure);
                    });
                }];
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
    
    self.currentCaptureIndex = 0;
    
    [self captureWithBlockImpl:block];
}

- (void)setContinuous:(BOOL)continuous
{
    _continuous = continuous;
    if (!_continuous){
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

@end

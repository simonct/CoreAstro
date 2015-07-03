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
#import "CASFilterWheelController.h"
#import "CASAutoGuider.h"
#import "CASCCDDevice.h"
#import "CASClassDefaults.h"
#import "CASPHD2Client.h"
#import "CASDeviceManager.h"

@interface CASExposureSettings ()
@property (nonatomic,assign) NSInteger currentCaptureIndex; // give the camera controller privileged access to this property
@end

NSString* const kCASCameraControllerExposureStartedNotification = @"kCASCameraControllerExposureStartedNotification";
NSString* const kCASCameraControllerExposureCompletedNotification = @"kCASCameraControllerExposureCompletedNotification";

NSString* const kCASCameraControllerGuideErrorNotification = @"kCASCameraControllerGuideErrorNotification";
NSString* const kCASCameraControllerGuideCommandNotification = @"kCASCameraControllerGuideCommandNotification";

@interface CASCameraController ()
@property (nonatomic,assign) BOOL capturing;
@property (nonatomic,strong) CASCCDDevice* camera;
@property (nonatomic) NSTimeInterval continuousNextExposureTime;
@property (nonatomic) CASCameraControllerState state;
@property (nonatomic) float progress;
@property (nonatomic,strong) CASExposureSettings* settings;
//@property (nonatomic,strong) CASPHD2Client* phd2Client; // todo; guide/dither interface ?
@property (nonatomic,readonly) NSArray* slaves;
@end

@implementation CASCameraController {
    BOOL _cancelled:1;
    BOOL _waitingForDevice:1;
    CASExposeParams _expParams;
    NSMutableArray* _settingsStack;
}

- (id)initWithCamera:(CASCCDDevice*)camera
{
    self = [super init];
    if (self){
        self.camera = camera;
        self.temperatureLock = YES;
        self.settings = [CASExposureSettings new];
        self.settings.cameraController = self;
        [self registerDeviceDefaults];
    }
    return self;
}

- (void)dealloc
{
    [self unregisterDeviceDefaults];
}

- (CASDevice*) device
{
    return self.camera;
}

- (NSArray*)deviceDefaultsKeys
{
    return @[@"targetTemperature",@"temperatureLock",@"settings.continuous",@"settings.binning",@"settings.exposureDuration",@"settings.exposureUnits",@"settings.exposureInterval",@"settings.ditherEnabled",@"settings.ditherPixels",@"settings.startGuiding"];
}

- (void)registerDeviceDefaults
{
    NSString* deviceName = self.camera.deviceName;
    if (deviceName){
        [[CASDeviceDefaults defaultsForClassname:deviceName] registerKeys:self.deviceDefaultsKeys ofInstance:self];
    }
}

- (void)unregisterDeviceDefaults
{
    NSString* deviceName = self.camera.deviceName;
    if (deviceName){
        [[CASDeviceDefaults defaultsForClassname:deviceName] unregisterKeys:self.deviceDefaultsKeys ofInstance:self];
    }
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

- (void)setRole:(CASCameraControllerRole)role
{
    NSAssert(!self.capturing,@"Can't set role while capturing");
    _role = role;
}

- (NSArray*)slaves
{
    if (self.role == CASCameraControllerRoleMaster){
        // return all slave camera controllers know to the device manager (this limits us to a single master per-process but that's probably fine for now)
        return [[CASDeviceManager sharedManager].cameraControllers filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(CASCameraController* evaluatedObject, NSDictionary *bindings) {
            return (evaluatedObject.role == CASCameraControllerRoleSlave);
        }]];
    }
    return nil;
}

- (void)updateProgress
{
    if (self.state == CASCameraControllerStateNone ||
        self.state == CASCameraControllerStateWaitingForTemperature ||
        self.state == CASCameraControllerStateWaitingForGuider){
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
        self.progress = MAX(0,interval/self.settings.exposureInterval);
//        NSLog(@"Waiting progress: %f",self.progress);
    }

    const NSTimeInterval updateInterval = MAX(0.25,_expParams.ms/1000.0/100.0); // reduce further on battery ?
    [self performSelector:_cmd withObject:nil afterDelay:updateInterval];
}

- (void)postLocalNotificationWithTitle:(NSString*)title subtitle:(NSString*)subtitle
{
    NSUserNotification* note = [[NSUserNotification alloc] init];
    note.title = title;
    note.subtitle = subtitle;
    note.soundName = NSUserNotificationDefaultSoundName;
    [[NSUserNotificationCenter defaultUserNotificationCenter] deliverNotification:note];
}

- (NSError*)errorWithCode:(NSInteger)code message:(NSString*)message recovery:(NSString*)recovery
{
    NSMutableDictionary* errorDict = [NSMutableDictionary dictionaryWithCapacity:2];
    if (message){
        errorDict[NSLocalizedDescriptionKey] = message;
    }
    if (recovery){
        errorDict[NSLocalizedRecoverySuggestionErrorKey] = recovery;
    }
    return [NSError errorWithDomain:@"CASCameraController" code:code userInfo:errorDict];
}

- (NSError*)errorWithCode:(NSInteger)code message:(NSString*)message
{
    return [self errorWithCode:code message:message recovery:nil];
}

- (void)captureWithBlockImpl:(void(^)(NSError*,CASCCDExposure*))block
{
    void (^scheduleNextCapture)(NSTimeInterval) = ^(NSTimeInterval t) {
        
        self.continuousNextExposureTime = [NSDate timeIntervalSinceReferenceDate] + t;
        [self performSelector:_cmd withObject:block afterDelay:t inModes:@[NSRunLoopCommonModes]];
    };
    
    // todo; move most of this into a sequence class ?
    
    void (^endCapture)(NSError*,CASCCDExposure*) = ^(NSError* error,CASCCDExposure* exp){
        
        // remember the last exposure
        self.lastExposure = exp;
        
        // figure out if we need to go round again
        if (!error && !_cancelled && (self.settings.continuous || ++self.settings.currentCaptureIndex < self.settings.captureCount) ){
            
            self.state = CASCameraControllerStateWaitingForNextExposure;

            if (!self.guider || !self.guideAlgorithm){
                
                // not guiding, figure out the next exposure time
                scheduleNextCapture(self.settings.exposureInterval);
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
                        
                        const NSTimeInterval nextExposureTimeInterval = MAX(self.settings.exposureInterval,ceil((float)duration/1000.0));
                        
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
    
    void (^startExposure)() = ^(){
                
        self.state = CASCameraControllerStateExposing;
        
        const BOOL saveExposure = !self.settings.continuous;
        
        bzero(&_expParams, sizeof _expParams);
        
        const NSInteger xBin = self.settings.binning;
        const NSInteger yBin = self.settings.binning;
        const NSInteger exposureMS = (self.settings.exposureUnits == 0) ? self.settings.exposureDuration * 1000 : self.settings.exposureDuration;
        const CGRect subframe = self.settings.subframe;
        
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
        
        NSString* filterName = [self.filterWheel.currentFilterName copy];

        if (filterName){
            NSLog(@"Starting exposure of %ldms, binning %ld, filter '%@'",_expParams.ms,_expParams.bin.width,filterName);
        }
        else {
            NSLog(@"Starting exposure of %ldms, binning %ld",_expParams.ms,_expParams.bin.width);
        }
        [[NSNotificationCenter defaultCenter] postNotificationName:kCASCameraControllerExposureStartedNotification object:self];
        // todo; call delegate to inform an exposure will start.
        // could figure out how long until a flip and modify the exposure time so that
        // the flip doesn't happen in the middle of the exposure
        
        [self.camera exposeWithParams:_expParams type:self.settings.exposureType block:^(NSError *error, CASCCDExposure *exposure) {
            
            self.progress = 1;
            
            _waitingForDevice = NO;
            
            exposure.type = self.settings.exposureType;
            if (filterName){
                exposure.filters = @[filterName];
            }
            
            // send the exposure to the sink
            @try {
                [self.sink cameraController:self didCompleteExposure:exposure error:error];
            }
            @catch (NSException *exception) {
                NSLog(@"*** Exception calling capture sink: %@",exception);
            }
            
            // figure out if we need to go round again or stop here
            if (error){
                endCapture(error,nil);
            }
            else {
                
                // no exposure means it was cancelled
                if (!exposure){
                    endCapture(nil,nil);
                }
                else {
                    
                    if (!saveExposure && !_cancelled){
                        endCapture(error,exposure);
                    }
                    else{
                        endCapture(nil,exposure);
                    }
                }
            }
        }];
    };
    
    switch (self.role) {
        case CASCameraControllerRoleMaster:{
            // wait for slaves to complete the proceed with default behaviour
        }
            break;
        case CASCameraControllerRoleSlave:{
            // do not dither, wait for -captureWithRole: to be called
        }
            break;
        default:{
            // dither if requested and we're not in continuous capture or on the first exposure of a sequence
            if (self.settings.continuous || !self.settings.ditherEnabled || self.settings.ditherPixels < 1 || self.settings.currentCaptureIndex == 0){
                startExposure();
            }
            else{
                
                self.state = CASCameraControllerStateDithering;
                
                [self.phd2Client ditherByPixels:self.settings.ditherPixels inRAOnly:NO completion:^(BOOL success) {
                    if (success){
                        NSLog(@"Dither of %.1f pixels complete",self.settings.ditherPixels);
                    }
                    else {
                        NSLog(@"*** Dither failed"); // an alert might be too intrusive - need a sequence log this can go into perhaps plus a non-blocking ui feature e.g. log window
                        [self postLocalNotificationWithTitle:NSLocalizedString(@"Dither failed", @"Notification title") subtitle:NSLocalizedString(@"Check PHD2 is guiding successfully", @"Notification subtitle")];
                    }
                    if (!_cancelled){
                        startExposure(); // expose anyway as long as we haven't been cancelled
                    }
                }];
            }
        }
            break;
    }
}

- (void)captureWithBlock:(void(^)(NSError*,CASCCDExposure*))block
{
    if (self.capturing){
        block([self errorWithCode:1 message:@"Can't have multiple capture sessions"],nil);
        return;
    }
    
    if (self.filterWheel.filterWheel.moving){
        block([self errorWithCode:2 message:@"The associated filter wheel is moving"],nil);
        return;
    }

    _cancelled = NO;

    self.settings.currentCaptureIndex = 0;
    
    void (^startCapture)() = ^{
        
        // todo; check focus - again, something better handled in a capture co-ordinator
        
        __block id activity;
        NSProcessInfo* proc = [NSProcessInfo processInfo];
        if ([proc respondsToSelector:@selector(beginActivityWithOptions:reason:)]){
            const NSActivityOptions options = NSActivityIdleSystemSleepDisabled|NSActivitySuddenTerminationDisabled|NSActivityAutomaticTerminationDisabled|NSActivityUserInitiated;
            activity = [proc beginActivityWithOptions:options reason:@"Capturing exposures"];
        }
        
        [self captureWithBlockImpl:^(NSError *error, CASCCDExposure *exposure) {
            
            NSDictionary* userInfo;
            if (error){
                userInfo = @{@"error":error};
            }
            [[NSNotificationCenter defaultCenter] postNotificationName:kCASCameraControllerExposureCompletedNotification object:self userInfo:userInfo];

            if (block){
                block(error,exposure);
            }
            if (activity){
                [proc endActivity:activity];
                activity = nil;
            }
        }];
    };
    
    // todo; always attempt to connect to phd2, only fail if we can't connect and had a specific thing to do e.g. dither, auto-start
    
    // todo; dithering is something that probably belongs in a capture co-ordinator class rather than the actual camera controller
    if (self.settings.ditherEnabled || self.settings.startGuiding){  // make a read-only property
        self.phd2Client = [CASPHD2Client new];
    }
    else {
        self.phd2Client = nil; // this is probably happening during sync captures
    }
    
    if (!self.phd2Client){
        startCapture();
    }
    else {
        
        self.capturing = YES;
        self.state = CASCameraControllerStateWaitingForGuider;

        // not in continuous mode ?
        
        // connect to PHD2 and start guiding before kicking off the capture
        [self.phd2Client connectWithCompletion:^{
            
            if (!self.phd2Client.connected){
                
                self.capturing = NO;
                self.state = CASCameraControllerStateNone;

                NSString* const message = @"PHD2 connection failed";
                NSString* const recovery = NSLocalizedString(@"Check PHD2 is running and Tools->Enable Server is on", @"Notification subtitle");
                [self postLocalNotificationWithTitle:NSLocalizedString(message, @"Notification title") subtitle:recovery];
                if (block){
                    block([self errorWithCode:3 message:message recovery:recovery],nil);
                }
            }
            else {
                
                if (!self.cancelled){
                    
                    if (self.phd2Client.guiding || !self.settings.startGuiding){
                        startCapture();
                    }
                    else {
                        
                        [self.phd2Client guideWithCompletion:^(BOOL guiding) {
                            
                            if (!self.cancelled){
                                
                                if (!guiding){
                                    
                                    self.capturing = NO;
                                    self.state = CASCameraControllerStateNone;

                                    NSString* const message = NSLocalizedString(@"Looks like PHD2 failed to start guiding", @"Notification subtitle");
                                    NSString* const recovery = NSLocalizedString(@"Check all equipment is connected in PHD2 and that it can aquire a guide star", @"Notification subtitle");
                                    [self postLocalNotificationWithTitle:NSLocalizedString(@"Guiding failed", @"Notification title") subtitle:NSLocalizedString(@"Looks like PHD2 failed to start guiding", @"Notification subtitle")];
                                    if (block){
                                        block([self errorWithCode:4 message:message recovery:recovery],nil);
                                    }
                                }
                                else {
                                    startCapture();
                                }
                            }
                        }];
                    }
                }
            }
        }];
    }
}

- (void)captureWithRole:(CASCameraControllerRole)role block:(void(^)(NSError*,CASCCDExposure*))block
{
    NSParameterAssert(role != CASCameraControllerRoleNone);
    
    self.role = role;

    self.settings.continuous = NO; // continuous is inappropriate for either role
    
    [self captureWithBlock:block];
}

- (void)cancelCapture
{
    if (_cancelled){
        return;
    }
    
    _cancelled = YES;
    self.settings.continuous = NO;
    
    // cancel any pending dither
    [self.phd2Client cancel];
    
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
}

- (BOOL) cancelled
{
    return _cancelled;
}

- (void)setGuider:(CASGuiderController*)guider
{
    _guider = guider;
}

- (CGFloat)targetTemperature
{
    return self.camera.targetTemperature;
}

- (void)setTargetTemperature:(CGFloat)targetTemperature
{
    self.camera.targetTemperature = targetTemperature;
}

- (void)setNilValueForKey:(NSString *)key
{
    if ([@"exposure" isEqualToString:key]){
        return;
    }
    [super setNilValueForKey:key];
}

- (void)pushSettings:(CASExposureSettings*)settings
{
    // todo; change to just -pushSettings which also pushes other camera state not in the settings object e.g. temp lock, etc
    // which will save us saving this in external flags
    
    NSParameterAssert(settings);
    
    if (!_settingsStack){
        _settingsStack = [NSMutableArray arrayWithCapacity:3];
    }
    [_settingsStack addObject:self.settings];
    self.settings = settings; // does this trigger kvo ?
}

- (void)popSettings
{
    NSParameterAssert(_settingsStack);
    
    self.settings = [_settingsStack lastObject];  // does this trigger kvo ?
    [_settingsStack removeLastObject];
    
    if (!self.settings){
        NSLog(@"Settings nil after popping the stack !");
    }
}

- (CGSize)arcsecsPerPixelForFocalLength:(float)focalLength
{
    NSParameterAssert(focalLength > 0);
    
    const NSInteger binning = self.settings.binning;
    const CGSize pixelSize = self.camera.sensor.pixelSize;
    const CGSize size = {
        .width = binning*(206.3*pixelSize.width/focalLength),
        .height = binning*(206.3*pixelSize.height/focalLength)
    };
    return size;
}

- (CGSize)fieldSizeForFocalLength:(float)focalLength
{
    NSParameterAssert(focalLength > 0);
    
    const CGSize sensorSize = self.camera.sensor.sensorSize;
    const CGSize size = {
        .width = 3438*sensorSize.width/focalLength/60.0,
        .height = 3438*sensorSize.height/focalLength/60.0
    };
    return size;
}

@end

@implementation CASCameraController (CASScripting)

- (NSString*)containerAccessor
{
	return @"cameraControllers";
}

- (id)scriptingSequence
{
    return self.settings;
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

- (NSNumber*)scriptingIsCapturing
{
    return [NSNumber numberWithBool:self.capturing];
}

// todo; for now leave these settings on the camera and route through to the settings object but may want to revist that

- (NSNumber*)scriptingSequenceCount
{
    return self.settings.scriptingSequenceCount;
}

- (void)setScriptingSequenceCount:(NSNumber*)count
{
    self.settings.scriptingSequenceCount = count;
}

- (NSNumber*)scriptingSequenceIndex
{
    return self.settings.scriptingSequenceIndex;
}

- (NSNumber*)scriptingInterval
{
    return self.settings.scriptingInterval;
}

- (void)setScriptingInterval:(NSNumber*)interval
{
    self.settings.scriptingInterval = interval;
}

- (NSNumber*)scriptingDitherPixels
{
    return self.settings.scriptingDitherPixels;
}

- (void)setScriptingDitherPixels:(NSNumber*)ditherPixels
{
    self.settings.scriptingDitherPixels = ditherPixels;
}

- (NSNumber*)scriptingBinning
{
    return self.settings.scriptingBinning;
}

- (void)setScriptingBinning:(NSNumber*)binning
{
    self.settings.scriptingBinning = binning;
}

- (NSNumber*)scriptingDuration
{
    return self.settings.scriptingDuration;
}

- (void)setScriptingDuration:(NSNumber*)duration
{
    self.settings.scriptingDuration = duration;
}

@end

@implementation CASCameraController (CASCCDExposure)

- (void)updateSettingsWithExposure:(CASCCDExposure*)exposure
{
    if (exposure.exposureMS < 1000){
        self.settings.exposureDuration = exposure.exposureMS;
        self.settings.exposureUnits = CASExposureDurationMilliseconds;
    }
    else {
        self.settings.exposureDuration = exposure.exposureMS/1000;
        self.settings.exposureUnits = CASExposureDurationSeconds;
    }
    
    if ([self.camera.binningModes containsObject:@(exposure.params.bin.width)]){
        self.settings.binning = exposure.params.bin.width;
    }
    
    if (self.camera.hasCooler){
        NSNumber* setPoint = [exposure valueForKeyPath:@"meta.temperature.setpoint"];
        if (setPoint){
            self.targetTemperature = setPoint.integerValue;
            self.temperatureLock = YES;
        }
        else {
            self.temperatureLock = NO;
        }
    }
    
    // filter, subframe ?
}

@end


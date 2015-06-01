//
//  CASMountSlewController.m
//  astrometry-test
//
//  Created by Simon Taylor on 24/03/2015.
//  Copyright (c) 2015 Simon Taylor. All rights reserved.
//

#import "CASMountSynchroniser.h"

@interface CASMountSynchroniser ()
@property BOOL solving;
@property float separation;
@property (strong) NSError* error;
@property (nonatomic,copy) NSString* status;
@property (strong) CASPlateSolver* plateSolver;
@end

@implementation CASMountSynchroniser {
    int _syncCount;
    float _raInDegrees,_decInDegrees;
    BOOL _pushedSettings;
    BOOL _saveTemperatureLock;
    id<CASCameraControllerSink> _savedSink;
}

static void* kvoContext;

+ (void)initialize
{
    [[NSUserDefaults standardUserDefaults] registerDefaults:@{@"CASMountSlewControllerBinning":@(4),
                                                              @"CASMountSlewControllerDuration":@(5),
                                                              @"CASMountSlewControllerConvergence":@(0.02),
                                                              @"CASMountSlewControllerSearchRadius":@(5)}];
}

- (void)handleMountFlipCompletedWithRA:(double)raInDegrees dec:(double)decInDegrees
{
    NSParameterAssert(self.mount.connected);
    NSParameterAssert(self.cameraController);
    NSParameterAssert(raInDegrees >= 0 && raInDegrees <= 360);
    NSParameterAssert(decInDegrees >= -90 && decInDegrees <= 90);

    self.solving = YES;

    _syncCount = 0;
    _raInDegrees = raInDegrees;
    _decInDegrees = decInDegrees;

    // stop tracking
    [self.mount stopTracking];
    
    // capture and solve to get current position
    [self captureAndSolveWithCompletion:^(NSError* error, double actualRA, double actualDec) {
        
        if (error){
            [self completeWithError:error];
        }
        else {
            
            // sync to current position
            [self.mount syncToRA:actualRA dec:actualDec completion:^(CASMountSlewError error) {
                
                if (error != CASMountSlewErrorNone){
                    [self completeWithErrorMessage:[NSString stringWithFormat:@"Failed to sync the mount with error %ld",error]];
                }
                else {
                    // start slewing to the desired location
                    [self startSlewToRA:_raInDegrees dec:_decInDegrees];
                }
            }];
        }
    }];
}

- (void)startSlewToRA:(double)raInDegrees dec:(double)decInDegrees
{
    NSParameterAssert(self.mount.connected);
    NSParameterAssert(self.cameraController);
    NSParameterAssert(raInDegrees >= 0 && raInDegrees <= 360);
    NSParameterAssert(decInDegrees >= -90 && decInDegrees <= 90);

    self.solving = YES;

    _syncCount = 0;
    _raInDegrees = raInDegrees;
    _decInDegrees = decInDegrees;
    
    [self.mount startSlewToRA:_raInDegrees dec:_decInDegrees completion:^(CASMountSlewError error) {
        
        if (error != CASMountSlewErrorNone){
            [self completeWithErrorMessage:[NSString stringWithFormat:@"Start slew failed with error %ld",error]];
        }
        else {
            self.status = [NSString stringWithFormat:@"Slewing to %@, %@...",[CASLX200Commands highPrecisionRA:_raInDegrees],[CASLX200Commands highPrecisionDec:_decInDegrees]];
            [self.mount addObserver:self forKeyPath:@"slewing" options:0 context:&kvoContext];
        }
    }];
}

- (void)cancel
{
    [self.cameraController cancelCapture];
    [self.plateSolver cancel];
    [self.mount stopMoving];
}

- (void)setStatus:(NSString *)status
{
    if (status != _status){
        _status = [status copy];
        if (status) NSLog(@"%@",status);
    }
}

- (void)setNilValueForKey:(NSString *)key
{
    if ([@"focalLength" isEqualToString:key]){
        self.focalLength = 0;
    }
    else {
        [super setNilValueForKey:key];
    }
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if (context == &kvoContext) {
        
        if ([@"slewing" isEqualToString:keyPath]){
            
            if (!self.mount.slewing){
                
                NSLog(@"Slew complete");
                [self.mount removeObserver:self forKeyPath:@"slewing" context:&kvoContext];
                
                dispatch_async(dispatch_get_main_queue(), ^{
                    
#if !CAS_SLEW_AND_SYNC_TEST
                    [self syncAndSlew];
#else
                    NSLog(@"_testError: %f",_testError);
                    
                    if (_testError < 0.125){
                        [self.mountWindowDelegate mountWindowControllerDidSync:nil];
                    }
                    else{
                        
                        // sync to an imaginary position
                        [self.mount syncToRA:_raDegs+_testError dec:_decDegs+_testError completion:^(CASMountSlewError slewError) {
                            
                            // reduce error
                            _testError /= 2;
                            
                            if (slewError != CASMountSlewErrorNone){
                                [self presentAlertWithMessage:[NSString stringWithFormat:@"Failed to sync with solved location: %ld",slewError]];
                            }
                            else {
                                
                                // slew
                                dispatch_async(dispatch_get_main_queue(), ^{
                                    [self startSlewToRA:_raDegs dec:_decDegs];
                                });
                            }
                        }];
                    }
#endif
                });
            }
        }
    } else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

- (void)completeWithError:(NSError*)error
{
    self.solving = NO;
    self.status = @"";
    
    if (_pushedSettings){
        _pushedSettings = NO;
        [self.cameraController popSettings]; // causing exception about nil keys e.g. startGuiding?
        self.cameraController.temperatureLock = _saveTemperatureLock;
        self.cameraController.sink = _savedSink;
    }
    
    self.error = error;

    [self.delegate mountSynchroniser:self didCompleteWithError:self.error];
}

- (void)completeWithErrorMessage:(NSString*)message
{
    if (message){
        [self setErrorWithCode:1 message:message];
    }
    [self completeWithError:self.error];
}

- (NSError*)setErrorWithCode:(NSInteger)code message:(NSString*)message
{
    self.error = [NSError errorWithDomain:NSStringFromClass([self class])
                                     code:code
                                 userInfo:[NSDictionary dictionaryWithObjectsAndKeys:NSLocalizedDescriptionKey,message,nil]];
    return self.error;
}

- (void)captureAndSolveWithCompletion:(void(^)(NSError*,double ra,double dec))completion
{
    NSParameterAssert(completion);
    
    const NSInteger captureBinning = [[NSUserDefaults standardUserDefaults] integerForKey:@"CASMountSlewControllerBinning"];
    const NSInteger captureSeconds = [[NSUserDefaults standardUserDefaults] integerForKey:@"CASMountSlewControllerDuration"];
    
    void (^callCompletion)(NSError*,double,double) = ^(NSError* error,double ra,double dec){
        
        [self.cameraController popSettings];
        self.cameraController.temperatureLock = _saveTemperatureLock;

        completion(error,ra,dec);
    };
    
    if (!self.cameraController){
        callCompletion([self setErrorWithCode:1 message:@"No camera is connected"],0,0);
    }
    else {
        
        // set up the camera
        CASExposureSettings* settings = [CASExposureSettings new];
        settings.binning = captureBinning;
        settings.exposureDuration = captureSeconds;

        // turn off temp lock, not stored in settings so we have to stash it in an ivar
        _pushedSettings = YES;
        _saveTemperatureLock = self.cameraController.temperatureLock;
        self.cameraController.temperatureLock = NO;
        
        // turn off the controller's sink
        _savedSink = self.cameraController.sink;
        self.cameraController.sink = nil;
        
        [self.cameraController pushSettings:settings];
        
        self.status = [NSString stringWithFormat:@"Capturing from %@",self.cameraController.camera.deviceName];
        
        // grab an exposure
        [self.cameraController captureWithBlock:^(NSError* error, CASCCDExposure* exposure) {
            
            if (error){
                callCompletion(error,0,0);
            }
            else {
                
                [self.delegate mountSynchroniser:self didCaptureExposure:exposure];
                
                // plate solve the exposure
                self.status = @"Capture complete, solving...";
                self.plateSolver = [CASPlateSolver plateSolverWithIdentifier:nil];
                if (![self.plateSolver canSolveExposure:exposure error:&error]){
                    callCompletion(error,0,0);
                }
                else {
                    
                    // set optical params
                    if (self.focalLength > 0){
                        self.plateSolver.fieldSizeDegrees = [self.cameraController fieldSizeForFocalLength:self.focalLength];
                        self.plateSolver.arcsecsPerPixel = [self.cameraController arcsecsPerPixelForFocalLength:self.focalLength].width;
                    }
                    
                    // set mount params
                    NSNumber* ra = self.mount.ra;
                    NSNumber* dec = self.mount.dec;
                    if (ra && dec){
                        self.plateSolver.searchRA = ra.floatValue;
                        self.plateSolver.searchDec = dec.floatValue;
                        self.plateSolver.searchRadius = [[NSUserDefaults standardUserDefaults] floatForKey:@"CASMountSlewControllerSearchRadius"];
                    }
                    
                    [self.plateSolver solveExposure:exposure completion:^(NSError *error, NSDictionary* results) {
                        
                        if (error){
                            callCompletion(error,0,0);
                        }
                        else {
                            
                            // got a solution, calculate separation and see if it's converging on the intended location
                            CASPlateSolveSolution* solution = results[@"solution"];
                            
                            [self.delegate mountSynchroniser:self didSolveExposure:solution];
                            
                            callCompletion(nil,solution.centreRA,solution.centreDec);
                        }
                    }];
                }
            }
        }];
    }
}

- (void)syncAndSlew
{
    const float separationLimit = [[NSUserDefaults standardUserDefaults] floatForKey:@"CASMountSlewControllerConvergence"];
    const float maxSeparationLimit = 10;
    const NSInteger syncCountLimit = 4;

    // get the current pointing location of the mount
    [self captureAndSolveWithCompletion:^(NSError* error, double actualRA, double actualDec) {

        if (error){
            [self completeWithError:error];
        }
        else {
            
            // figure out the separation from where we are and where we want to be
            self.separation = CASAngularSeparation(actualRA,actualDec,_raInDegrees,_decInDegrees);
            self.status = [NSString stringWithFormat:@"Solved, RA: %f Dec: %f, separation: %f",actualRA,actualDec,self.separation];
            
            // check the separation against our limits
            if (self.separation > maxSeparationLimit){
                [self completeWithErrorMessage:[NSString stringWithFormat:@"Slew failed, separation of %0.3f° exceeds maximum",self.separation]];
            }
            else if (self.separation < separationLimit){
                [self completeWithError:nil];
            }
            else {
                
                // check to see if we're not converging
                if (++_syncCount > syncCountLimit){
                    [self completeWithErrorMessage:[NSString stringWithFormat:@"Slew failed, exceeded max sync count. Current separation is %0.3f°",self.separation]];
                }
                else {
                    
                    self.status = [NSString stringWithFormat:@"Separation is %0.3f°, syncing mount and re-slewing",self.separation];
                    
                    // close but not yet good enought, sync scope to solution co-ordinates, repeat slew
                    [self.mount syncToRA:actualRA dec:actualDec completion:^(CASMountSlewError slewError) {
                        
                        if (slewError != CASMountSlewErrorNone){
                            [self completeWithErrorMessage:[NSString stringWithFormat:@"Failed to sync with solved location: %ld",slewError]];
                        }
                        else {
                            
                            [self.cameraController popSettings];
                            self.cameraController.temperatureLock = _saveTemperatureLock;
                            
                            dispatch_async(dispatch_get_main_queue(), ^{
                                [self startSlewToRA:_raInDegrees dec:_decInDegrees];
                            });
                        }
                    }];
                }
            }
        }
    }];
}

@end

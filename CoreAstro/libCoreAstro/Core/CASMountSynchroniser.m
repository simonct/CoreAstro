//
//  CASMountSlewController.m
//  astrometry-test
//
//  Created by Simon Taylor on 24/03/2015.
//  Copyright (c) 2015 Simon Taylor. All rights reserved.
//

#import "CASMountSynchroniser.h"

//#define CAS_SLEW_AND_SYNC_TEST 1

@interface CASMountSynchroniser ()
@property BOOL busy;
@property float separation;
@property float focalLength;
@property (strong) NSError* error;
@property (nonatomic,copy) NSString* status;
@property (strong) CASPlateSolver* plateSolver;
@property (strong) CASMountSlewObserver* slewObserver;
@end

@implementation CASMountSynchroniser {
    int _syncCount;
    float _raInDegrees,_decInDegrees;
    BOOL _pushedSettings;
    BOOL _saveTemperatureLock;
    id<CASCameraControllerSink> _savedSink;
    BOOL _cancelled;
#if CAS_SLEW_AND_SYNC_TEST
    double _testError;
#endif
}

+ (void)initialize
{
    [[NSUserDefaults standardUserDefaults] registerDefaults:@{@"CASMountSlewControllerBinning":@(4),
                                                              @"CASMountSlewControllerDuration":@(5),
                                                              @"CASMountSlewControllerConvergence":@(0.02),
                                                              @"CASMountSlewControllerSearchRadius":@(5)}];
}

- (void)startSlewToRA:(double)raInDegrees dec:(double)decInDegrees
{
#if CAS_SLEW_AND_SYNC_TEST
    _testError = 1;
#endif
    
    [self startSlewToRAImpl:raInDegrees dec:decInDegrees];
}

- (void)startSlewToRAImpl:(double)raInDegrees dec:(double)decInDegrees
{
    NSParameterAssert(self.mount);
    NSParameterAssert(self.mount.connected);
    NSParameterAssert(self.cameraController);
    NSParameterAssert(raInDegrees >= 0 && raInDegrees <= 360);
    NSParameterAssert(decInDegrees >= -90 && decInDegrees <= 90);

    self.busy = YES;

    _syncCount = 0;
    _raInDegrees = raInDegrees;
    _decInDegrees = decInDegrees;
    
    __weak __typeof(self) weakSelf = self;
    [self.mount startSlewToRA:_raInDegrees dec:_decInDegrees completion:^(CASMountSlewError error,CASMountSlewObserver* observer) {
        
        if (error != CASMountSlewErrorNone){
            [self completeWithErrorMessage:[NSString stringWithFormat:@"Start slew failed with error %ld",error]];
        }
        else {
            
            self.status = [NSString stringWithFormat:@"Slewing to %@, %@...",[CASLX200Commands highPrecisionRA:_raInDegrees],[CASLX200Commands highPrecisionDec:_decInDegrees]];
            
            self.slewObserver = observer;
            self.slewObserver.completion = ^(NSError* error){
                
                NSLog(@"Synchroniser slew complete");
                
                dispatch_async(dispatch_get_main_queue(), ^{
                    
#if !CAS_SLEW_AND_SYNC_TEST
                    [weakSelf syncAndSlew];
#else
                    NSLog(@"_testError: %f",_testError);
                    
                    if (_testError < 0.125){
                        [weakSelf completeWithError:nil];
                    }
                    else{
                        
                        // sync to an imaginary position
                        [weakSelf.mount syncToRA:_raInDegrees+_testError dec:_decInDegrees+_testError completion:^(CASMountSlewError slewError) {
                            
                            // reduce error
                            _testError /= 2;
                            
                            if (slewError != CASMountSlewErrorNone){
//                                [self presentAlertWithMessage:[NSString stringWithFormat:@"Failed to sync with solved location: %ld",slewError]];
                                [weakSelf completeWithErrorMessage:[NSString stringWithFormat:@"Slew failed with error %ld",(long)slewError]];
                            }
                            else {
                                
                                // slew
                                dispatch_async(dispatch_get_main_queue(), ^{
                                    [self startSlewToRAImpl:_raInDegrees dec:_decInDegrees];
                                });
                            }
                        }];
                    }
#endif
                });
                weakSelf.slewObserver = nil;
            };
        }
    }];
}

- (void)cancel
{
    _cancelled = YES;
    [self.cameraController cancelCapture];
    [self.plateSolver cancel];
    [self.mount stopSlewing];
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

- (void)completeWithError:(NSError*)error
{
    self.busy = NO;
    self.status = @"";
    
    [self restoreCameraSettings];
    
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

- (void)restoreCameraSettings
{
    if (_pushedSettings){
        _pushedSettings = NO;
        [self.cameraController popSettings]; // causing exception about nil keys e.g. startGuiding?
        self.cameraController.temperatureLock = _saveTemperatureLock;
        self.cameraController.sink = _savedSink;
    }
}

- (void)captureAndSolveWithCompletion:(void(^)(NSError*,double ra,double dec))completion
{
    NSParameterAssert(completion);
    
    const NSInteger captureBinning = [[NSUserDefaults standardUserDefaults] integerForKey:@"CASMountSlewControllerBinning"];
    const NSInteger captureSeconds = [[NSUserDefaults standardUserDefaults] integerForKey:@"CASMountSlewControllerDuration"];
    
    void (^callCompletion)(NSError*,double,double) = ^(NSError* error,double ra,double dec){
        [self restoreCameraSettings];
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
        settings.ditherEnabled = NO;
        
        // turn off temp lock, not stored in settings so we have to stash it in an ivar
        _pushedSettings = YES;
        _saveTemperatureLock = self.cameraController.temperatureLock;
        self.cameraController.temperatureLock = NO;
        
        // turn off the controller's sink so that we don't save these intermediate pointing exposures
        // (todo; or could just pass a param identifying this as a pointing rather than capture exposure?)
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
                
                // check exposure intensity ? e.g. see if it's massively overexposed
                
                if (_cancelled || self.cameraController.cancelled){
                    [self restoreCameraSettings];
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
                        
                        // grab the camera's focal length
                        self.focalLength = self.cameraController.focalLength;

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
                                
                                if (_cancelled){
                                    [self restoreCameraSettings];
                                }
                                else{
                                
                                    // got a solution, calculate separation and see if it's converging on the intended location
                                    CASPlateSolveSolution* solution = results[@"solution"];
                                    
                                    [self.delegate mountSynchroniser:self didSolveExposure:solution];
                                    
                                    callCompletion(nil,solution.centreRA,solution.centreDec);
                                }
                            }
                        }];
                    }
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
                NSLog(@"Separation %f greater than limit of %f, sync failed",self.separation,maxSeparationLimit);
                [self completeWithErrorMessage:[NSString stringWithFormat:@"Slew failed, separation of %0.3f° exceeds maximum",self.separation]];
            }
            else if (self.separation < separationLimit){
                NSLog(@"Separation %f less than limit of %f, sync complete",self.separation,separationLimit);
                [self completeWithError:nil];
            }
            else {
                
                // check to see if we're not converging
                if (++_syncCount > syncCountLimit){
                    NSLog(@"Sync count exceeded max of %ld",syncCountLimit);
                    [self completeWithErrorMessage:[NSString stringWithFormat:@"Slew failed, exceeded max sync count. Current separation is %0.3f°",self.separation]];
                }
                else {
                    
                    NSLog(@"Slewing mount to sync position");

                    self.status = [NSString stringWithFormat:@"Separation is %0.3f°, syncing mount and re-slewing",self.separation];
                    
                    // close but not yet good enough, sync scope to solution co-ordinates, repeat slew
                    [self.mount syncToRA:actualRA dec:actualDec completion:^(CASMountSlewError slewError) {
                        
                        if (slewError != CASMountSlewErrorNone){
                            [self completeWithErrorMessage:[NSString stringWithFormat:@"Failed to sync with solved location: %ld",slewError]];
                        }
                        else {
                            
                            [self restoreCameraSettings];
                            
                            dispatch_async(dispatch_get_main_queue(), ^{
                                [self startSlewToRAImpl:_raInDegrees dec:_decInDegrees];
                            });
                        }
                    }];
                }
            }
        }
    }];
}

@end

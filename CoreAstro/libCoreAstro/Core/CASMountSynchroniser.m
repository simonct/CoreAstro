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
}

static void* kvoContext;

+ (void)initialize
{
    [[NSUserDefaults standardUserDefaults] registerDefaults:@{@"CASMountSlewControllerBinning":@(4),
                                                              @"CASMountSlewControllerDuration":@(5),
                                                              @"CASMountSlewControllerConvergence":@(0.02),
                                                              @"CASMountSlewControllerSearchRadius":@(5)}];
}

- (void)startSlewToRA:(double)raInDegrees dec:(double)decInDegrees
{
    NSParameterAssert(self.mount.connected);
    NSParameterAssert(self.cameraController);
    NSParameterAssert(raInDegrees >= 0 && raInDegrees <= 360);
    NSParameterAssert(decInDegrees >= -90 && decInDegrees <= 90);

    _raInDegrees = raInDegrees;
    _decInDegrees = decInDegrees;
    
    [self.mount startSlewToRA:_raInDegrees dec:_decInDegrees completion:^(CASMountSlewError error) {
        
        if (error != CASMountSlewErrorNone){
            [self completeWithMessage:[NSString stringWithFormat:@"Start slew failed with error %ld",error]];
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
                    [self captureImageAndPlateSolve];
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

- (void)completeWithMessage:(NSString*)message
{
    self.solving = NO;
    self.status = @"";
    [self.cameraController popSettings];
    if (message){
        [self setErrorWithCode:1 message:message];
    }
    [self.delegate mountSynchroniser:self didCompleteWithError:self.error];
}

- (void)setErrorWithCode:(NSInteger)code message:(NSString*)message
{
    self.error = [NSError errorWithDomain:NSStringFromClass([self class])
                                     code:code
                                 userInfo:[NSDictionary dictionaryWithObjectsAndKeys:NSLocalizedFailureReasonErrorKey,message,nil]];
}

- (void)captureImageAndPlateSolve
{
    const float separationLimit = [[NSUserDefaults standardUserDefaults] floatForKey:@"CASMountSlewControllerConvergence"];
    const NSInteger captureBinning = [[NSUserDefaults standardUserDefaults] integerForKey:@"CASMountSlewControllerBinning"];
    const NSInteger captureSeconds = [[NSUserDefaults standardUserDefaults] integerForKey:@"CASMountSlewControllerDuration"];
    
    const float maxSeparationLimit = 10;
    const NSInteger syncCountLimit = 4;
    
    self.solving = YES;
    
    if (!self.cameraController){
        [self completeWithMessage:@"There are no connected cameras"];
    }
    else {
        
        // set up the camera
        CASExposureSettings* settings = [CASExposureSettings new];
        settings.binning = captureBinning;
        settings.exposureDuration = captureSeconds;
        // set point 0 ?
        [self.cameraController pushSettings:settings];
        
        self.status = [NSString stringWithFormat:@"Capturing from %@",self.cameraController.camera.deviceName];
        
        // grab an exposure
        [self.cameraController captureWithBlock:^(NSError* error, CASCCDExposure* exposure) {
            
            if (error){
                [self completeWithMessage:[NSString stringWithFormat:@"Capture failed: %@",[error localizedDescription]]];
            }
            else {
                
                [self.delegate mountSynchroniser:self didCaptureExposure:exposure];
                
                // plate solve the exposure
                self.status = @"Capture complete, solving...";
                self.plateSolver = [CASPlateSolver plateSolverWithIdentifier:nil];
                if (![self.plateSolver canSolveExposure:exposure error:&error]){
                    [self completeWithMessage:[NSString stringWithFormat:@"Can't solve exposure: %@",[error localizedDescription]]];
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
                    
                    [self.plateSolver solveExposure:exposure completion:^(NSError *error, NSDictionary * results) {
                        
                        if (error){
                            [self completeWithMessage:[NSString stringWithFormat:@"Plate solve failed: %@",[error localizedDescription]]];
                        }
                        else {
                            
                            // got a solution, calculate separation and see if it's converging on the intended location
                            CASPlateSolveSolution* solution = results[@"solution"];

                            [self.delegate mountSynchroniser:self didSolveExposure:solution];

                            self.separation = CASAngularSeparation(solution.centreRA,solution.centreDec,_raInDegrees,_decInDegrees);
                            self.status = [NSString stringWithFormat:@"Solved, RA: %f Dec: %f, separation: %f",solution.centreRA,solution.centreDec,self.separation];
                            
                            if (self.separation > maxSeparationLimit){
                                [self completeWithMessage:[NSString stringWithFormat:@"Slew failed, separation of %0.3f° exceeds maximum",self.separation]];
                            }
                            else if (self.separation < separationLimit){
                                
                                NSLog(@"Slew and sync complete");
                                [self completeWithMessage:nil];
                            }
                            else {
                                
                                // check to see if we're not converging
                                if (++_syncCount > syncCountLimit){
                                    [self completeWithMessage:[NSString stringWithFormat:@"Slew failed, exceeded max sync count. Current separation is %0.3f°",self.separation]];
                                }
                                else {
                                    
                                    self.status = [NSString stringWithFormat:@"Separation is %0.3f°, syncing mount and re-slewing",self.separation];
                                    
                                    // close but not yet good enought, sync scope to solution co-ordinates, repeat slew
                                    [self.mount syncToRA:solution.centreRA dec:solution.centreDec completion:^(CASMountSlewError slewError) {
                                        
                                        if (slewError != CASMountSlewErrorNone){
                                            [self completeWithMessage:[NSString stringWithFormat:@"Failed to sync with solved location: %ld",slewError]];
                                        }
                                        else {
                                            
                                            [self.cameraController popSettings];
                                            
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
            }
        }];
    }
}

@end

//
//  CASMountWindowController.m
//  ieq-test
//
//  Created by Simon Taylor on 1/26/14.
//  Copyright (c) 2014 Simon Taylor. All rights reserved.
//

#import "CASMountWindowController.h"
#import <CoreAstro/CoreAstro.h>

@interface CASMountWindowController ()
@property (nonatomic,strong) CASMount* mount;
@property (nonatomic,copy) NSString* searchString;
@property (nonatomic,assign) NSInteger guideDurationInMS;
@property (nonatomic) double separation;
@property BOOL usePlateSolvng;
@end

#define CAS_SLEW_AND_SYNC_TEST 0

@implementation CASMountWindowController {
    NSInteger _syncCount;
    double _raInDegrees, _decInDegrees; // still need these ?
#if CAS_SLEW_AND_SYNC_TEST
    double _testError;
#endif
}

static void* kvoContext;

+ (void)initialize
{
    [NSValueTransformer setValueTransformer:[CASLX200RATransformer new] forName:@"CASLX200RATransformer"];
    [NSValueTransformer setValueTransformer:[CASLX200DecTransformer new] forName:@"CASLX200DecTransformer"];
}

- (void)presentAlertWithMessage:(NSString*)message
{
    [[NSAlert alertWithMessageText:nil defaultButton:@"OK" alternateButton:nil otherButton:nil informativeTextWithFormat:@"%@",message] runModal];
}

- (void)connectToMount:(CASMount*)mount completion:(void(^)(NSError*))completion
{
    self.mount = mount;
    
#if CAS_SLEW_AND_SYNC_TEST
    _testError = 1;
#endif

    [self.mount connectWithCompletion:^(NSError* error){
        if (self.mount.connected){
            [self.window makeKeyAndOrderFront:nil];
            self.guideDurationInMS = 1000;
        }
        if (completion){
            completion(error);
        }
    }];
}

- (void)setTargetRA:(double)raDegs dec:(double)decDegs
{
    NSParameterAssert(self.mount.connected);
    
    __weak __typeof (self) weakSelf = self;
    [self.mount setTargetRA:raDegs dec:decDegs completion:^(CASMountSlewError error) {
        if (error != CASMountSlewErrorNone){
            [weakSelf presentAlertWithMessage:[NSString stringWithFormat:@"Set target failed with error %ld",error]];
        }
    }];
}

- (void)startSlewToRA:(double)raInDegrees dec:(double)decInDegrees
{
    NSParameterAssert(self.mount.connected);

    _raInDegrees = raInDegrees;
    _decInDegrees = decInDegrees;
    
    // todo; validate, don't depend on the mount
    
    [self.mount startSlewToRA:_raInDegrees dec:_decInDegrees completion:^(CASMountSlewError error) {
        
        if (error != CASMountSlewErrorNone){
            [self presentAlertWithMessage:[NSString stringWithFormat:@"Start slew failed with error %ld",error]];
        }
        else {
            NSLog(@"Slewing to %@, %@...",[CASLX200Commands highPrecisionRA:_raInDegrees],[CASLX200Commands highPrecisionDec:_decInDegrees]);
            [self.mount addObserver:self forKeyPath:@"slewing" options:0 context:&kvoContext];
        }
    }];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if (context == &kvoContext) {
        
        if ([@"slewing" isEqualToString:keyPath]){
            
            if (!self.mount.slewing){
                
                NSLog(@"Slew complete");
                [self.mount removeObserver:self forKeyPath:@"slewing" context:&kvoContext];
                
                // if we're using plate solving, iterate towards the location
                if (self.usePlateSolvng){
                    
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
        }
    } else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

- (void)captureImageAndPlateSolve
{
    const NSInteger captureBinning = 4;
    const NSInteger captureSeconds = 5;
    const float focalLength = 430;
    const float separationLimit = 0.25;
    const float maxSeparationLimit = 10;
    const NSInteger syncCountLimit = 4;

    CASCameraController* controller = [[CASDeviceManager sharedManager].cameraControllers firstObject];
    if (!controller){
        [self presentAlertWithMessage:@"There are no connected cameras"];
    }
    else {
        
        void (^completeWithMessage)(NSString*,BOOL) = ^(NSString* message,BOOL callDelegate){
            [controller popSettings];
            if (callDelegate){
                [self.mountWindowDelegate mountWindowControllerDidSync:message ? [NSError errorWithDomain:@"CASMountWindowController"
                                                                                                     code:1
                                                                                                 userInfo:[NSDictionary dictionaryWithObjectsAndKeys:NSLocalizedFailureReasonErrorKey,message,nil]] : nil];
            }
        };
        
        CASExposureSettings* settings = [CASExposureSettings new];
        settings.binning = captureBinning;
        settings.exposureDuration = captureSeconds;
        // set point 0 ?
        [controller pushSettings:settings];
        
        NSLog(@"Capturing from %@",controller.camera.deviceName);
        [controller captureWithBlock:^(NSError* error, CASCCDExposure* exposure) {
            
            if (error){
                completeWithMessage([NSString stringWithFormat:@"Capture failed: %@",[error localizedDescription]],YES);
            }
            else {
                
                // set this as the current exposure
                [self.mountWindowDelegate mountWindowController:self didCaptureExposure:exposure];

                NSLog(@"Capture complete, solving...");
                CASPlateSolver* plateSolver = [CASPlateSolver plateSolverWithIdentifier:nil];
                if (![plateSolver canSolveExposure:exposure error:&error]){
                    completeWithMessage([NSString stringWithFormat:@"Can't solve exposure: %@",[error localizedDescription]],YES);
                }
                else {
                    
                    plateSolver.fieldSizeDegrees = [controller fieldSizeForFocalLength:focalLength];
                    plateSolver.arcsecsPerPixel = [controller arcsecsPerPixelForFocalLength:focalLength].width;
                    
                    // todo; can also set expected ra and dec of field
                    
                    [plateSolver solveExposure:exposure completion:^(NSError *error, NSDictionary * results) {
                        
                        if (error){
                            completeWithMessage([NSString stringWithFormat:@"Plate solve failed: %@",[error localizedDescription]],YES);
                        }
                        else {
                            
                            CASPlateSolveSolution* solution = results[@"solution"];
                            self.separation = CASAngularSeparation(solution.centreRA,solution.centreDec,_raInDegrees,_decInDegrees);
                            NSLog(@"Solved, RA: %f Dec: %f, separation: %f",solution.centreRA,solution.centreDec,self.separation);

                            // set as current solution
                            [self.mountWindowDelegate mountWindowController:self didSolveExposure:solution];

                            if (self.separation > maxSeparationLimit){
                                // warn, confirm slew...
                                completeWithMessage([NSString stringWithFormat:@"Slew failed, separation of %0.3f° exceeds maximum",self.separation],YES);
                            }
                            else if (self.separation < separationLimit){
                                completeWithMessage(nil,YES);
                            }
                            else {
                                
                                if (++_syncCount > syncCountLimit){
                                    completeWithMessage([NSString stringWithFormat:@"Slew failed, exceeded max sync count. Current separation is %0.3f°",self.separation],YES);
                                }
                                else {
                                
                                    NSLog(@"Separation is %0.3f°, syncing mount and re-slewing",self.separation);

                                    // sync scope to solution co-ordinates, repeat slew
                                    [self.mount syncToRA:solution.centreRA dec:solution.centreDec completion:^(CASMountSlewError slewError) {
                                        
                                        if (slewError != CASMountSlewErrorNone){
                                            completeWithMessage([NSString stringWithFormat:@"Failed to sync with solved location: %ld",slewError],YES);
                                        }
                                        else {
                                            completeWithMessage(nil,NO); // pop the settings
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

- (void)startMoving:(CASMountDirection)direction
{
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(stopMoving:) object:nil];
    [self performSelector:@selector(stopMoving:) withObject:nil afterDelay:0.25];
    [self.mount startMoving:direction];
}

#pragma mark - Actions

- (IBAction)north:(id)sender
{
    [self startMoving:CASMountDirectionNorth];
}

- (IBAction)soutgh:(id)sender
{
    [self startMoving:CASMountDirectionSouth];
}

- (IBAction)west:(id)sender
{
    [self startMoving:CASMountDirectionWest];
}

- (IBAction)east:(id)sender
{
    [self startMoving:CASMountDirectionEast];
}

- (IBAction)slew:(id)sender
{
    if (!self.mount.targetRa || !self.mount.targetDec){
        return;
    }
    
    [self startSlewToRA:[self.mount.targetRa doubleValue] dec:[self.mount.targetDec doubleValue]];
}

- (IBAction)stop:(id)sender
{
    [self.mount halt];
}

- (IBAction)lookup:(id)sender
{
    if (![self.searchString length]){
        NSBeep();
        return;
    }
    
    __weak __typeof (self) weakSelf = self;
    
    CASObjectLookup* lookup = [CASObjectLookup new];
    [lookup lookupObject:self.searchString withCompletion:^(BOOL success,double ra, double dec) {
        if (!success){
            [[NSAlert alertWithMessageText:@"Not Found" defaultButton:@"OK" alternateButton:nil otherButton:nil informativeTextWithFormat:@"Target couldn't be found"] runModal];
        }
        else{
            [weakSelf setTargetRA:ra dec:dec];
        }
    }];
}

@end

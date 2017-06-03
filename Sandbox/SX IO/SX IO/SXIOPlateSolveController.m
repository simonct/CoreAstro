//
//  SXIOPlateSolveController.m
//  SX IO
//
//  Created by Simon Taylor on 01/06/2017.
//  Copyright © 2017 Simon Taylor. All rights reserved.
//

#import "SXIOPlateSolveController.h"
#import "CASProgressWindowController.h"
#import "SXIOPlateSolutionLookup.h"
#import "SXIOPlateSolveOptionsWindowController.h"

@interface SXIOPlateSolveController ()
@property (strong) CASPlateSolver* plateSolver;
@property (strong) SXIOPlateSolveOptionsWindowController* plateSolveOptionsWindowController;
@end

@implementation SXIOPlateSolveController

- (BOOL) busy
{
    return self.plateSolver != nil;
}

// check the astrometry.net is installed and configured
//
- (void)preparePlateSolveExposure:(CASCCDExposure*)exposure completion:(void(^)(NSError*))completion
{
    NSParameterAssert(completion);
    
    if (self.plateSolver){
        // todo; solvers should be per exposure
        NSLog(@"Already solving something");
        completion(NO);
        return;
    }
    
    if (!exposure){
        NSLog(@"No current exposure");
        completion(NO);
        return;
    }
    
    NSError* error = nil;
    self.plateSolver = [CASPlateSolver plateSolverWithIdentifier:nil];
    if ([self.plateSolver canSolveExposure:exposure error:&error]){
        completion(nil);
    }
    else{
        
        // consume the error relating to missing indexes
        if (error.code == 1){
            
            NSOpenPanel* openPanel = [NSOpenPanel openPanel];
            
            openPanel.canChooseFiles = NO;
            openPanel.canChooseDirectories = YES;
            openPanel.canCreateDirectories = YES;
            openPanel.allowsMultipleSelection = NO;
            openPanel.prompt = @"Choose";
            openPanel.message = @"Locate the astrometry.net indexes";;
            
            [openPanel beginSheetModalForWindow:self.window completionHandler:^(NSInteger result) {
                if (result == NSFileHandlingPanelOKButton){
                    self.plateSolver.indexDirectoryURL = openPanel.URL;
                    dispatch_async(dispatch_get_main_queue(), ^{
                        completion(nil);
                    });
                }
            }];
            
            error = nil;
        }
        else if (error.code == 2) {
            error = [NSError errorWithDomain:@"SXIOPlateSolveController"
                                        code:1
                                    userInfo:@{NSLocalizedDescriptionKey:@"astrometry.net not installed. Please install the command line tools from astrometry.net before running this command"}]; // link to blog page ?
            completion(error);
        }
        else {
            completion(error);
        }
    }
}

// Solve the given exposure
//
- (void)plateSolveExposure:(CASCCDExposure*)exposure withFieldSize:(CGSize)fieldSize arcsecsPerPixel:(float)arcsecsPerPixel
{
    [self preparePlateSolveExposure:exposure completion:^(NSError* prepError) {
        
        if (prepError){
            [self.delegate plateSolver:self completedWithSolution:nil error:prepError];
            return;
        }
        
        NSError* error;
        if (![self.plateSolver canSolveExposure:exposure error:&error]){
            [self.delegate plateSolver:self completedWithSolution:nil error:error];
            return;
        }
        
        // todo; should be per exposure rather than blocking the whole app
        // todo; show the spinner on the plate solution hud
        // todo; autosolve when show plate solution is on, lose the plate solve command
        CASProgressWindowController* progress;
        progress = [CASProgressWindowController createWindowController];
        [progress beginSheetModalForWindow:self.window];
        progress.label.stringValue = NSLocalizedString(@"Solving...", @"Progress sheet status label");
        [progress.progressBar setIndeterminate:YES];
        
        progress.canCancel = YES;
        progress.cancelBlock = ^{
            [self.plateSolver cancel];
        };
        
        [self.delegate plateSolver:self didStartSolvingExposure:exposure];

        // solve async - beware of races here since we're doing this async
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            
            self.plateSolver.fieldSizeDegrees = fieldSize;
            self.plateSolver.arcsecsPerPixel = arcsecsPerPixel;
            
            [self.plateSolver solveExposure:exposure completion:^(NSError *error, NSDictionary * results) {
                
                if (!progress.cancelled && !error){
                    
                    // post notification so that mount controller window can pick up the new solution ?
                    
                    NSData* solutionData = [NSKeyedArchiver archivedDataWithRootObject:results[@"solution"]];
                    if (solutionData){
                        [[SXIOPlateSolutionLookup sharedLookup] storeSolutionData:solutionData forUUID:exposure.uuid];
                    }
                }
                
                dispatch_async(dispatch_get_main_queue(), ^{
                    
                    [progress endSheetWithCode:NSOKButton];
                    
                    if (!progress.cancelled) {
                        [self.delegate plateSolver:self completedWithSolution:results[@"solution"] error:error];
                    }
                    self.plateSolver = nil;
                });
            }];
        });
    }];
}

- (void)plateSolveExposure:(CASCCDExposure*)exposure
{
    [self preparePlateSolveExposure:(CASCCDExposure*)exposure completion:^(NSError* error) {
        
        if (error){
            self.plateSolver = nil;
            [NSApp presentError:error];
        }
        else{
            [self plateSolveExposure:exposure withFieldSize:CGSizeZero arcsecsPerPixel:0];
        }
    }];
}

- (void)plateSolveExposureWithOptions:(CASCCDExposure*)exposure
{
    [self preparePlateSolveExposure:(CASCCDExposure*)exposure completion:^(NSError* error) {
        
        if (error){
            self.plateSolver = nil;
            [NSApp presentError:error];
        }
        else{
            
            self.plateSolveOptionsWindowController = [SXIOPlateSolveOptionsWindowController createWindowController];
            self.plateSolveOptionsWindowController.exposure = exposure;
            self.plateSolveOptionsWindowController.cameraController = self.cameraController;
            [self.plateSolveOptionsWindowController beginSheetModalForWindow:self.window completionHandler:^(NSInteger result) {
                if (result == NSOKButton) {
                    const CGSize fieldSize = self.plateSolveOptionsWindowController.enableFieldSize ? self.plateSolveOptionsWindowController.fieldSizeDegrees : CGSizeZero;
                    const float arcsecsPerPixel = self.plateSolveOptionsWindowController.enablePixelSize ? self.plateSolveOptionsWindowController.arcsecsPerPixel: 0;
                    [self plateSolveExposure:exposure withFieldSize:fieldSize arcsecsPerPixel:arcsecsPerPixel];
                }
                else {
                    self.plateSolver = nil;
                }
                self.plateSolveOptionsWindowController = nil;
            }];
        }
    }];
}

@end

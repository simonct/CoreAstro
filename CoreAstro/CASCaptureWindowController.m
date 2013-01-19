//
//  CASCaptureWindowController.m
//  CoreAstro
//
//  Created by Simon Taylor on 1/19/13.
//  Copyright (c) 2013 Mako Technology Ltd. All rights reserved.
//

#import "CASCaptureWindowController.h"
#import "CASCameraController.h"
#import "CASImageProcessor.h"
#import "CASCCDExposureLibrary.h"
#import "CASBatchProcessor.h"
#import "CASCCDDevice.h"

@implementation CASCaptureModel
@end

@interface CASCaptureWindowController ()
- (IBAction)ok:(id)sender;
- (IBAction)cancel:(id)sender;
@end

@implementation CASCaptureWindowController

- (id)initWithWindow:(NSWindow *)window
{
    self = [super initWithWindow:window];
    if (self) {
        self.model = [[CASCaptureModel alloc] init];
    }
    
    return self;
}

- (IBAction)ok:(id)sender
{
    [self endSheetWithCode:NSOKButton];
}

- (IBAction)cancel:(id)sender
{
    [self endSheetWithCode:NSCancelButton];
}

@end

@implementation CASCaptureController

- (void)captureWithProgressBlock:(void(^)(CASCCDExposure* exposure,BOOL postProcessing))progress completion:(void(^)(NSError* error))completion
{
    BOOL temperatureLock = NO;
    __block BOOL saveExposure = YES;
    __block NSInteger exposureTime, exposureUnits;
    __block NSMutableArray* exposures = [NSMutableArray arrayWithCapacity:self.model.captureCount];

    switch (self.model.captureMode) {
        case kCASCaptureModelModeDark:
            exposureUnits = 0; // seconds
            exposureTime = self.model.exposureSeconds;
            temperatureLock = YES;
            break;
        case kCASCaptureModelModeBias:
            exposureUnits = 0; // seconds
            exposureTime = 0;
            temperatureLock = YES;
            break;
        case kCASCaptureModelModeFlat:
            exposureUnits = 1; // ms
            exposureTime = 100;
            temperatureLock = NO;
            break;
        default:
            NSLog(@"*** Unknown capture mode: %ld",self.model.captureMode);
            return;
    }
    
    void (^__block capture)(void) = ^(void) {
      
        self.cameraController.continuous = NO;
        self.cameraController.captureCount = 1;
        self.cameraController.exposure = exposureTime;
        self.cameraController.exposureUnits = exposureUnits;
        self.cameraController.binningIndex = 0;
        self.cameraController.subframe = CGRectZero;
        self.cameraController.guider = nil;
        self.cameraController.temperatureLock = temperatureLock;
        
        [self.cameraController captureWithBlock:^(NSError *error,CASCCDExposure* exposure) {
            
            if (error){
                if (completion) completion(error);
            }
            else{
                                
                if ([exposures count] == self.model.captureCount){
                    
                    NSLog(@"Completed %ld exposures",[exposures count]);

                    if (self.model.combineMode == kCASCaptureModelCombineAverage && self.model.captureCount > 1){

                        CASBatchProcessor* processor = [CASBatchProcessor batchProcessorsWithIdentifier:@"combine.average"];

                        // run the processor in the background
                        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                            
                            NSEnumerator* enumerator = [exposures objectEnumerator];
                            
                            [processor processWithProvider:^(CASCCDExposure **exposure, NSDictionary **info) {
                                
                                CASCCDExposure* exp = [enumerator nextObject];
                                if (exp){
                                    
                                    if (self.model.captureMode == kCASCaptureModelModeFlat && self.cameraController.camera.isColour){
                                        exp = [self.imageProcessor removeBayerMatrix:exp];
                                    }
                                }
                                
                                *exposure = exp;
                                
                                if (progress) progress(exp,YES);
                                
                            } completion:^(NSError *error, CASCCDExposure *result) {
                                
                                if (self.model.captureMode == kCASCaptureModelModeFlat){
                                    // todo; save normailised flat data to its exposure bundle
                                }
                                
                                // run completion on the main thread
                                dispatch_async(dispatch_get_main_queue(), ^{
                                    
                                    if (error){
                                        [NSApp presentError:error];
                                    }
                                    else {
                                        if (!self.model.keepOriginals){
                                            [exposures makeObjectsPerformSelector:@selector(deleteExposure)]; // doesn't update the library...
                                        }
                                    }
                                    if (completion) completion(error);
                                });
                            }];
                        });
                    }
                    else {
                        if (completion) completion(nil);
                    }
                }
                else {
                                        
                    if (self.model.captureMode == kCASCaptureModelModeFlat){
                        
                        // assume we might have to adjust the exposure
                        saveExposure = NO;
                        
                        // check intensity todo; need a limit to stop it hunting forever
                        const CGFloat average = [self.imageProcessor averagePixelValue:exposure];
                        if (average < 0.1){
                            exposureTime *= 2;
                        }
                        else if (average > 0.9){
                            exposureTime /= 2;
                        }
                        else if (average >= 0.4 && average <= 0.6) {
                            saveExposure = YES; // nope, good enough
                        }
                        else {
                            exposureTime *= (0.5/average);
                        }
                        NSLog(@"Flats: average of %f, now using exposure of %ldms",average,exposureTime);
                    }
                    
                    if (!saveExposure) {
                        capture();
                    }
                    else{
                    
                        // save exposure to library
                        [[CASCCDExposureLibrary sharedLibrary] addExposure:exposure save:YES block:^(NSError *saveError, NSURL *url) {
                            
                            NSLog(@"Added exposure to library at %@",url);
                            
                            if (error){
                                if (completion) completion(error);
                            }
                            else {
                                [exposures addObject:exposure];
                                if (progress) progress(exposure,NO);
                                capture();
                            }
                        }];
                    }
                }
            }
        }];
    };
    
    capture();
}

+ (CASCaptureController*)captureControllerWithWindowController:(CASCaptureWindowController*)cwc
{
    CASCaptureController* result = [[CASCaptureController alloc] init];

    result.model = cwc.model;
    
    return result;
}

@end
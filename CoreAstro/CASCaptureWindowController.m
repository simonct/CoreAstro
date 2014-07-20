//
//  CASCaptureWindowController.m
//  CoreAstro
//
//  Created by Simon Taylor on 1/19/13.
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

#import "CASCaptureWindowController.h"
#import "CASExposuresController.h"

#import <CoreAstro/CoreAstro.h>

@implementation CASCaptureModel

- (BOOL)exposureSecondsEnabled
{
    return (self.captureMode == kCASCaptureModelModeDark);
}

+ (NSSet*)keyPathsForValuesAffectingExposureSecondsEnabled
{
    return [NSSet setWithObject:@"captureMode"];
}

@end

@interface CASCaptureWindowController ()
- (IBAction)ok:(id)sender;
- (IBAction)cancel:(id)sender;
@property (weak) IBOutlet NSButton *keepOriginalsCheckbox;
@property (weak) IBOutlet NSButton *matchHistogramsCheckbox;
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

- (void)windowDidLoad
{
    [super windowDidLoad];
    [self.keepOriginalsCheckbox setHidden:!self.model.showKeepOriginals];
    [self.matchHistogramsCheckbox setHidden:!self.model.showMatchHistograms];
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

@implementation CASCaptureController {
    BOOL _cancelled:1;
}

- (void)cancelCapture
{
    _cancelled = YES;
    [self.cameraController cancelCapture];
}

- (void)captureWithProgressBlock:(void(^)(CASCCDExposure* exposure,BOOL postProcessing))progress completion:(void(^)(NSError* error,CASCCDExposure* result))completion
{
    BOOL temperatureLock = NO;
    CASCCDExposureType exposureType;
    
    const CGFloat targetFloatAverage = 0.5;
    const CGFloat targetFloatAverageTolerance = 0.1;

    __block BOOL saveExposure = YES;
    __block float exposureTime;
    __block NSInteger exposureUnits;
    __block NSMutableArray* exposures = [NSMutableArray arrayWithCapacity:self.model.captureCount];

    switch (self.model.captureMode) {
        case kCASCaptureModelModeDark:
            exposureUnits = 0; // seconds
            exposureTime = self.model.exposureSeconds;
            temperatureLock = YES;
            exposureType = kCASCCDExposureDarkType;
            break;
        case kCASCaptureModelModeBias:
            exposureUnits = 0; // seconds
            exposureTime = 0;
            temperatureLock = YES;
            exposureType = kCASCCDExposureBiasType;
            break;
        case kCASCaptureModelModeFlat:
            exposureUnits = 1; // milliseconds
            exposureTime = 1000;
            temperatureLock = NO;
            exposureType = kCASCCDExposureFlatType;
            break;
        default:
            NSLog(@"*** Unknown capture mode: %ld",self.model.captureMode);
            return;
    }
    
    // save/clear sink
    id<CASCameraControllerSink> savedSink = self.cameraController.sink;
    self.cameraController.sink = nil;
    
    void (^complete)() = ^(NSError*error,CASCCDExposure*exposure){
        self.cameraController.sink = savedSink;
        if (completion) completion(error,exposure);
    };

    void (^__block capture)(void) = ^(void) {
      
        if (_cancelled){
            complete(nil,nil);
            return;
        }
        
        self.cameraController.settings.continuous = NO;
        self.cameraController.settings.captureCount = 1;
        self.cameraController.settings.exposureDuration = exposureTime;
        self.cameraController.settings.exposureUnits = exposureUnits;
        self.cameraController.settings.binning = 1;
        self.cameraController.settings.subframe = CGRectZero;
        self.cameraController.guider = nil;
        self.cameraController.temperatureLock = temperatureLock;
        self.cameraController.settings.exposureType = exposureType;
        self.cameraController.settings.ditherEnabled = NO;
        
        [self.cameraController captureWithBlock:^(NSError *error,CASCCDExposure* exposure) {
            
            if (error){
                complete(error,nil);
            }
            else{
                
                // if we're processing flats, adjust the exposure to get around 50% average pixel value
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
                    else if (average >= targetFloatAverage-targetFloatAverageTolerance && average <= targetFloatAverage+targetFloatAverageTolerance) {
                        saveExposure = YES; // nope, good enough
                    }
                    else {
                        exposureTime *= (targetFloatAverage/average);
                    }
                    NSLog(@"Flats: average of %f, now using exposure of %fs",average,exposureTime);
                    
                    // todo; check the exposure time doesn't vary too much, this might happen if the intensity of the light source for the flat changes
                    // once we've started saving exposures we should probably reduce the tolerance ?
                    // alternatively, scale before averaging all the flats to match the first one ?
                }
                
                if (!saveExposure) {
                    [self.exposuresController removeObjects:@[exposure]]; // cameraController will have saved it to the library so we need to remove it again
                    dispatch_async(dispatch_get_current_queue(), capture);
                }
                else{
                
                    // add the exposure
                    [exposures addObject:exposure];
                    
                    // check to see if we're done
                    if ([exposures count] < self.model.captureCount){
                        
                        if (progress) progress(exposure,NO);
                        dispatch_async(dispatch_get_current_queue(), capture);
                    }
                    else {
                        
                        // if we've hit the required number, process the accumulated exposures

                        NSLog(@"Completed %ld exposures",[exposures count]);

                        if (self.model.combineMode == kCASCaptureModelCombineNone){
                            if (progress) progress(exposure,NO);
                            complete(nil,nil);
                        }
                        else {
                            
                            if (self.model.combineMode == kCASCaptureModelCombineAverage && self.model.captureCount > 1){
                                
                                CASBatchProcessor* processor = [CASBatchProcessor batchProcessorsWithIdentifier:@"combine.average"];
                                
                                // match autosave flags
                                processor.autoSave = NO;
                                
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
                                            // todo; save normalised flat data to its exposure bundle
                                        }
                                        
                                        // run completion on the main thread
                                        dispatch_async(dispatch_get_main_queue(), ^{
                                            
                                            if (error){
                                                [NSApp presentError:error];
                                            }
                                            else {
                                                if (!self.model.keepOriginals){
                                                    [self.exposuresController removeObjects:exposures];
                                                }
                                            }
                                            complete(error,result);
                                        });
                                    }];
                                });
                            }
                            else {
                                complete(nil,nil);
                            }
                        }
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
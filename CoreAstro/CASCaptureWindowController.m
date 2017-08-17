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
#import "CASProgressWindowController.h"

#import <CoreAstro/CoreAstro.h>

@interface CASCaptureController : NSObject

@property (nonatomic,strong) CASCaptureModel* model;
@property (nonatomic,weak) CASCameraController* cameraController;
@property (nonatomic,strong) CASImageProcessor* imageProcessor;
@property (nonatomic,strong) CASExposuresController* exposuresController;
@property (nonatomic,readonly) BOOL cancelled;

- (void)cancelCapture;
- (void)captureWithProgressBlock:(void(^)(CASCCDExposure* exposure,BOOL postProcessing))progress completion:(void(^)(NSError* error,CASCCDExposure* result))completion;

+ (CASCaptureController*)captureControllerWithWindowController:(CASCaptureWindowController*)cwc;

@end

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
@property (nonatomic,strong) CASCaptureController* captureController;
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

- (void)presentRelativeToWindow:(NSWindow*)window
{
    BOOL (^saveExposure)() = ^BOOL(CASCCDExposure* exposure){
        return [self.delegate captureWindow:self didCapture:exposure mode:self.model.captureMode];
    };
    
    [self beginSheetModalForWindow:window completionHandler:^(NSInteger result) {
        
        if (result == NSOKButton){
            
            self.captureController = [CASCaptureController captureControllerWithWindowController:self];
            if (self.captureController){
                
                CASProgressWindowController* progress = [CASProgressWindowController createWindowController];
                [progress beginSheetModalForWindow:window];
                [progress configureWithRange:NSMakeRange(0, self.captureController.model.captureCount) label:NSLocalizedString(@"Capturing...", @"Progress sheet label")];
                progress.canCancel = YES;
                progress.cancelBlock = ^(){
                    [self.captureController cancelCapture];
                };
                
                self.captureController.imageProcessor = self.imageProcessor;
                self.captureController.cameraController = self.cameraController;
                
                // self.cameraController pushExposureSettings
                
                __block BOOL inPostProcessing = NO;
                
                // disable sleep
                [CASPowerMonitor sharedInstance].disableSleep = YES;
                
                [self.captureController captureWithProgressBlock:^(CASCCDExposure* exposure,BOOL postProcessing) {
                    
                    dispatch_async(dispatch_get_main_queue(), ^{
                        
                        // check the cancelled flag as set in the progress window controller
                        if (progress.cancelled){
                            [self.captureController cancelCapture];
                        }
                        
                        if (postProcessing && !inPostProcessing){
                            inPostProcessing = YES;
                            [progress configureWithRange:NSMakeRange(0, self.captureController.model.captureCount) label:NSLocalizedString(@"Combining...", @"Progress sheet label")];
                        }
                        if (self.captureController.model.combineMode == kCASCaptureModelCombineNone){
                            saveExposure(exposure);
                        }
                        progress.progressBar.doubleValue++;
                    });
                    
                } completion:^(NSError *error,CASCCDExposure* result) {
                    
                    // restore sleep setting
                    [CASPowerMonitor sharedInstance].disableSleep = NO;
                    
                    if (error){
                        [NSApp presentError:error];
                    }
                    else if (result) {
                        if (!self.captureController.cancelled){
                            saveExposure(result);
                        }
                    }
                    
                    [progress endSheetWithCode:NSOKButton];
                    
                    [self.delegate captureWindowDidComplete:self];
                    
                    // self.cameraController popExposureSettings
                }];
            }
        }
    }];
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
    
    const CGFloat targetFloatAverage = 0.33;
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
        self.cameraController.settings.subframe = CGRectZero;
        self.cameraController.guider = nil;
        self.cameraController.temperatureLock = temperatureLock;
        self.cameraController.settings.exposureType = exposureType;
        self.cameraController.settings.ditherEnabled = NO;
        self.cameraController.settings.startGuiding = NO;
        
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
                    
                    if (saveExposure && exposureTime < 1000) {
                        
                        NSString* const flatsWarningKey = @"SXIOSuppressFlatsWarning";
                        if (![[NSUserDefaults standardUserDefaults] boolForKey:flatsWarningKey]){
                            
                            NSAlert* alert = [NSAlert alertWithMessageText:@"Short Exposure"
                                                             defaultButton:@"OK"
                                                           alternateButton:nil
                                                               otherButton:nil
                                                 informativeTextWithFormat:@"Exposures of less than 1s or so can result in artefacts on the calibration frame. Consider lowering the intensity of the light source in order to increase the exposure time."];
                            
                            alert.showsSuppressionButton = YES;
                            
                            [alert runModal];
                            
                            if ([[alert suppressionButton] state]){
                                [[NSUserDefaults standardUserDefaults] setBool:YES forKey:flatsWarningKey];
                            }
                        }
                    }
                }
                
                if (!saveExposure) {
                    [self.exposuresController removeObjects:@[exposure]]; // cameraController will have saved it to the library so we need to remove it again
                    dispatch_async(dispatch_get_main_queue(), capture);
                }
                else {
                
                    // add the exposure
                    if (exposure){
                        [exposures addObject:exposure];
                    }
                    else {
                        if (_cancelled){
                            complete(nil,nil);
                            return;
                        }
                    }
                    
                    // check to see if we're done
                    if ([exposures count] < self.model.captureCount){
                        
                        if (progress) progress(exposure,NO);
                        dispatch_async(dispatch_get_main_queue(), capture);
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

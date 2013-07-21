//
//  SXIOCameraWindowController.m
//  SX IO
//
//  Created by Simon Taylor on 7/21/13.
//  Copyright (c) 2013 Simon Taylor. All rights reserved.
//

#import "SXIOCameraWindowController.h"

#import "CASExposureView.h"
#import "CASCameraControlsViewController.h"
#import "SXIOSaveTargetViewController.h"

@interface CASControlsContainerView : NSView
@end
@implementation CASControlsContainerView
@end

@interface SXIOCameraWindowController ()

@property (weak) IBOutlet CASControlsContainerView *controlsContainerView;
@property (weak) IBOutlet CASExposureView *exposureView;
@property (weak) IBOutlet NSTextField *progressStatusText;
@property (weak) IBOutlet NSProgressIndicator *progressIndicator;
@property (weak) IBOutlet NSButton *captureButton;

@property (nonatomic,strong) CASCCDExposure *currentExposure;
@property (strong) SXIOSaveTargetViewController *saveTargetControlsViewController;
@property (strong) CASCameraControlsViewController *cameraControlsViewController;

@end

@implementation SXIOCameraWindowController

- (void)windowDidLoad
{
    [super windowDidLoad];
    
    // slot the camera controls into the controls container view todo; make this layout code part of the container view or its controller
    self.cameraControlsViewController = [[CASCameraControlsViewController alloc] initWithNibName:@"CASCameraControlsViewController" bundle:nil];
    self.cameraControlsViewController.view.translatesAutoresizingMaskIntoConstraints = NO;
    [self.controlsContainerView addSubview:self.cameraControlsViewController.view];
    
    // layout camera controls
    id cameraControlsViewController1 = self.cameraControlsViewController.view;
    NSDictionary* viewNames = NSDictionaryOfVariableBindings(cameraControlsViewController1);
    [self.controlsContainerView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|[cameraControlsViewController1]|" options:0 metrics:nil views:viewNames]];
    [self.controlsContainerView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|[cameraControlsViewController1(==height)]" options:NSLayoutFormatAlignAllCenterX metrics:@{@"height":@(self.cameraControlsViewController.view.frame.size.height)} views:viewNames]];
    
    // save target controls
    self.saveTargetControlsViewController = [[SXIOSaveTargetViewController alloc] initWithNibName:@"SXIOSaveTargetViewController" bundle:nil];
    self.saveTargetControlsViewController.view.translatesAutoresizingMaskIntoConstraints = NO;
    [self.controlsContainerView addSubview:self.saveTargetControlsViewController.view];
    
    // save target controls
    id saveTargetControlsViewController1 = self.saveTargetControlsViewController.view;
    viewNames = NSDictionaryOfVariableBindings(cameraControlsViewController1,saveTargetControlsViewController1);
    [self.controlsContainerView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|[saveTargetControlsViewController1]|" options:0 metrics:nil views:viewNames]];
    [self.controlsContainerView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|[cameraControlsViewController1][saveTargetControlsViewController1(==height)]" options:NSLayoutFormatAlignAllCenterX metrics:@{@"height":@(self.saveTargetControlsViewController.view.frame.size.height)} views:viewNames]];
    
    [self.cameraControlsViewController bind:@"cameraController" toObject:self withKeyPath:@"cameraController" options:nil];
    [self.cameraControlsViewController bind:@"exposure" toObject:self withKeyPath:@"currentExposure" options:nil];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if (context == (__bridge void *)(self)) {
        
        if (object == self.cameraController){
            if ([keyPath isEqualToString:@"state"] || [keyPath isEqualToString:@"progress"]){
                [self updateExposureIndicator];
            }
        }
        else if (object == self.exposureView){
            if ([keyPath isEqualToString:@"showSelection"]){
                if (self.exposureView.showSelection){
//                    self.selectionControl.selectedSegment = 0;
                }
                else {
//                    self.selectionControl.selectedSegment = 1;
                }
            }
        }
        else if (object == [CASDeviceManager sharedManager]) {
            
//            if ([keyPath isEqualToString:@"filterWheelControllers"]){
//                
//                switch ([change[NSKeyValueChangeKindKey] integerValue]) {
//                    case NSKeyValueChangeInsertion:
//                        [self showFilterWheelControls];
//                        break;
//                    case NSKeyValueChangeRemoval:
//                        [self hideFilterWheelControls];
//                        break;
//                }
//            }
        }
    }
    else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}


- (void)setCameraController:(CASCameraController *)cameraController
{
    if (_cameraController != cameraController){
        if (_cameraController){
            [_cameraController removeObserver:self forKeyPath:@"state" context:(__bridge void *)(self)];
            [_cameraController removeObserver:self forKeyPath:@"progress" context:(__bridge void *)(self)];
        }
        _cameraController = cameraController;
        if (_cameraController){
            [_cameraController addObserver:self forKeyPath:@"state" options:0 context:(__bridge void *)(self)];
            [_cameraController addObserver:self forKeyPath:@"progress" options:0 context:(__bridge void *)(self)];
        }
        [self configureForCameraController];
    }
}

- (IBAction)capture:(NSButton*)sender
{
    // check we have somewhere to save the file, a prefix and a sequence number
    
    // capture the current controller and continuous flag in the completion block
    CASCameraController* cameraController = self.cameraController;
    
    // do not save to the library
    cameraController.autoSave = NO;
    
    // issue the capture command
    [cameraController captureWithBlock:^(NSError *error,CASCCDExposure* exposure) {
        
        if (error){
            // todo; run completion actions e.g. email, run processing scripts, etc
            [NSApp presentError:error];
        }
        else{
            
            // check it's the still the currently displayed camera before displaying the exposure
            if (exposure){
                
                NSURL* url = [NSURL fileURLWithPath:[[NSUserDefaults standardUserDefaults] stringForKey:kSaveFolderURLDefaultsKey]];
                NSString* prefix = [[NSUserDefaults standardUserDefaults] stringForKey:kSavedImagePrefixDefaultsKey];
                if (!prefix){
                    prefix = @"image";
                }
                const NSInteger sequence = [[NSUserDefaults standardUserDefaults] integerForKey:kSavedImageSequenceDefaultsKey];
                prefix = [prefix stringByAppendingFormat:@"-%ld",sequence];
                url = [url URLByAppendingPathComponent:prefix];
                url = [url URLByAppendingPathExtension:@"fits"];
                [[NSUserDefaults standardUserDefaults] setInteger:sequence+1 forKey:kSavedImageSequenceDefaultsKey];
                
                CASCCDExposureIO* io = [CASCCDExposureIO exposureIOWithPath:[url path]];
                if (!io){
                    NSLog(@"*** Failed to create FITS exporter");
                }
                else {
                    NSError* error = nil;
                    [io writeExposure:exposure writePixels:YES error:&error];
                    if (error){
                        dispatch_async(dispatch_get_main_queue(), ^{
                            [NSApp presentError:error];
                        });
                    }
                }
                
                // save to the designated folder with the current settings as a fits file
                
                if (cameraController == self.cameraController){
                    self.currentExposure = exposure;
                }
            }
        }
    }];
}

- (void)configureForCameraController
{
    NSString* title = self.cameraController.camera.deviceName;
    if (title){
        self.window.title = title;
    }
    else {
        self.window.title = @"";
    }
    
//    // show camera name
//    self.imageBannerView.camera = self.cameraController.camera;
    
    // capture the current controller in the completion block
    CASCameraController* cameraController = self.cameraController;
    
    if (!cameraController){
        
        self.currentExposure = nil;
    }
    else {
        
        // set the current displayed exposure to the last one recorded by this camera controller
        // (specifically check for pixels as this will detect if the backing store has been deleted)
        if (self.cameraController.lastExposure.pixels){
            self.currentExposure = self.cameraController.lastExposure;
        }
        else{
            self.currentExposure = nil;
        }
        
        // if there's no exposure, create a placeholder image
        if (!self.currentExposure){
            
            const CGSize size = CGSizeMake(self.cameraController.camera.sensor.width, self.cameraController.camera.sensor.height);
            CGContextRef bitmap = [CASCCDImage newBitmapContextWithSize:CASSizeMake(size.width, size.height) bitsPerPixel:16];
            if (bitmap){
                CGContextSetRGBFillColor(bitmap,0.35,0.35,0.35,1);
                CGContextFillRect(bitmap,CGRectMake(0, 0, size.width, size.height));
                CGImageRef CGImage = CGBitmapContextCreateImage(bitmap);
                if (CGImage){
                    [self.exposureView setCGImage:CGImage];
                    CGImageRelease(CGImage);
                }
                CGContextRelease(bitmap);
            }
        }
        
        [self.cameraController connect:^(NSError *error) {
            
            if (error){
                [NSApp presentError:error];
            }
        }];
    }
    
    //    // reset the capture count - why am I doing this here ?
    //    if (!self.cameraController.captureCount && !self.cameraController.continuous){
    //        self.cameraController.captureCount = 1; // no, reset to the number of exposures selected in the UI...
    //    }
    
    // set progress display if this camera is capturing
    [self updateExposureIndicator];
    
    // set the exposures controller to either nil or one that shows only exposures from this camera
//    self.exposuresController = nil;
}

- (void)updateExposureIndicator
{
    void (^commonShowProgressSetup)(NSString*,BOOL) = ^(NSString* statusText,BOOL showIndicator){
        
        // todo; tidy this interface up
//        self.exposureView.showProgress = showIndicator;
//        self.exposureView.progressInterval = self.cameraController.exposureUnits ? self.cameraController.exposure/1000 : self.cameraController.exposure;
        
        self.progressIndicator.hidden = NO;
        self.progressIndicator.indeterminate = NO;
        self.progressStatusText.stringValue = statusText ? statusText : @"";
    };
    
    switch (self.cameraController.state) {
            
        case CASCameraControllerStateNone:{
            self.exposureView.showProgress = NO;
            self.progressIndicator.hidden = YES;
            self.progressStatusText.stringValue = @"";
        }
            break;
            
        case CASCameraControllerStateWaitingForTemperature:{
            commonShowProgressSetup(@"Waiting for °C...",NO);
        }
            break;
            
        case CASCameraControllerStateWaitingForNextExposure:{
            commonShowProgressSetup(@"Waiting...",NO);
        }
            break;
            
        case CASCameraControllerStateExposing:{
            commonShowProgressSetup(nil,YES);
            if (self.cameraController.progress >= 1){
                self.progressIndicator.indeterminate = YES;
                self.progressStatusText.stringValue = @"Downloading image...";
            }
            else {
                self.progressStatusText.stringValue = @"Capturing...";
            }
        }
            break;
    }
    
    self.exposureView.progress = self.progressIndicator.doubleValue = self.cameraController.progress;
    
    if (self.cameraController.capturing){
        self.captureButton.title = NSLocalizedString(@"Cancel", @"Button title");
        self.captureButton.action = @selector(cancelCapture:);
        self.captureButton.keyEquivalent = @"";
    }
    else {
        self.captureButton.title = NSLocalizedString(@"Capture", @"Button title");
        self.captureButton.action = @selector(capture:);
        self.captureButton.keyEquivalent = [NSString stringWithFormat:@"%c",NSCarriageReturnCharacter];
        self.captureButton.enabled = YES; // set to NO in -cancelCapture:
    }
}

- (void)displayExposure:(CASCCDExposure*)exposure
{
    if (!exposure){
        self.exposureView.currentExposure = nil;
        return;
    }
        
    // check image view is actually visible before bothering to display it
    if (!self.exposureView.isHiddenOrHasHiddenAncestor){
        
        // get the current exposure (need an accessor for this)
//        CASCCDExposure* parentExposure = exposure;
        
        // prefer corrected exposure (and similarly for debayered)
        CASCCDExposure* corrected = exposure.correctedExposure;
        if (corrected){
            exposure = corrected;
        }
        CASCCDExposure* debayered = exposure.debayeredExposure;
        if (debayered){
            exposure = debayered;
        }
        
        static NSDateFormatter* exposureFormatter = nil;
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            exposureFormatter = [[NSDateFormatter alloc] init];
            [exposureFormatter setDateStyle:NSDateFormatterMediumStyle];
            [exposureFormatter setTimeStyle:NSDateFormatterMediumStyle];
        });
        
//        // debayer if required
//        if (self.imageDebayer.mode != kCASImageDebayerNone){
//            CASCCDExposure* debayeredExposure = [self.imageDebayer debayer:exposure adjustRed:self.colourAdjustments.redAdjust green:self.colourAdjustments.greenAdjust blue:self.colourAdjustments.blueAdjust all:self.colourAdjustments.allAdjust];
//            if (debayeredExposure){
//                exposure = debayeredExposure;
//            }
//        }
        
        
//        if (self.equalise){
//            exposure = [self.imageProcessor equalise:exposure];
//        }
//        
//        if (self.invert){
//            exposure = [self.imageProcessor invert:exposure];
//        }
        
        self.exposureView.currentExposure = exposure;
        
    }
}

- (void)clearSelection
{
//    self.selectionControl.selectedSegment = 1;
//    [self selection:self.selectionControl]; // yuk
}

- (void)setCurrentExposure:(CASCCDExposure *)currentExposure
{
    if (_currentExposure != currentExposure){
        
        // unload the current exposure's pixels
        [_currentExposure reset];
        
        _currentExposure = currentExposure;
        
        // display the exposure
        [self displayExposure:_currentExposure];
        
        // clear selection - necessary ?
        if (!_currentExposure){
            [self clearSelection];
        }
    }
}

@end

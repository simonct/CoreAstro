//
//  CASCameraWindowController.m
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
//  Todo: split this up into view controllers, do less in -windowDidLoad 

#import "CASCameraWindowController.h"
#import "CASAppDelegate.h" // hmm, dragging the delegate in...
#import "CASExposuresController.h"
#import "CASProgressWindowController.h"
#import "CASCaptureWindowController.h"
#import "CASExposureView.h"
#import "CASShadowView.h"
#import "CASMasterSelectionView.h"
#import "CASLibraryBrowserViewController.h"

#import <Quartz/Quartz.h>
#import <CoreAstro/CoreAstro.h>

@interface CASImageBannerView : NSView
@property (nonatomic,weak) IBOutlet NSTextField *dateField;
@property (nonatomic,weak) IBOutlet NSTextField *cameraNameField;
@property (nonatomic,weak) CASCCDExposure* exposure;
@property (nonatomic,weak) CASCCDDevice* camera;
@end

@implementation CASImageBannerView

- (void)drawRect:(NSRect)rect {
    
    const CGRect bounds = self.bounds;
    
    [[[NSGradient alloc] initWithColorsAndLocations:
      [NSColor colorWithDeviceWhite:0.25f alpha:1.0f], 0.0f,
      [NSColor colorWithDeviceWhite:0.29f alpha:1.0f], 0.5f,
      [NSColor colorWithDeviceWhite:0.30f alpha:1.0f], 0.5f,
      [NSColor colorWithDeviceWhite:0.35f alpha:1.0f], 1.0f,
      nil] drawInRect:bounds angle:90.0f];
    
    [[NSColor blackColor] set];
    NSFrameRect(CGRectOffset(CGRectInset(bounds, -1, 0), 0, 2.5));
}

- (void)setExposure:(CASCCDExposure *)exposure
{
    _camera = nil;
    _exposure = exposure;
    self.cameraNameField.stringValue = exposure.displayName ? exposure.displayName : @"";
    self.dateField.stringValue = exposure.displayDate ? exposure.displayDate : @"";
}

- (void)setCamera:(CASCCDDevice *)camera
{
    _camera = camera;
    _exposure = nil;
    self.cameraNameField.stringValue = camera.deviceName ? camera.deviceName : @"";
    self.dateField.stringValue = @"";
}

@end

#pragma IB Convenience Classes

@interface CASGuidersArrayController : NSArrayController
@end
@implementation CASGuidersArrayController
@end

@interface CASCamerasArrayController : NSArrayController
@end
@implementation CASCamerasArrayController
@end

#pragma Colour adjustments

@interface CASColourAdjustments : NSObject
@property (nonatomic,assign) float redAdjust, greenAdjust, blueAdjust, allAdjust;
@end

@implementation CASColourAdjustments

- (id)init
{
    self = [super init];
    if (self) {
        self.allAdjust = self.redAdjust = self.greenAdjust = self.blueAdjust = 1;
    }
    return self;
}

@end

#pragma Camera Window

@interface CASCameraWindowController ()<CASMasterSelectionViewDelegate,CASLibraryBrowserViewControllerDelegate,CASExposureViewDelegate>
@property (nonatomic,assign) BOOL invert;
@property (nonatomic,assign) BOOL equalise;
@property (nonatomic,assign) BOOL medianFilter;
@property (nonatomic,assign) BOOL showPlateSolution;
@property (nonatomic,assign) BOOL showHistogram;
@property (nonatomic,assign) BOOL enableGuider;
@property (nonatomic,assign) BOOL scaleSubframe;
@property (nonatomic,assign) BOOL recordAsVideo;
@property (nonatomic,assign) NSInteger debayerMode;
@property (nonatomic,strong) CASCCDExposure* currentExposure;
@property (nonatomic,strong) NSLayoutConstraint* detailLeadingConstraint;
@property (nonatomic,strong) CASImageProcessor* imageProcessor;
@property (nonatomic,strong) CASGuideAlgorithm* guideAlgorithm;
@property (nonatomic,strong) CASImageDebayer* imageDebayer;
@property (nonatomic,weak) IBOutlet NSTextField *exposuresStatusText;
@property (nonatomic,weak) IBOutlet NSPopUpButton *captureMenu;
@property (nonatomic,weak) IBOutlet NSPopUpButton *guiderMenu;
@property (nonatomic,assign) NSUInteger captureMenuSelectedIndex;
@property (nonatomic,strong) CASLibraryBrowserViewController* libraryViewController;
@property (nonatomic,strong) CASColourAdjustments* colourAdjustments;
@property (nonatomic,readonly) CASCCDExposureLibrary* library;
@property (nonatomic,strong) CASExposuresController *libraryExposuresController;
@property (nonatomic,strong) CASExposuresController *exposuresController;
@property (nonatomic,weak) IBOutlet NSView *guideControlsContainer;
@property (nonatomic,assign) NSInteger guidePulseDuration;
@property (nonatomic,strong) CASPlateSolver* plateSolver;
@property (nonatomic,strong) CASCaptureWindowController* captureWindowController;
@property (nonatomic,strong) CASCaptureController* captureController;
@property (nonatomic,weak) IBOutlet NSTextField *measuredTemperatureField;
@property (nonatomic,weak) IBOutlet NSTextField *measuredTemperatureLabel;
@property (nonatomic,weak) IBOutlet NSButton *libraryBackButton;
@property (nonatomic,strong) NSArray *libraryBackButtonConstraints;
@end

@interface CASCameraWindow : NSWindow
@end

@implementation CASCameraWindow
@end

@implementation CASCameraWindowController

- (void)windowDidLoad
{
    [super windowDidLoad];
    
    self.showPlateSolution = YES;

    self.colourAdjustments = [[CASColourAdjustments alloc] init];
    
    self.imageDebayer = [CASImageDebayer imageDebayerWithIdentifier:nil];
    self.imageProcessor = [CASImageProcessor imageProcessorWithIdentifier:nil];
    self.guideAlgorithm = [CASGuideAlgorithm guideAlgorithmWithIdentifier:nil];
    
    [[NSApp delegate] addObserver:self forKeyPath:@"guiderControllers" options:NSKeyValueObservingOptionNew|NSKeyValueObservingOptionOld|NSKeyValueObservingOptionInitial context:(__bridge void *)(self)];
    
    self.exposuresController = [[CASExposuresController alloc] init];
    self.libraryExposuresController = self.exposuresController;

    CGColorRef gray = CGColorCreateGenericRGB(128/255.0, 128/255.0, 128/255.0, 1); // match to self.imageView.backgroundColor ?
    self.imageView.layer.backgroundColor = gray;
    CGColorRelease(gray);
    
    NSButton* close = [self.window standardWindowButton:NSWindowCloseButton];
    [close setTarget:self];
    [close setAction:@selector(hideWindow:)];
    
    self.imageView.exposureViewDelegate = self;
    self.imageView.imageProcessor = self.imageProcessor;
    self.imageView.guideAlgorithm = self.guideAlgorithm;
    
    [self.imageView addObserver:self forKeyPath:@"showSelection" options:NSKeyValueObservingOptionInitial|NSKeyValueObservingOptionNew|NSKeyValueObservingOptionOld context:(__bridge void *)(self)];
    
    self.toolbar.displayMode = NSToolbarDisplayModeIconOnly;

    // remove the leading constraints from IB (still needed?)
    NSMutableSet* constraints = [NSMutableSet setWithCapacity:2];
    for (NSLayoutConstraint* constraint in [self.detailContainerView constraintsAffectingLayoutForOrientation:0]){
        if (constraint.firstAttribute == NSLayoutAttributeLeading){
            [constraints addObject:constraint];
        }
    }
    if ([constraints count]){
        [self.detailContainerView.superview removeConstraints:[constraints allObjects]];
    }
    
    // add a customisable constraint so that we can show/hide the master selection view
    id detailContainerView1 = self.detailContainerView;
    NSDictionary* viewNames = NSDictionaryOfVariableBindings(detailContainerView1);
    self.detailLeadingConstraint = [[NSLayoutConstraint constraintsWithVisualFormat:@"|-0-[detailContainerView1]-|" options:NSLayoutFormatAlignAllCenterY metrics:nil views:viewNames] objectAtIndex:0];
    [self.window.contentView addConstraints:[NSArray arrayWithObject:self.detailLeadingConstraint]];
    
    // add a drop shadow
    [CASShadowView attachToView:self.detailContainerView edge:NSMinXEdge];
    [CASShadowView attachToView:self.imageBannerView.superview edge:NSMaxXEdge];

    // listen for guide notifications
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(guideCommandNotification:) name:kCASCameraControllerGuideCommandNotification object:nil];
    
    // listen for master selection changes
    self.devicesTableView.masterViewDelegate = (id)self;
    self.devicesTableView.camerasContainer = [NSApp delegate];
    
    // set up the guider controls
    self.guidePulseDuration = 250;
    self.guideControlsContainer.hidden = YES;
    
    // set up the Back button
    [self configureLibraryBackButton];
    
    // all done, bind the exposures controller
    [self.exposuresController bind:@"contentArray" toObject:self withKeyPath:@"library.exposures" options:nil];
}

- (void)hideWindow:sender
{
    [self.window orderOut:nil]; 
    
    // still removed from windows menu...
}

- (void)windowWillClose:(NSNotification *)notification
{
    if ([self.delegate respondsToSelector:@selector(cameraWindowWillClose:)]){
        [self.delegate cameraWindowWillClose:self];
    }
}

- (CASCCDExposureLibrary*)library
{
    return [CASCCDExposureLibrary sharedLibrary];
}

- (void)setCameraController:(CASCameraController *)cameraController
{
    if (_cameraController != cameraController){
        if (_cameraController){
            [_cameraController removeObserver:self forKeyPath:@"exposureStart" context:(__bridge void *)(self)];
            [_cameraController removeObserver:self forKeyPath:@"capturing" context:(__bridge void *)(self)];
        }
        _cameraController = cameraController;
        if (_cameraController){
            [_cameraController addObserver:self forKeyPath:@"exposureStart" options:0 context:(__bridge void *)(self)];
            [_cameraController addObserver:self forKeyPath:@"capturing" options:0 context:(__bridge void *)(self)];
        }
        [self configureForCameraController];
    }
}

- (void)setExposuresController:(CASExposuresController *)exposuresController
{
    if (exposuresController != _exposuresController){
        
        [_exposuresController removeObserver:self forKeyPath:@"selectedObjects" context:(__bridge void *)(self)];
        [_exposuresController removeObserver:self forKeyPath:@"arrangedObjects" context:(__bridge void *)(self)];
        
        _exposuresController = exposuresController;
        
        [_exposuresController addObserver:self forKeyPath:@"selectedObjects" options:0 context:(__bridge void *)(self)];
        [_exposuresController addObserver:self forKeyPath:@"arrangedObjects" options:0 context:(__bridge void *)(self)];
    }
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

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if (context == (__bridge void *)(self)) {
        
        if (object == self.exposuresController){
            if ([keyPath isEqualToString:@"selectedObjects"]){
                self.currentExposure = [[self.exposuresController selectedObjects] lastObject];
            }
        }
        else if (object == self.cameraController){
            if ([keyPath isEqualToString:@"exposureStart"]){
                [self updateExposureIndicator];
            }
            if ([keyPath isEqualToString:@"capturing"]){
                if (!self.cameraController.capturing){
                    self.progressStatusText.hidden = self.progressIndicator.hidden = YES;
                    self.imageView.showProgress = NO;
                    self.captureButton.title = NSLocalizedString(@"Capture", @"Button title");
                    self.captureButton.action = @selector(capture:);
                    self.captureButton.enabled = YES;
                    self.captureButton.keyEquivalent = [NSString stringWithFormat:@"%c",NSCarriageReturnCharacter];
                }
                else {
                    self.progressStatusText.stringValue = @"Capturing...";
                    self.captureButton.title = NSLocalizedString(@"Cancel", @"Button title");
                    self.captureButton.action = @selector(cancelCapture:);
                    self.captureButton.keyEquivalent = @"";
                }
            }
        }
        else if (object == [NSApp delegate]){
            if ([keyPath isEqualToString:@"guiderControllers"]){
                [self updateGuiderMenu];
                // guider came or went
//                NSLog(@"%@: %@ -> %@",object,keyPath,[object valueForKeyPath:keyPath]);
//                NSLog(@"%@: %@",object,change);
                // add, kind == 2 (NSKeyValueChangeInsertion)
                // remove, kind == 3 (NSKeyValueChangeRemoval)
            }
        }
        else if (object == self.imageView){
            if ([keyPath isEqualToString:@"showSelection"]){
                if (self.imageView.showSelection){
                    self.selectionControl.selectedSegment = 0;
                }
                else {
                    self.selectionControl.selectedSegment = 1;
                }
            }
        }
    }
    else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
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
    
    [self.sensorSizeField setStringValue:@""];
    [self.sensorPixelsField setStringValue:@""];

    // show camera name
    self.imageBannerView.camera = self.cameraController.camera;

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
                    [self.imageView setCGImage:CGImage];
                    CGImageRelease(CGImage);
                }
                CGContextRelease(bitmap);
            }
        }
        
        [self.cameraController connect:^(NSError *error) {
            
            if (error){
                [NSApp presentError:error];
            }
            else {
                
                // check it's the same camera...
                if (self.cameraController == cameraController){
                    
                    CASCCDDevice* camera = self.cameraController.camera;
                    
                    [self.sensorSizeField setStringValue:[NSString stringWithFormat:@"%ld x %ld",camera.sensor.width,camera.sensor.height]];
                    [self.sensorPixelsField setStringValue:[NSString stringWithFormat:@"%0.2fµm x %0.2fµm",camera.sensor.pixelWidth,camera.sensor.pixelHeight]];
                }
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
    self.exposuresController = nil;
}

- (void)_resetAndRedisplayCurrentExposure
{
    if (self.currentExposure){
        [self.currentExposure reset];
        [[self.exposuresController arrangedObjects] makeObjectsPerformSelector:@selector(reset)]; // reset all
        [self displayExposure:self.currentExposure];
    }
}

- (void)setEqualise:(BOOL)equalise
{
    if (_equalise != equalise){
        _equalise = equalise;
        [self _resetAndRedisplayCurrentExposure];
    }
}

- (void)setMedianFilter:(BOOL)medianFilter
{
    if (_medianFilter != medianFilter){
        _medianFilter = medianFilter;
        [self _resetAndRedisplayCurrentExposure];
    }
}

- (void)setShowPlateSolution:(BOOL)showPlateSolution
{
    if (_showPlateSolution != showPlateSolution){
        _showPlateSolution = showPlateSolution;
        [self _resetAndRedisplayCurrentExposure];
    }
}

- (NSInteger)debayerMode
{
    return self.imageDebayer.mode;
}

- (void)setDebayerMode:(NSInteger)debayerMode
{
    if (self.imageDebayer.mode != debayerMode){
        self.imageDebayer.mode = debayerMode;
        [self _resetAndRedisplayCurrentExposure];
    }
}

- (void)setInvert:(BOOL)invert
{
    if (invert != _invert){
        _invert = invert;
        [self _resetAndRedisplayCurrentExposure];
    }
}

- (void)setCaptureMenuSelectedIndex:(NSUInteger)index
{
    if (_captureMenuSelectedIndex != index){
        _captureMenuSelectedIndex = index;
        if (self.cameraController.continuous){
            self.cameraController.captureCount = 0;
        }
        else {
            
            // tmp - probably replace with a different control style
            switch (_captureMenuSelectedIndex) {
                case 0:
                case 1:
                case 2:
                case 3:
                case 4:
                    self.cameraController.captureCount = _captureMenuSelectedIndex + 1;
                    break;
                case 5:
                    self.cameraController.captureCount = 10;
                    break;
                case 6:
                    self.cameraController.captureCount = 25;
                    break;
                case 7:
                    self.cameraController.captureCount = 50;
                    break;
                case 8:
                    self.cameraController.captureCount = 75;
                    break;
                default:
                    self.cameraController.captureCount = 1;
                    NSLog(@"Unknown exposure index: %ld",_captureMenuSelectedIndex);
                    break;
            }
        }
    }
}

- (BOOL)showHistogram
{
    return self.imageView.showHistogram;
}

- (void)setShowHistogram:(BOOL)showHistogram
{
    self.imageView.showHistogram = showHistogram;
}

- (void)setEnableGuider:(BOOL)enableGuider
{
    _enableGuider = enableGuider;
    
    // hide/show guider overlay interface
    
    // switch to continuous mode and lock it, allow exposure duration to be changed (a todo in any case)
    
    // when capture is pressed, frames are fed into the guider and off it goes
}

- (BOOL)scaleSubframe
{
    return self.imageView.scaleSubframe;
}

- (void)setScaleSubframe:(BOOL)scaleSubframe
{
    self.imageView.scaleSubframe = scaleSubframe;
}

- (void)updateExposureIndicator
{
    NSDate* start = self.cameraController.exposureStart;
    if (self.cameraController.exposureStart){
        
        const double interval = [[NSDate date] timeIntervalSinceDate:start];
        const NSInteger scaling = (self.cameraController.exposureUnits == 0) ? 1 : 1000;
        
        self.imageView.showProgress = YES;
        self.imageView.progressInterval = self.cameraController.exposureUnits ? self.cameraController.exposure/1000 : self.cameraController.exposure;
        if (self.cameraController.exposure){
            self.imageView.progress = self.progressIndicator.doubleValue = (interval * scaling) / self.cameraController.exposure;
        }
        else {
            self.imageView.progress = self.progressIndicator.doubleValue = 0;;
        }
        
        self.progressIndicator.hidden = NO;
        if (self.progressIndicator.doubleValue >= self.progressIndicator.maxValue){
            self.progressIndicator.indeterminate = YES;
            self.progressStatusText.stringValue = @"Downloading image...";
            self.imageView.progress = 0;
        }
        else {
            self.progressIndicator.indeterminate = NO;
        }
        [self.progressIndicator startAnimation:self];
        [self performSelector:@selector(updateExposureIndicator) withObject:nil afterDelay:0.1 inModes:@[NSRunLoopCommonModes]];
    }
    else {
        
        if (self.cameraController.waitingForNextCapture){
            self.progressIndicator.indeterminate = NO;
            self.progressIndicator.hidden = NO;
            self.imageView.showProgress = YES;
            self.progressStatusText.stringValue = @"Waiting...";
            self.imageView.progressInterval = self.cameraController.interval;
            const double fraction = self.cameraController.interval ? (self.cameraController.continuousNextExposureTime - [NSDate timeIntervalSinceReferenceDate])/(double)self.cameraController.interval : 0;
            self.imageView.progress = fraction;
            self.progressIndicator.doubleValue = 1 - fraction;
            [self performSelector:@selector(updateExposureIndicator) withObject:nil afterDelay:0.1 inModes:@[NSRunLoopCommonModes]];
        }
        else {
            self.progressIndicator.hidden = YES;
            self.imageView.showProgress = NO;
            self.imageView.progress = self.progressIndicator.doubleValue = 0;
            [self.progressIndicator stopAnimation:self];
        }
    }
}

- (void)displayExposure:(CASCCDExposure*)exposure
{
    if (!exposure){
        self.imageView.currentExposure = nil;
        self.imageBannerView.camera = nil;
        self.exposureField.stringValue = self.sensorSizeField.stringValue = self.sensorPixelsField.stringValue = @"";
        return;
    }
    
    // set the banner exposure to display name, date, etc
    self.imageBannerView.exposure = exposure;

    // show the exposure specifics in the sidebar (todo; encapsulate sidebar and just set the exposure as with the banner)
    NSDictionary* params = [exposure.meta valueForKeyPath:@"device.params"];
    if (!params){
        self.exposureField.stringValue = self.sensorSizeField.stringValue = self.sensorPixelsField.stringValue = self.measuredTemperatureField.stringValue = @"";
    }
    else {
        
        self.sensorSizeField.stringValue = [NSString stringWithFormat:@"%@ x %@",
                                            [params valueForKeyPath:@"width"],
                                            [params valueForKeyPath:@"height"]];
        self.sensorPixelsField.stringValue = [NSString stringWithFormat:@"%0.2fµm x %0.2fµm",
                                              [[params valueForKeyPath:@"pixelWidth"] doubleValue],
                                              [[params valueForKeyPath:@"pixelHeight"] doubleValue]];
                
        NSUInteger ms = exposure.params.ms;
        if (!ms){
            self.exposureField.stringValue = @"";
            [self.exposureScalePopup selectItemAtIndex:0];
        }
        else {
            if (ms > 999){
                ms /= 1000;
                [self.exposureScalePopup selectItemAtIndex:0];
            }
            else {
                [self.exposureScalePopup selectItemAtIndex:1];
            }
            self.exposureField.stringValue = [NSString stringWithFormat:@"%ld",ms];
        }
        
        [self.binningRadioButtons selectCellAtRow:0 column:exposure.params.bin.width - 1];
        
        if (!exposure.isSubframe){
            self.subframeDisplay.stringValue = @"";
        }
        else {
            self.subframeDisplay.stringValue = [NSString stringWithFormat:@"x=%ld y=%ld\nw=%ld h=%ld",exposure.params.origin.x,exposure.params.origin.y,exposure.params.size.width,exposure.params.size.height];
        }
        
        // need to see how this interacts with a camera connected e.g. is this conflicting with bindings ?
        
        NSArray* temps = [exposure valueForKeyPath:@"meta.temperature.temperatures"];
        if ([temps count]){
            double avTemp = 0;
            for (NSNumber* temp in temps){
                avTemp += [temp doubleValue];
            }
            avTemp /= [temps count];
            self.measuredTemperatureLabel.hidden = self.measuredTemperatureField.hidden = NO;
            self.measuredTemperatureField.stringValue = [NSString stringWithFormat:@"%.1f",avTemp];
        }
        else {
            self.measuredTemperatureLabel.hidden = self.measuredTemperatureField.hidden = YES;
            self.measuredTemperatureField.stringValue = @"";
        }
    }

    // check image view is actually visible before bothering to display it
    if (!self.imageView.isHiddenOrHasHiddenAncestor){
        
        // get the current exposure (need an accessor for this)
        CASCCDExposure* parentExposure = exposure;
        
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
        
        // debayer if required
        if (self.imageDebayer.mode != kCASImageDebayerNone){
            CASCCDExposure* debayeredExposure = [self.imageDebayer debayer:exposure adjustRed:self.colourAdjustments.redAdjust green:self.colourAdjustments.greenAdjust blue:self.colourAdjustments.blueAdjust all:self.colourAdjustments.allAdjust];
            if (debayeredExposure){
                exposure = debayeredExposure;
            }
        }
        
        if (self.medianFilter){
            exposure = [self.imageProcessor medianFilter:exposure];
        }
        
        if (self.equalise){
            exposure = [self.imageProcessor equalise:exposure];
        }
        
        if (self.invert){
            exposure = [self.imageProcessor invert:exposure];
        }
        
        self.imageView.currentExposure = exposure;
        
        // optionally show the solution (note; using the *parent* exposure)
        if (self.showPlateSolution){
            self.imageView.plateSolveSolution = [[CASPlateSolver plateSolverWithIdentifier:nil] cachedSolutionForExposure:parentExposure];
        }
        else {
            self.imageView.plateSolveSolution = nil;
        }
    }
}

- (void)clearSelection
{
    self.selectionControl.selectedSegment = 1;
    [self selection:self.selectionControl]; // yuk
}

- (void)updateGuiderMenu
{
    NSMenu* menu = [[NSMenu alloc] initWithTitle:@""];
    
    NSMenuItem* item = [[NSMenuItem alloc] initWithTitle:@"None" action:@selector(guiderMenuAction:) keyEquivalent:@""];
    [menu addItem:item];
    
    NSMenuItem* selectedItem = nil;
    CASAppDelegate* delegate = [NSApp delegate];
    if ([delegate.guiderControllers count]){
        [menu addItem:[NSMenuItem separatorItem]];
        for (CASGuiderController* guider in delegate.guiderControllers){
            NSMenuItem* item = [[NSMenuItem alloc] initWithTitle:guider.guider.deviceName action:@selector(guiderMenuAction:) keyEquivalent:@""];
            item.representedObject = guider;
            [menu addItem:item];
            if (self.cameraController.guider == guider){
                selectedItem = item;
            }
        }
    }
    
    self.guiderMenu.menu = menu;
    if (!selectedItem){
        selectedItem = [[menu itemArray] objectAtIndex:0]; // None item
    }
    [self.guiderMenu selectItem:selectedItem];
    
    if (self.cameraController.guider && !selectedItem){
        self.cameraController.guider = nil;
        // hide guider UI
    }
}

- (IBAction)guiderMenuAction:(NSMenuItem*)sender
{
    return; // tmp
    
    if (!sender.representedObject){
        self.cameraController.guider = nil;
        self.guideControlsContainer.hidden = YES;
    }
    else {
        self.cameraController.guider = sender.representedObject;
        self.guideControlsContainer.hidden = NO;
        self.imageView.showStarProfile = YES;
    }
}

#pragma mark - Actions

- (IBAction)_captureImpl
{
    // set the progress indicator settings after setting the continuous flag
    self.progressIndicator.maxValue = 1;
    self.imageView.progress = self.progressIndicator.doubleValue = 0;
    self.progressStatusText.hidden = self.progressIndicator.hidden = NO;
    
    if (self.cameraController.exposureUnits == 0 && self.cameraController.exposure > 1){
        self.imageView.showProgress = YES;
        self.imageView.progressInterval = self.cameraController.exposureUnits ? self.cameraController.exposure/1000 : self.cameraController.exposure;
    }
    else {
        self.imageView.showProgress = NO;
    }
    
    // capture the current controller and continuous flag in the completion block
    CASCameraController* cameraController = self.cameraController;
    
    // issue the capture command
    [cameraController captureWithBlock:^(NSError *error,CASCCDExposure* exposure) {
    
        if (error){
            // todo; run completion actions e.g. email, run processing scripts, etc
            [NSApp presentError:error];
            self.imageView.showProgress = NO;
        }
        else{
            
            // check it's the still the currently displayed camera before displaying the exposure
            if (exposure){
                if (cameraController == self.cameraController){
                    self.currentExposure = exposure;
                }
            }
            
            if (self.cameraController.capturing){
                self.progressStatusText.stringValue = @"Waiting...";
            }
            else{
                // todo; run completion actions e.g. email, run processing scripts, etc
                [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(updateExposureIndicator) object:nil];
            }
            self.progressStatusText.hidden = self.progressIndicator.hidden = !self.cameraController.capturing;
            self.imageView.showProgress = self.cameraController.capturing;
        }
    }];
}

- (void)_chooseMovieLocationAndStartRecordingWithBlock:(void(^)(void))block
{
    NSSavePanel* save = [NSSavePanel savePanel];
    save.canCreateDirectories = YES;
    save.allowedFileTypes = @[@"mov"];
    
    [save beginSheetModalForWindow:self.window completionHandler:^(NSInteger result) {
        
        if (result == NSFileHandlingPanelOKButton){
            
            self.cameraController.movieExporter = [CASMovieExporter exporterWithURL:save.URL];
            
            // todo; some kind of record indicator on the exposure view
            
            if (block){
                block();
            }
        }
    }];
}

- (IBAction)capture:(NSButton*)sender
{
    // if recording to video, select a file todo; just save to exposure library
    if (self.cameraController.continuous && self.recordAsVideo && !self.cameraController.movieExporter){
        [self _chooseMovieLocationAndStartRecordingWithBlock:^{
            [self _captureImpl];
        }];
    }
    else {
        [self _captureImpl];
    }
}

- (IBAction)cancelCapture:(NSButton*)sender
{
    // todo; confirm !
    
    self.captureButton.enabled = NO;
    [self.cameraController cancelCapture];
    self.imageView.showProgress = NO;
}

- (void)_runSavePanel:(NSSavePanel*)save forExposures:(NSArray*)exposures withProgressLabel:(NSString*)progressLabel exportBlock:(void(^)(CASCCDExposure*))exportBlock completionBlock:(void(^)(void))completionBlock
{
    [save beginSheetModalForWindow:self.window completionHandler:^(NSInteger result) {
        
        if (result == NSFileHandlingPanelOKButton){
            
            // wait for the open sheet to dismiss
            dispatch_async(dispatch_get_main_queue(), ^{
                
                // start progress hud
                CASProgressWindowController* progress = [CASProgressWindowController createWindowController];
                [progress beginSheetModalForWindow:self.window];
                [progress configureWithRange:NSMakeRange(0, [exposures count]) label:progressLabel];
                
                // export the exposures - beware of races here since we're doing this async
                dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                    
                    for (__strong CASCCDExposure* exposure in exposures){
                        
                        // prefer the corrected image
                        CASCCDExposure* corrected = exposure.correctedExposure;
                        if (corrected){
                            exposure = corrected;
                        }
                        
                        @try {
                            @autoreleasepool {
                                exportBlock(exposure);
                            }
                        }
                        @catch (NSException *exception) {
                            NSLog(@"*** Exception exporting exposure: %@",exposure);
                        }
                        
                        // release the pixels - need an autorelease pool-style mechanism to do this generally
                        [exposure reset];
                        
                        // update progress bar
                        dispatch_async(dispatch_get_main_queue(), ^{
                            progress.progressBar.doubleValue++;
                        });
                    }
                    
                    // dismiss progress sheet/hud
                    dispatch_async(dispatch_get_main_queue(), ^{
                        
                        if (completionBlock){
                            completionBlock();
                        }
                        [progress endSheetWithCode:NSOKButton];
                    });
                });
            });
        }
    }];
}

- (IBAction)saveAs:(id)sender
{
    NSArray* exposures = self.exposuresController.selectedObjects;
    if (![exposures count]){
        return;
    }
        
    NSSavePanel* save = nil;
    if ([exposures count] == 1){
        save = [NSSavePanel savePanel];
    }
    else {
        save = [NSOpenPanel openPanel];
        ((NSOpenPanel*)save).canChooseFiles = NO;
        ((NSOpenPanel*)save).canChooseDirectories = YES;
        ((NSOpenPanel*)save).prompt = @"Choose";
    }
    save.canCreateDirectories = YES;
    
    IKSaveOptions* options = [[IKSaveOptions alloc] initWithImageProperties:nil imageUTType:nil]; // leaks ?
    [options addSaveOptionsAccessoryViewToSavePanel:save];
    
    // run the save panel and save the exposures to the selected location
    [self _runSavePanel:save forExposures:exposures withProgressLabel:NSLocalizedString(@"Saving...", @"Progress text") exportBlock:^(CASCCDExposure* exposure) {
        
        NSData* data = [[exposure newImage] dataForUTType:options.imageUTType options:options.imageProperties]; 
        if (!data){
            NSLog(@"*** Failed to create image from exposure");
        }
        else {
            
            NSURL* url = save.URL;
            if ([exposures count] > 1){
                NSString* name = [CASCCDExposureIO defaultFilenameForExposure:exposure];
                NSString *extension = (__bridge_transfer NSString *)UTTypeCopyPreferredTagWithClass((__bridge CFStringRef)(options.imageUTType), kUTTagClassFilenameExtension);
                url = [[url URLByAppendingPathComponent:name] URLByAppendingPathExtension:extension];
            }

            NSError* error;
            [data writeToFile:url.path options:NSDataWritingAtomic error:&error];
            if (error){
                [NSApp presentError:error];
            }
        }
    } completionBlock:nil];
}

- (IBAction)exportToFITS:(id)sender
{
    NSArray* exposures = self.exposuresController.selectedObjects;
    if (![exposures count]){
        return;
    }
    
    NSSavePanel* save = nil;
    if ([exposures count] == 1){
        save = [NSSavePanel savePanel];
    }
    else {
        save = [NSOpenPanel openPanel];
        ((NSOpenPanel*)save).canChooseFiles = NO;
        ((NSOpenPanel*)save).canChooseDirectories = YES;
        ((NSOpenPanel*)save).prompt = @"Choose";
    }
    save.canCreateDirectories = YES;

    save.allowedFileTypes = @[@"fits",@"fit"];
    
    [self _runSavePanel:save forExposures:exposures withProgressLabel:NSLocalizedString(@"Exporting...", @"Progress text") exportBlock:^(CASCCDExposure* exposure) {
        
        NSURL* url = save.URL;
        if ([exposures count] > 1){
            NSString* name = [CASCCDExposureIO defaultFilenameForExposure:exposure];
            url = [[url URLByAppendingPathComponent:name] URLByAppendingPathExtension:@"fits"];
        }
        
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
    } completionBlock:nil];
}

- (IBAction)exportToMovie:(id)sender
{
    NSArray* exposures = self.exposuresController.selectedObjects;
    if (![exposures count]){
        return;
    }
    
    NSSavePanel* save = [NSSavePanel savePanel];
    save.canCreateDirectories = YES;
    save.allowedFileTypes = @[@"mov"];
    
    __block CASMovieExporter* exporter = nil;
    [self _runSavePanel:save forExposures:exposures withProgressLabel:NSLocalizedString(@"Exporting...", @"Progress text") exportBlock:^(CASCCDExposure* exposure) {
        
        if (!exporter){
            exporter = [CASMovieExporter exporterWithURL:save.URL];
        }
        
        NSError* error;
        if (!([exporter addExposure:exposure error:&error])){
            dispatch_async(dispatch_get_main_queue(), ^{
                [NSApp presentError:error];
            });
        }
        
    } completionBlock:^{
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [exporter complete];
        });
    }];
}

- (IBAction)zoom:(NSSegmentedControl*)sender
{
    if (sender.selectedSegment == 0){
        [self zoomIn:self];
    }
    else {
        [self zoomOut:self];
    }
}

- (IBAction)zoomFit:(NSSegmentedControl*)sender
{
    if (sender.selectedSegment == 0){
        [self.imageView zoomImageToFit:self];
    }
    else {
        [self.imageView zoomImageToActualSize:self];
    }
}

- (IBAction)selection:(NSSegmentedControl*)sender
{
    if (sender.selectedSegment == 0 && !self.imageView.displayingScaledSubframe){
        self.imageView.showSelection = YES;
    }
    else {
        self.imageView.showSelection = NO;
        [self selectionRectChanged:self.imageView];
    }
}

- (IBAction)zoomIn:(id)sender
{
    [self.imageView zoomIn:sender];
}

- (IBAction)zoomOut:(id)sender
{
    [self.imageView zoomOut:sender];
}

- (void)zoomImageToFit:sender
{
    [self.imageView zoomImageToFit:sender];
}

- (void)zoomImageToActualSize:sender
{
    [self.imageView zoomImageToActualSize:sender];
}

- (IBAction)toggleDevices:(id)sender
{
    if (!self.detailLeadingConstraint.constant){
        [self.devicesTableView completeSetup];
        [self.detailLeadingConstraint.animator setConstant:self.devicesTableView.frame.size.width];
    }
    else {
        [self.detailLeadingConstraint.animator setConstant:0];
    }
}

- (IBAction)selectExposure:(id)sender
{
    CASCCDExposure* exp = [sender representedObject];
    if ([exp isKindOfClass:[CASCCDExposure class]]){
        self.exposuresController.selectedObjects = [NSArray arrayWithObject:exp];
    }
}

- (IBAction)deleteExposure:(id)sender
{
    const NSInteger count = [self.exposuresController.selectedObjects count];
    if (count > 0){
        
        NSString* message = (count == 1) ? @"Are you sure you want to delete this exposure ? This cannot be undone." : [NSString stringWithFormat:@"Are you sure you want to delete these %ld exposures ? This cannot be undone.",count];
        
        NSAlert* alert = [NSAlert alertWithMessageText:@"Delete Exposure"
                                         defaultButton:nil
                                       alternateButton:@"Cancel"
                                           otherButton:nil
                             informativeTextWithFormat:message,nil];
        
        [alert beginSheetModalForWindow:self.window modalDelegate:self didEndSelector:@selector(deleteConfirmSheetCompleted:returnCode:contextInfo:) contextInfo:nil];
    }
}

- (void)deleteConfirmSheetCompleted:(NSAlert*)sender returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo
{
    if (returnCode == NSAlertDefaultReturn){
        [self.exposuresController removeObjectsAtArrangedObjectIndexes:[self.exposuresController selectionIndexes]];
    }
}

- (IBAction)toggleShowHistogram:(id)sender
{
    self.showHistogram = !self.showHistogram;
}

- (IBAction)toggleShowReticle:(id)sender
{
    self.imageView.showReticle = !self.imageView.showReticle;
}

- (IBAction)toggleShowStarProfile:(id)sender
{
    self.imageView.showStarProfile = !self.imageView.showStarProfile;
}

- (IBAction)toggleShowImageStats:(id)sender
{
    self.imageView.showImageStats = !self.imageView.showImageStats;
}

- (IBAction)toggleInvertImage:(id)sender
{
    self.invert = !self.invert;
}

- (IBAction)toggleEqualiseHistogram:(id)sender
{
    self.equalise = !self.equalise;
}

- (IBAction)toggleMedianFilter:(id)sender
{
    self.medianFilter = !self.medianFilter;
}

- (IBAction)toggleShowPlateSolution:(id)sender
{
    self.showPlateSolution = !self.showPlateSolution;
}

- (IBAction)applyDebayer:(NSMenuItem*)sender
{
    switch (sender.tag) {
        case 11000:
            self.debayerMode = kCASImageDebayerNone;
            break;
        case 11001:
            self.debayerMode = kCASImageDebayerRGGB;
            break;
        case 11002:
            self.debayerMode = kCASImageDebayerGRBG;
            break;
        case 11003:
            self.debayerMode = kCASImageDebayerBGGR;
            break;
        case 11004:
            self.debayerMode = kCASImageDebayerGBRG;
            break;
    }
}

- (IBAction)toggleScaleSubframe:(id)sender
{
    self.scaleSubframe = !self.scaleSubframe;
}

- (IBAction)sendFeedback:(id)sender
{
    NSString* const feedback = @"feedback@coreastro.org";
    NSURL* mailUrl = [NSURL URLWithString:[NSString stringWithFormat:@"mailto:%@?subject=%@",feedback,@"CoreAstro%20Feedback"]];
    if (![[NSWorkspace sharedWorkspace] openURL:mailUrl]){
        [[NSAlert alertWithMessageText:@"Send Feedback"
                         defaultButton:@"OK"
                       alternateButton:nil
                           otherButton:nil
             informativeTextWithFormat:[NSString stringWithFormat:@"You don't appear to have a configured email account on this Mac. You can send feedback to %@",feedback],nil] runModal];
    }
}

- (IBAction)adjustRed:(NSSlider*)sender
{
    self.colourAdjustments.redAdjust = sender.floatValue;
    [self displayExposure:_currentExposure];
}

- (IBAction)adjustGreen:(NSSlider*)sender
{
    self.colourAdjustments.greenAdjust = sender.floatValue;
    [self displayExposure:_currentExposure];
}

- (IBAction)adjustBlue:(NSSlider*)sender
{
    self.colourAdjustments.blueAdjust = sender.floatValue;
    [self displayExposure:_currentExposure];
}

- (IBAction)adjustAll:(NSSlider*)sender
{
    self.colourAdjustments.allAdjust = sender.floatValue;
    [self displayExposure:_currentExposure];
}

// todo; implement click and hold behaviour for pulse buttons
- (IBAction)pulseNorth:(id)sender
{
    [self.cameraController.guider pulse:kCASGuiderDirection_DecPlus duration:self.guidePulseDuration block:nil];
}

- (IBAction)pulseSouth:(id)sender
{
    [self.cameraController.guider pulse:kCASGuiderDirection_DecMinus duration:self.guidePulseDuration block:nil];
}

- (IBAction)pulseEast:(id)sender
{
    [self.cameraController.guider pulse:kCASGuiderDirection_RAMinus duration:self.guidePulseDuration block:nil];
}

- (IBAction)pulseWest:(id)sender
{
    [self.cameraController.guider pulse:kCASGuiderDirection_RAPlus duration:self.guidePulseDuration block:nil];

}

- (void)_presentCaptureControllerWithMode:(NSInteger)mode
{
    if (!self.cameraController || self.cameraController.capturing){
        return;
    }
    
    self.captureWindowController = [CASCaptureWindowController createWindowController];
    self.captureWindowController.model.captureCount = 25;
    self.captureWindowController.model.captureMode = mode;
    self.captureWindowController.model.combineMode = kCASCaptureModelCombineAverage;
    
    [self.captureWindowController beginSheetModalForWindow:self.window completionHandler:^(NSInteger result) {
        
        if (result == NSOKButton){
            
            self.captureController = [CASCaptureController captureControllerWithWindowController:self.captureWindowController];
            self.captureWindowController = nil;
            if (self.captureController){
                
                CASProgressWindowController* progress = [CASProgressWindowController createWindowController];
                [progress beginSheetModalForWindow:self.window];
                [progress configureWithRange:NSMakeRange(0, self.captureController.model.captureCount) label:NSLocalizedString(@"Capturing...", @"Progress sheet label")];

                self.captureController.imageProcessor = self.imageProcessor;
                self.captureController.cameraController = self.cameraController;
                self.captureController.exposuresController = self.libraryExposuresController;
                
                // self.cameraController pushExposureSettings
                
                __block BOOL inPostProcessing = NO;
                
                [self.captureController captureWithProgressBlock:^(CASCCDExposure* exposure,BOOL postProcessing) {
                
                    dispatch_async(dispatch_get_main_queue(), ^{
                    
                        if (postProcessing && !inPostProcessing){
                            inPostProcessing = YES;
                            [progress configureWithRange:NSMakeRange(0, self.captureController.model.captureCount) label:NSLocalizedString(@"Combining...", @"Progress sheet label")];
                        }
                        progress.progressBar.doubleValue++;
                    });
                    
                } completion:^(NSError *error) {
                   
                    if (error){
                        [NSApp presentError:error];
                    }
                    
                    [progress endSheetWithCode:NSOKButton];
                    
                    // self.cameraController popExposureSettings
                }];
            }
        }
    }];
}

- (IBAction)captureDarks:(id)sender
{
    [self _presentCaptureControllerWithMode:kCASCaptureModelModeDark];
}

- (IBAction)captureBias:(id)sender
{
    [self _presentCaptureControllerWithMode:kCASCaptureModelModeBias];
}

- (IBAction)captureFlats:(id)sender
{
    [self _presentCaptureControllerWithMode:kCASCaptureModelModeFlat];
}

- (IBAction)plateSolve:(id)sender
{
    if (self.plateSolver){
        // todo; solvers should be per exposure
        NSLog(@"Already solving something");
        return;
    }
        
    CASCCDExposure* exposure = self.currentExposure;
    if (!exposure){
        NSLog(@"No current exposure");
        return;
    }

    NSError* error;
    self.plateSolver = [CASPlateSolver plateSolverWithIdentifier:nil];
    if (![self.plateSolver canSolveExposure:exposure error:&error]){
        [NSApp presentError:error];
    }
    else{
    
        // todo; should be per exposure rather than blocking the whole app
        CASProgressWindowController* progress = [CASProgressWindowController createWindowController];
        [progress beginSheetModalForWindow:self.window];
        progress.label.stringValue = NSLocalizedString(@"Solving...", @"Progress sheet status label");
        [progress.progressBar setIndeterminate:YES];
        
        // solve async - beware of races here since we're doing this async
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            
            [self.plateSolver solveExposure:exposure completion:^(NSError *error, NSDictionary * results) {
                
                dispatch_async(dispatch_get_main_queue(), ^{
                    
                    [progress endSheetWithCode:NSOKButton];
                    
                    if (error){
                        [NSApp presentError:error];
                    }
                    else {
                        [self _resetAndRedisplayCurrentExposure];
                    }
                    self.plateSolver = nil;
                });
            }];
        });
    }
}

- (IBAction)toggleRecordAsVideo:(id)sender
{
    self.recordAsVideo = !self.recordAsVideo;
    
    if (!self.cameraController){
        return;
    }
        
    if (!self.recordAsVideo){
        
        // stop any active recoring
        if (self.cameraController.movieExporter){
            [self.cameraController.movieExporter complete];
            self.cameraController.movieExporter = nil;
        }
    }
    else {
        
        if (!self.cameraController.movieExporter) {
            
            // todo; have this as an option, by default save to exposure library ?
            
            [self _chooseMovieLocationAndStartRecordingWithBlock:nil];
        }
    }
}

#pragma mark Menu validation

- (BOOL)validateMenuItem:(NSMenuItem*)item
{
    BOOL enabled = YES;
    
    switch (item.tag) {
            
        case 10000:
            if (self.showHistogram){
                item.title = NSLocalizedString(@"Hide Histogram", @"Menu item title");
            }
            else {
                item.title = NSLocalizedString(@"Show Histogram", @"Menu item title");
            }
            break;
            
        case 10001:
            item.state = self.invert;
            break;
            
        case 10002:
            item.state = self.equalise;
            break;
            
        case 10006:
            item.state = self.medianFilter;
            break;

        case 10003:
            if (self.imageView.showReticle){
                item.title = NSLocalizedString(@"Hide Reticle", @"Menu item title");
            }
            else {
                item.title = NSLocalizedString(@"Show Reticle", @"Menu item title");
            }
            break;
            
        case 10004:
            if (self.imageView.showStarProfile){
                item.title = NSLocalizedString(@"Hide Star Profile", @"Menu item title");
            }
            else {
                item.title = NSLocalizedString(@"Show Star Profile", @"Menu item title");
            }
            break;

        case 10005:
            if (self.imageView.showImageStats){
                item.title = NSLocalizedString(@"Hide Image Stats", @"Menu item title");
            }
            else {
                item.title = NSLocalizedString(@"Show Image Stats", @"Menu item title");
            }
            break;

        case 10010:
            item.state = self.scaleSubframe;
            break;

        case 10011:
            item.state = self.recordAsVideo;
            break;
            
        case 10012:
            enabled = (self.currentExposure != nil && !self.cameraController.capturing);
            break;
            
        case 10014:
            item.state = self.showPlateSolution;
            break;

        case 10020:
        case 10021:
        case 10022:
            enabled = (self.cameraController != nil && !self.cameraController.capturing);
            break;

        case 11000:
            item.state = self.imageDebayer.mode == kCASImageDebayerNone;
            break;

        case 11001:
            item.state = self.imageDebayer.mode == kCASImageDebayerRGGB;
            break;
            
        case 11002:
            item.state = self.imageDebayer.mode == kCASImageDebayerGRBG;
            break;
            
        case 11003:
            item.state = self.imageDebayer.mode == kCASImageDebayerBGGR;
            break;
            
        case 11004:
            item.state = self.imageDebayer.mode == kCASImageDebayerGBRG;
            break;

    }
    return enabled;
}

- (IBAction)libraryBackButtonPressed:(id)sender
{
    [self.devicesTableView selectProject:self.exposuresController.project];
}

#pragma mark NSResponder

- (void)keyDown:(NSEvent *)theEvent
{
    [self interpretKeyEvents:[NSArray arrayWithObject:theEvent]];
}

- (void)moveLeft:(id)sender
{
    [self.exposuresController selectPrevious:nil];
}

- (void)moveRight:(id)sender
{
    [self.exposuresController selectNext:nil];
}

- (void)delete:sender
{
    if ([[self.exposuresController selectedObjects] count]){
        if ([self.exposuresController isKindOfClass:[CASExposuresController class]]){
            [self.exposuresController removeCurrentlySelectedExposuresWithWindow:self.window];
        }
        else {
            [self.exposuresController remove:sender]; // change no being saved
        }
    }
}

- (void)deleteBackward:sender
{
    [self delete:sender];
}

#pragma mark CASExposureView delegate

- (void) selectionRectChanged: (CASExposureView*) imageView
{
//    NSLog(@"selectionRectChanged: %@",NSStringFromRect(imageView.selectionRect));
    
    if (self.imageView.image){
        
        const CGRect rect = self.imageView.selectionRect;
        if (CGRectIsEmpty(rect)){
            
            self.cameraController.subframe = CGRectZero;
            [self.subframeDisplay setStringValue:@"Make a selection to define a subframe"];
        }
        else {
            
            CGSize size = CGSizeZero;
            CASCCDProperties* sensor = self.cameraController.camera.sensor;
            if (sensor){
                size = CGSizeMake(sensor.width, sensor.height);
            }
            else {
                size = CGSizeMake(CGImageGetWidth(self.imageView.CGImage), CGImageGetHeight(self.imageView.CGImage));
            }
            
            CGRect subframe = CGRectMake(rect.origin.x, size.height - rect.origin.y - rect.size.height, rect.size.width,rect.size.height);
            subframe = CGRectIntersection(subframe, CGRectMake(0, 0, size.width, size.height));
            [self.subframeDisplay setStringValue:[NSString stringWithFormat:@"x=%.0f y=%.0f\nw=%.0f h=%.0f",subframe.origin.x,subframe.origin.y,subframe.size.width,subframe.size.height]];
            self.cameraController.subframe = subframe;
        }
    }
}

#pragma mark NSToolbar delegate

- (NSToolbarItem *)toolbarItemWithIdentifier:(NSString *)identifier
                                       label:(NSString *)label
                                 paleteLabel:(NSString *)paletteLabel
                                     toolTip:(NSString *)toolTip
                                      target:(id)target
                                 itemContent:(id)imageOrView
                                      action:(SEL)action
                                        menu:(NSMenu *)menu
{
    // here we create the NSToolbarItem and setup its attributes in line with the parameters
    NSToolbarItem *item = [[NSToolbarItem alloc] initWithItemIdentifier:identifier];
    
    [item setLabel:label];
    [item setPaletteLabel:paletteLabel];
    [item setToolTip:toolTip];
    [item setTarget:target];
    [item setAction:action];
    
    // Set the right attribute, depending on if we were given an image or a view
    if([imageOrView isKindOfClass:[NSImage class]]){
        [item setImage:imageOrView];
    } else if ([imageOrView isKindOfClass:[NSView class]]){
        [item setView:imageOrView];
    }else {
        assert(!"Invalid itemContent: object");
    }
    
    
    // If this NSToolbarItem is supposed to have a menu "form representation" associated with it
    // (for text-only mode), we set it up here.  Actually, you have to hand an NSMenuItem
    // (not a complete NSMenu) to the toolbar item, so we create a dummy NSMenuItem that has our real
    // menu as a submenu.
    //
    if (menu != nil)
    {
        // we actually need an NSMenuItem here, so we construct one
        NSMenuItem *mItem = [[NSMenuItem alloc] init];
        [mItem setSubmenu:menu];
        [mItem setTitle:label];
        [item setMenuFormRepresentation:mItem];
    }
    
    return item;
}

- (NSToolbarItem *)toolbar:(NSToolbar *)toolbar itemForItemIdentifier:(NSString *)itemIdentifier willBeInsertedIntoToolbar:(BOOL)flag;
{
    NSToolbarItem* item = nil;
    
    if ([@"DeviceView" isEqualToString:itemIdentifier]){
        
        item = [self toolbarItemWithIdentifier:itemIdentifier
                                         label:@"Devices" 
                                   paleteLabel:@"Devices" 
                                       toolTip:nil 
                                        target:self 
                                   itemContent:self.devicesToggleControl 
                                        action:@selector(toggleDevices:) 
                                          menu:nil];
    }

    if ([@"ZoomInOut" isEqualToString:itemIdentifier]){
        
        item = [self toolbarItemWithIdentifier:itemIdentifier
                                         label:@"Zoom" 
                                   paleteLabel:@"Zoom" 
                                       toolTip:nil 
                                        target:self 
                                   itemContent:self.zoomControl 
                                        action:@selector(zoom:) 
                                          menu:nil];
    }
    
    if ([@"ZoomFit" isEqualToString:itemIdentifier]){
        
        item = [self toolbarItemWithIdentifier:itemIdentifier
                                         label:@"Fit" 
                                   paleteLabel:@"Fit" 
                                       toolTip:nil 
                                        target:self 
                                   itemContent:self.zoomFitControl
                                        action:@selector(zoomFit:) 
                                          menu:nil];
    }

    if ([@"Selection" isEqualToString:itemIdentifier]){
        
        item = [self toolbarItemWithIdentifier:itemIdentifier
                                         label:@"Selection" 
                                   paleteLabel:@"Selection" 
                                       toolTip:nil 
                                        target:self 
                                   itemContent:self.selectionControl
                                        action:@selector(selection:) 
                                          menu:nil];
    }

    return item;    
}

- (NSArray *)toolbarDefaultItemIdentifiers:(NSToolbar*)toolbar;
{
    return [NSArray arrayWithObjects:@"DeviceView",@"ZoomInOut",@"ZoomFit",@"Selection",nil];   
}

#pragma mark Notifications

- (void)guideCommandNotification:(NSNotification*)notification
{
    // check object is the current camera controller
    NSLog(@"guideCommandNotification: %@ %@",[notification object],[notification userInfo]);
}

#pragma mark Master selection changes

- (void)showLibraryViewWithProject:(CASCCDExposureLibraryProject*)project
{
    if (!self.libraryViewController){
        self.libraryViewController = [[CASLibraryBrowserViewController alloc] initWithNibName:@"CASLibraryBrowserViewController" bundle:nil];
        self.libraryViewController.exposureDelegate = self;
    }
    
    // drop the library view into the same container as the image view
    if (![self.libraryViewController.view superview]){
        self.libraryViewController.view.frame = CGRectInset(self.imageView.enclosingScrollView.frame, -1, -1);
        [self.imageView.enclosingScrollView.superview addSubview:self.libraryViewController.view];
        self.libraryViewController.view.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
        self.imageView.enclosingScrollView.hidden = YES;
    }

    // set the exposure set to display
    if (!project){
        self.libraryViewController.exposuresController = self.libraryExposuresController;
    }
    else {
        CASExposuresController* exposuresController = project.exposuresController;
        if (!exposuresController){
            exposuresController = [[CASExposuresController alloc] initWithContainer:project keyPath:@"exposures"];
            exposuresController.project = project;
            project.exposuresController = exposuresController;
        }
        self.libraryViewController.exposuresController = exposuresController;
    }
    self.libraryViewController.exposuresController.navigateSelection = NO;
    
    self.exposuresController = (CASExposuresController*)self.libraryViewController.exposuresController;
    
    if ([self.exposuresController.selectionIndexes count] == 1){
        self.imageBannerView.exposure = [self.exposuresController.selectedObjects objectAtIndex:0];
    }
    else {
        self.imageBannerView.exposure = nil;
    }
}

- (void)hideLibraryView
{
    if ([self.libraryViewController.view superview]){
        [self.libraryViewController.view removeFromSuperview];
        self.imageView.enclosingScrollView.hidden = NO;
        [self displayExposure:_currentExposure];
    }
}

- (void)configureLibraryBackButton
{
    if (self.libraryViewController.view.superview || self.cameraController){
        
        // if we're displaying the library view or in camera mode then hide the Back button
        
        self.libraryBackButton.hidden = YES;
        
        NSView* cameraNameField = self.imageBannerView.cameraNameField;
        if (self.libraryBackButtonConstraints){
            [self.imageBannerView removeConstraints:self.libraryBackButtonConstraints];
        }
        self.libraryBackButtonConstraints = [NSLayoutConstraint constraintsWithVisualFormat:@"|-[cameraNameField]" options:0 metrics:nil views:NSDictionaryOfVariableBindings(cameraNameField)];
        [self.imageBannerView addConstraints:self.libraryBackButtonConstraints];
    }
    else {
        
        // otherwise, if we're in archived image mode, show the Back button and set the title to the name of the exposure's parent project
        
        self.libraryBackButton.hidden = NO;
        
        NSView* libraryBackButton = self.libraryBackButton;
        NSView* cameraNameField = self.imageBannerView.cameraNameField;
        if (self.libraryBackButtonConstraints){
            [self.imageBannerView removeConstraints:self.libraryBackButtonConstraints];
        }
        self.libraryBackButtonConstraints = [NSLayoutConstraint constraintsWithVisualFormat:@"|-8-[libraryBackButton(>=85)]-[cameraNameField]" options:0 metrics:nil views:NSDictionaryOfVariableBindings(cameraNameField,libraryBackButton)];
        [self.imageBannerView addConstraints:self.libraryBackButtonConstraints];
        
        if (self.exposuresController.project.name){
            self.libraryBackButton.title = self.exposuresController.project.name;
        }
        else {
            self.libraryBackButton.title = @"All Exposures";
        }
        [self.libraryBackButton sizeToFit];
    }
}

#pragma mark Master selection delegate

- (void)cameraWasSelected:(id)cameraController
{
    [self hideLibraryView];
    
    self.cameraController = cameraController;
    
    if (!cameraController){
        [self configureForCameraController];
    }
    
    [self configureLibraryBackButton];
}

- (void)libraryWasSelected:(id)library
{
    self.cameraController = nil;
    
    if (!library){
        [self hideLibraryView];
    }
    else{
        [self showLibraryViewWithProject:[library isKindOfClass:[CASCCDExposureLibraryProject class]] ? library : nil];
    }

    [self configureLibraryBackButton];
}

#pragma mark Library delegate

- (void)focusOnExposures:(CASExposuresController*)exposuresController
{
    if ([[exposuresController arrangedObjects] count]){
        
        [self hideLibraryView];
        
        self.exposuresController = exposuresController;
        
        NSArray* exposures = [self.exposuresController selectedObjects];
        if ([exposures count]){
            self.currentExposure = [exposures objectAtIndex:0];
        }
        
        [self configureLibraryBackButton];
    }
}

@end

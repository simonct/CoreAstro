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
#import "CASExposureView.h"
#import "CASShadowView.h"
#import "CASMasterSelectionView.h"
#import "CASLibraryBrowserViewController.h"
#import <CoreAstro/CoreAstro.h>

#pragma IB Convenience Classes

@interface CASGuidersArrayController : NSArrayController
@end
@implementation CASGuidersArrayController
@end

@interface CASFlatsArrayController : NSArrayController
@end
@implementation CASFlatsArrayController
@end

@interface CASDarksArrayController : NSArrayController
@end
@implementation CASDarksArrayController
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

@interface CASCameraWindowController ()<CASMasterSelectionViewDelegate,CASLibraryBrowserViewControllerDelegate>
@property (nonatomic,assign) BOOL invert;
@property (nonatomic,assign) BOOL equalise;
@property (nonatomic,assign) BOOL divideFlat;
@property (nonatomic,assign) BOOL subtractDark;
@property (nonatomic,assign) BOOL showHistogram;
@property (nonatomic,assign) BOOL enableGuider;
@property (nonatomic,assign) BOOL scaleSubframe;
@property (nonatomic,assign) NSInteger debayerMode;
@property (nonatomic,strong) CASCCDExposure* currentExposure;
@property (nonatomic,strong) NSLayoutConstraint* detailLeadingConstraint;
@property (nonatomic,strong) CASImageProcessor* imageProcessor;
@property (nonatomic,strong) CASImageDebayer* imageDebayer;
@property (nonatomic,weak) IBOutlet NSTextField *exposuresStatusText;
@property (nonatomic,weak) IBOutlet NSPopUpButton *captureMenu;
@property (nonatomic,assign) NSUInteger captureMenuSelectedIndex;
@property (nonatomic,strong) CASLibraryBrowserViewController* libraryViewController;
@property (nonatomic,strong) CASColourAdjustments* colourAdjustments;
@property (nonatomic,readonly) CASCCDExposureLibrary* library;
@end

@interface CASCameraWindow : NSWindow
@property (nonatomic,readonly) CASCameraWindowController* cameraController;
@end

@implementation CASCameraWindow

- (CASCameraWindowController*) cameraController {
    return (CASCameraWindowController*)self.windowController;
}

- (void)flipImageHorizontal:sender {
    [self.cameraController.imageView flipImageHorizontal:sender];
}

- (void)flipImageVertical:sender {
    [self.cameraController.imageView flipImageVertical:sender];
}

- (void)rotateImageLeft:sender {
    [self.cameraController.imageView rotateImageLeft:sender];
}

- (void)rotateImageRight:sender {
    [self.cameraController.imageView rotateImageRight:sender];
}

- (void)zoomIn:sender {
    [self.cameraController.imageView zoomIn:sender];
}

- (void)zoomOut:sender {
    [self.cameraController.imageView zoomOut:sender];
}

- (void)zoomImageToFit:sender {
    [self.cameraController.imageView zoomImageToFit:sender];
}

- (void)zoomImageToActualSize:sender {
    [self.cameraController.imageView zoomImageToActualSize:sender];
}

@end

@implementation CASCameraWindowController

- (void)windowDidLoad
{
    [super windowDidLoad];
    
    self.colourAdjustments = [[CASColourAdjustments alloc] init];
    
    self.imageDebayer = [CASImageDebayer imageDebayerWithIdentifier:nil];
    self.imageProcessor = [CASImageProcessor imageProcessorWithIdentifier:nil];
    
    [self.exposuresController setSortDescriptors:[NSArray arrayWithObject:[NSSortDescriptor sortDescriptorWithKey:@"date" ascending:NO]]];
    [self.exposuresController setSelectedObjects:nil];
    [self.exposuresController setSelectsInsertedObjects:YES];
    [self.exposuresController addObserver:self forKeyPath:@"selectedObjects" options:0 context:nil];
    [self.exposuresController addObserver:self forKeyPath:@"arrangedObjects" options:0 context:nil];
    [self.exposuresController bind:@"contentArray" toObject:self withKeyPath:@"library.exposures" options:nil];

    CGColorRef gray = CGColorCreateGenericRGB(128/255.0, 128/255.0, 128/255.0, 1); // match to self.imageView.backgroundColor ?
    self.imageView.layer.backgroundColor = gray;
    CGColorRelease(gray);
    
    NSButton* close = [self.window standardWindowButton:NSWindowCloseButton];
    [close setTarget:self];
    [close setAction:@selector(hideWindow:)];
    
    self.imageView.hasVerticalScroller = YES;
    self.imageView.hasHorizontalScroller = YES;
    self.imageView.autohidesScrollers = YES;
    self.imageView.currentToolMode = IKToolModeMove;
    self.imageView.delegate = self;
    self.imageView.imageProcessor = self.imageProcessor;
    
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
    
    // add a customisable one
    id detailContainerView1 = self.detailContainerView;
    NSDictionary* viewNames = NSDictionaryOfVariableBindings(detailContainerView1);
    self.detailLeadingConstraint = [[NSLayoutConstraint constraintsWithVisualFormat:@"|-0-[detailContainerView1]-|" options:NSLayoutFormatAlignAllCenterY metrics:nil views:viewNames] objectAtIndex:0];
    [self.window.contentView addConstraints:[NSArray arrayWithObject:self.detailLeadingConstraint]];
    
    // set the devices controller content
    self.camerasArrayController.content = ((CASAppDelegate*)[NSApp delegate]).cameraControllers;
    [[NSApp delegate] addObserver:self forKeyPath:@"cameraControllers" options:NSKeyValueObservingOptionInitial context:nil];
    [self.camerasArrayController addObserver:self forKeyPath:@"arrangedObjects" options:NSKeyValueObservingOptionInitial context:nil];
    [self.camerasArrayController addObserver:self forKeyPath:@"selectedObjects" options:NSKeyValueObservingOptionInitial context:nil];
    //[self.devicesArrayController bind:@"content" toObject:[NSApp delegate] withKeyPath:@"cameraControllers" options:nil];
    
    // set up the guiders controller
    self.guidersArrayController.content = ((CASAppDelegate*)[NSApp delegate]).guiderControllers;
    [[NSApp delegate] addObserver:self forKeyPath:@"guiderControllers" options:NSKeyValueObservingOptionInitial context:nil];
    [self.guidersArrayController addObserver:self forKeyPath:@"arrangedObjects" options:NSKeyValueObservingOptionInitial context:nil];
    [self.guidersArrayController addObserver:self forKeyPath:@"selectedObjects" options:NSKeyValueObservingOptionInitial context:nil];


    [self.darksController addObserver:self forKeyPath:@"selectedObjects" options:0 context:nil];
    [self.flatsController addObserver:self forKeyPath:@"selectedObjects" options:0 context:nil];
    
    // add a drop shadow
    [CASShadowView attachToView:self.detailContainerView edge:NSMinXEdge];
    [CASShadowView attachToView:self.imageView.superview edge:NSMaxXEdge];

    // set up the UI for the current camera controller
    [self configureForCameraController];
    
    // listen for guide notifications
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(guideCommandNotification:) name:kCASCameraControllerGuideCommandNotification object:nil];
    
    // listen for master selection changes
    self.devicesTableView.masterViewDelegate = (id)self;
    self.devicesTableView.camerasContainer = [NSApp delegate];
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

- (void)setCameraController:(CASCameraController *)cameraController
{
    if (_cameraController != cameraController){
        if (_cameraController){
            [_cameraController removeObserver:self forKeyPath:@"exposureStart"];
            [_cameraController removeObserver:self forKeyPath:@"capturing"];
        }
        _cameraController = cameraController;
        if (_cameraController){
            [_cameraController addObserver:self forKeyPath:@"exposureStart" options:0 context:nil];
            [_cameraController addObserver:self forKeyPath:@"capturing" options:0 context:nil];
        }
        [self configureForCameraController];
    }
}

- (CASCCDExposureLibrary*)library
{
    return [CASCCDExposureLibrary sharedLibrary];
}

- (CASCCDExposure*)currentlySelectedExposure
{
    NSArray* exposures = [self.exposuresController selectedObjects];
    if ([exposures isKindOfClass:[NSArray class]]){
        if ([exposures count] == 1){
            id exposure = [exposures objectAtIndex:0];
            if ([exposure isKindOfClass:[CASCCDExposure class]]){
                return exposure;
            }
        }
    }
    return nil;
}

- (void)setCurrentExposure:(CASCCDExposure *)currentExposure
{
    if (_currentExposure != currentExposure){

        // clear selection
        [self clearSelection];

        [_currentExposure reset]; // unload the current exposures pixels
        _currentExposure = currentExposure;
        
        // unobserve the darks and flats controllers so that they're not triggered by resetting the content in the methods below
        [self.darksController removeObserver:self forKeyPath:@"selectedObjects"];
        [self.flatsController removeObserver:self forKeyPath:@"selectedObjects"];

        // not currently showing candidate darks and flats
        // [self updateFlatsForExposure:_currentExposure];
        // [self updateDarksForExposure:_currentExposure];
        
        // observe the darks and flats controller again
        [self.darksController addObserver:self forKeyPath:@"selectedObjects" options:0 context:nil];
        [self.flatsController addObserver:self forKeyPath:@"selectedObjects" options:0 context:nil];

        // display the exposure
        [self displayExposure:_currentExposure];
    }
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if (context == nil) {
        
        if (object == self.exposuresController){
            if ([keyPath isEqualToString:@"selectedObjects"]){
                self.currentExposure = [self currentlySelectedExposure];
            }
        }
        else if (object == self.darksController || object == self.flatsController){
            if ([keyPath isEqualToString:@"selectedObjects"]){
                [self displayExposure:_currentExposure];
            }
        }
        else if (object == self.camerasArrayController){
            if ([keyPath isEqualToString:@"arrangedObjects"]){
            }
            else if ([keyPath isEqualToString:@"selectedObjects"]){
                NSArray* devices = self.camerasArrayController.selectedObjects;
                if ([devices count] > 0){
                    self.cameraController = [devices objectAtIndex:0];
                }
                else {
                    self.cameraController = nil;
                }
            }
        }
        else if (object == self.guidersArrayController){
            NSLog(@"[self.guidersArrayController arrangedObjects: %@",[self.guidersArrayController arrangedObjects]);
        }
        else if (object == [NSApp delegate]){
            if ([keyPath isEqualToString:@"cameraControllers"]){
                [self.camerasArrayController rearrangeObjects]; // can I avoid this step by binding the array controller directly to the app delegate ?
            }
            else if ([keyPath isEqualToString:@"guiderControllers"]){
                [self.guidersArrayController rearrangeObjects]; // can I avoid this step by binding the array controller directly to the app delegate ?
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
                }
                else {
                    self.progressStatusText.stringValue = @"Capturing...";
                    self.captureButton.title = NSLocalizedString(@"Cancel", @"Button title");
                    self.captureButton.action = @selector(cancelCapture:);
                    self.captureButton.enabled = self.cameraController.waitingForNextCapture;
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
    [self.sensorDepthField setStringValue:@""];
    [self.sensorPixelsField setStringValue:@""];

    [self.cameraController connect:^(NSError *error) {
        
        if (error){
            [NSApp presentError:error];
        }
        else {
            
            // check it's the same camera...
            
            CASCCDDevice* camera = self.cameraController.camera;

            [self.sensorSizeField setStringValue:[NSString stringWithFormat:@"%ld x %ld",camera.sensor.width,camera.sensor.height]];
            [self.sensorDepthField setStringValue:[NSString stringWithFormat:@"%ld bits per pixel",camera.sensor.bitsPerPixel]];
            [self.sensorPixelsField setStringValue:[NSString stringWithFormat:@"%0.2fµm x %0.2fµm",camera.sensor.pixelWidth,camera.sensor.pixelHeight]];
        }
    }];
    
    // show only exposures from this camera - still needed with the library view ?
    if (self.cameraController){
        [self.exposuresController setFilterPredicate:[NSPredicate predicateWithFormat:@"%K == %@",@"deviceID",self.cameraController.camera.uniqueID]];
    }
    else {
        [self.exposuresController setFilterPredicate:nil];
    }
    
    // set the first exposure for this camera
    if ([self.exposuresController.arrangedObjects count] > 0){
        [self.exposuresController setSelectionIndex:0];
    }
    else {
        [self.exposuresController setSelectedObjects:nil];
    }
    
    // reset the capture count - why am I doing this here ?
    if (!self.cameraController.captureCount && !self.cameraController.continuous){
        self.cameraController.captureCount = 1; // no, reset to the number of exposures selected in the UI...
    }
    
    // set progress display if this camera is capturing
    [self updateExposureIndicator];
}

- (void)_resetAndRedisplayCurrentExposure
{
    [[self.exposuresController arrangedObjects] makeObjectsPerformSelector:@selector(reset)]; // reset all
    [self displayExposure:[self currentlySelectedExposure]];
}

- (void)setEqualise:(BOOL)equalise
{
    if (_equalise != equalise){
        _equalise = equalise;
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

- (void)setSubtractDark:(BOOL)subtractDark
{
    if (_subtractDark != subtractDark){
        _subtractDark = subtractDark;
        [self _resetAndRedisplayCurrentExposure];
    }
}

- (void)setDivideFlat:(BOOL)divideFlat
{
    if (_divideFlat != divideFlat){
        _divideFlat = divideFlat;
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
        self.cameraController.continuous = [self captureMenuContinuousItemSelected];
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

- (BOOL)captureMenuContinuousItemSelected
{
    return (_captureMenuSelectedIndex == self.captureMenu.numberOfItems - 1);
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
        self.progressIndicator.hidden = NO;
        self.imageView.showProgress = YES;
        self.imageView.progress = self.progressIndicator.doubleValue = (interval * scaling) / self.cameraController.exposure;
        if (self.progressIndicator.doubleValue >= self.progressIndicator.maxValue){
            self.progressIndicator.indeterminate = YES;
            self.progressStatusText.stringValue = @"Downloading image...";
        }
        else {
            self.progressIndicator.indeterminate = NO;
        }
        [self.progressIndicator startAnimation:self];
        [self performSelector:@selector(updateExposureIndicator) withObject:nil afterDelay:0.05];
    }
    else {
        if (self.cameraController.waitingForNextCapture){
            self.progressIndicator.indeterminate = NO;
            self.progressIndicator.hidden = NO;
            self.imageView.showProgress = YES;
            self.progressStatusText.stringValue = @"Waiting...";
            self.imageView.progressInterval = self.cameraController.interval;
            self.imageView.progress = self.progressIndicator.doubleValue = 1 - (self.cameraController.continuousNextExposureTime - [NSDate timeIntervalSinceReferenceDate])/(double)self.cameraController.interval;
            [self performSelector:@selector(updateExposureIndicator) withObject:nil afterDelay:0.05];
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
        return;
    }
    
    NSString* title = self.cameraController.camera.deviceName;

    static NSDateFormatter* exposureFormatter = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        exposureFormatter = [[NSDateFormatter alloc] init];
        [exposureFormatter setDateStyle:NSDateFormatterMediumStyle];
        [exposureFormatter setTimeStyle:NSDateFormatterMediumStyle];
    });
    
    if (title){
        title = [NSString stringWithFormat:@"%@ %@",title,[NSString stringWithFormat:@"%@ (%@)",[exposureFormatter stringFromDate:exposure.date],exposure.displayExposure]];
    }
    else {
        title = [NSString stringWithFormat:@"%@ %@ (%@)",exposure.displayDeviceName,[exposureFormatter stringFromDate:exposure.date],exposure.displayExposure];
    }
    self.window.title = title;
    
    // debayer if required
    if (self.imageDebayer.mode != kCASImageDebayerNone){
        CASCCDExposure* debayeredExposure = [self.imageDebayer debayer:exposure adjustRed:self.colourAdjustments.redAdjust green:self.colourAdjustments.greenAdjust blue:self.colourAdjustments.blueAdjust all:self.colourAdjustments.allAdjust];
        if (debayeredExposure){
            exposure = debayeredExposure;
        }
    }
    
    // todo: CASImageProcessingChain runs all these async
    if (self.subtractDark){
        NSArray* darks = self.darksController.arrangedObjects;
        if ([darks count]){
            CASCCDExposure* dark = [self.darksController.arrangedObjects objectAtIndex:0];
            if (dark){
                [self.imageProcessor subtractDark:dark from:exposure];
            }
        }
    }

    if (self.divideFlat){
        NSArray* flats = self.flatsController.arrangedObjects;
        if ([flats count]){
            CASCCDExposure* flat = [self.flatsController.arrangedObjects objectAtIndex:0];
            if (flat){
                [self.imageProcessor divideFlat:flat into:exposure];
            }
        }
    }
    
    if (self.equalise){
        [self.imageProcessor equalise:exposure];
    }
    
    if (self.invert){
        [self.imageProcessor invert:exposure];
    }

    // check image view is actually visible
    if (!self.imageView.isHidden){
        self.imageView.currentExposure = exposure;
    }
}


- (void)updateFlatsForExposure:(CASCCDExposure*)exposure
{
    if (exposure.type != kCASCCDExposureLightType){
        self.flatsController.content = nil;
    }
    else {
        self.flatsController.content = [[CASCCDExposureLibrary sharedLibrary] flatsMatchingExposure:exposure];
    }
}

- (void)updateDarksForExposure:(CASCCDExposure*)exposure
{
    if (exposure.type != kCASCCDExposureLightType){
        self.darksController.content = nil;
    }
    else {
        self.darksController.content = [[CASCCDExposureLibrary sharedLibrary] darksMatchingExposure:exposure];
    }
}

- (void)clearSelection
{
    self.selectionControl.selectedSegment = 1;
    [self selection:self.selectionControl]; // yuk
}

#pragma mark - Actions

- (IBAction)capture:(NSButton*)sender
{
    // check to see if we're in continuous mode
    self.cameraController.continuous = [self captureMenuContinuousItemSelected];

    // set the progress indicator settings after setting the continuous flag
    self.progressIndicator.maxValue = 1;
    self.imageView.progress = self.progressIndicator.doubleValue = 0;
    self.progressStatusText.hidden = self.progressIndicator.hidden = NO;
    
    if (self.cameraController.exposureUnits == 0 && self.cameraController.exposure > 1){
        self.imageView.showProgress = YES;
        self.imageView.progressInterval = self.cameraController.exposure;
    }
    else {
        self.imageView.showProgress = NO;
    }
    
    // capture the current controller and continuous flag in the completion block
    CASCameraController* cameraController = self.cameraController;
    const BOOL continuous = self.cameraController.continuous;
    
    // issue the capture command
    [cameraController captureWithBlock:^(NSError *error,CASCCDExposure* exposure) {
    
        if (error){
            // todo; run completion actions e.g. email, run processing scripts, etc
            [NSApp presentError:error];
        }
        else{
            
            // check it's the still the currently displayed camera
            if (cameraController == self.cameraController){
                
                if (continuous){
                    [self.exposuresController setSelectedObjects:nil];
                    [self displayExposure:exposure]; // do this *after* clearing the selection
                }
                else {
                    

                    [self.exposuresController setSelectionIndex:0];
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
    
    // switch out of selection mode once the capture's started
    if ([self.imageView.currentToolMode isEqualToString:IKToolModeSelect]){
        [self clearSelection];
    }
}

- (IBAction)cancelCapture:(NSButton*)sender
{
    self.captureButton.enabled = NO;
    [self.cameraController cancelCapture];
}

- (void)_runSavePanel:(NSSavePanel*)save forExposures:(NSArray*)exposures withProgressLabel:(NSString*)progressLabel andExportBlock:(void(^)(CASCCDExposure*))exportBlock
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
                    
                    for (CASCCDExposure* exposure in exposures){
                        
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
    
    IKSaveOptions* options = [[IKSaveOptions alloc] initWithImageProperties:nil imageUTType:nil];
    [options addSaveOptionsAccessoryViewToSavePanel:save];
    
    // run the save panel and save the exposures to the selected location
    [self _runSavePanel:save forExposures:exposures withProgressLabel:NSLocalizedString(@"Saving...", @"Progress text") andExportBlock:^(CASCCDExposure* exposure) {
        
        // get the image
        CGImageRef image = [exposure createImage].CGImage; // need to apply the current processing settings
        if (!image){
            NSLog(@"*** Failed to create image from exposure");
        }
        else{
            
            // convert to rgb as many common apps, including Preview, seem to be completely baffled by generic gray images
            const size_t width = CGImageGetWidth(image);
            const size_t height = CGImageGetHeight(image);
            CGContextRef rgb = [CASCCDImage createRGBBitmapContextWithSize:CASSizeMake(width, height)];
            if (!rgb){
                NSLog(@"*** Failed to create rgb image context");
            }
            else{
                
                CGContextDrawImage(rgb, CGRectMake(0, 0, width, height), image);
                CGImageRef image = CGBitmapContextCreateImage(rgb);
                if (!image){
                    NSLog(@"*** Failed to create rgb image");
                }
                else{
                    
                    NSURL* url = save.URL;
                    if ([exposures count] > 1){
                        NSString* name = [CASCCDExposureIO defaultFilenameForExposure:exposure];
                        NSString *extension = (__bridge_transfer NSString *)UTTypeCopyPreferredTagWithClass((__bridge CFStringRef)(options.imageUTType), kUTTagClassFilenameExtension);
                        url = [[url URLByAppendingPathComponent:name] URLByAppendingPathExtension:extension];
                    }
                    if (![[NSFileManager defaultManager] createDirectoryAtPath:[[url path] stringByDeletingLastPathComponent] withIntermediateDirectories:YES attributes:nil error:nil]){
                        NSLog(@"*** Failed to create image directory");
                    }
                    else {
                        CGImageDestinationRef dest = CGImageDestinationCreateWithURL((__bridge CFURLRef)url,(__bridge CFStringRef)[options imageUTType],1,NULL);
                        if (!dest){
                            NSLog(@"*** Failed to create image exporter to %@",url);
                        }
                        else{
                            
                            CGImageDestinationAddImage(dest, image, (__bridge CFDictionaryRef)[options imageProperties]);
                            if (!CGImageDestinationFinalize(dest)){
                                NSLog(@"*** Failed to save image to %@",url);
                            }
                            CGImageRelease(image);
                            CFRelease(dest);
                        }
                    }
                }
                CGContextRelease(rgb);
            }
        }
    }];
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
    
    [self _runSavePanel:save forExposures:exposures withProgressLabel:NSLocalizedString(@"Exporting...", @"Progress text") andExportBlock:^(CASCCDExposure* exposure) {
        
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
    if (sender.selectedSegment == 0 && !self.scaleSubframe){
        self.imageView.currentToolMode = IKToolModeSelect;
    }
    else {
        self.imageView.currentToolMode = IKToolModeMove;
        [self selectionRectRemoved:self.imageView];
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

- (IBAction)toggleInvertImage:(id)sender
{
    self.invert = !self.invert;
}

- (IBAction)toggleEqualiseHistogram:(id)sender
{
    self.equalise = !self.equalise;
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

#pragma mark Menu validation

- (BOOL)validateMenuItem:(NSMenuItem*)item
{
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
            
        case 10003:
            if (self.imageView.showReticle){
                item.title = NSLocalizedString(@"Hide Reticle", @"Menu item title");
            }
            else {
                item.title = NSLocalizedString(@"Show Reticle", @"Menu item title");
            }
            break;
            
        case 10010:
            item.state = self.scaleSubframe;
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
    return YES;
}

#pragma mark NSResponder

- (void)keyDown:(NSEvent *)theEvent
{
    [self interpretKeyEvents:[NSArray arrayWithObject:theEvent]];
}

- (void)moveUp:(id)sender
{
    const NSUInteger index = self.exposuresController.selectionIndex;
    if (index == NSNotFound){
        self.exposuresController.selectionIndex = 0;
    }
    else if (index > 0){
        self.exposuresController.selectionIndex = index - 1;
    }
}

- (void)moveDown:(id)sender
{
    const NSUInteger index = self.exposuresController.selectionIndex;
    if (index == NSNotFound){
        self.exposuresController.selectionIndex = 0;
    }
    else if (index < [self.exposuresController.arrangedObjects count] - 1){
        self.exposuresController.selectionIndex = index + 1;
    }
}

- (void)delete:sender
{
    if ([[self.exposuresController selectedObjects] count]){
        [self.exposuresController promptToDeleteCurrentSelectionWithWindow:self.window];
    }
}

- (void)deleteBackward:sender
{
    [self delete:sender];
}

#pragma mark IKImageView delegate

- (void) selectionRectAdded: (IKImageView *) imageView
{
    NSLog(@"selectionRectAdded");
}

- (void) selectionRectRemoved: (IKImageView *) imageView
{
    if (!self.cameraController.capturing){
        self.cameraController.subframe = CGRectZero;
        [self.subframeDisplay setStringValue:@"Make a selection to define a subframe"];
    }
}

- (void) selectionRectChanged: (IKImageView *) imageView
{
    CASCCDProperties* sensor = self.cameraController.camera.sensor;
    if (sensor && !self.cameraController.capturing){
        const CGRect rect = self.imageView.selectionRect;
        CGRect subframe = CGRectMake(rect.origin.x, sensor.height - rect.origin.y - rect.size.height, rect.size.width,rect.size.height);
        subframe = CGRectIntersection(subframe, CGRectMake(0, 0, sensor.width, sensor.height));
        [self.subframeDisplay setStringValue:[NSString stringWithFormat:@"x=%.0f y=%.0f\nw=%.0f h=%.0f",subframe.origin.x,subframe.origin.y,subframe.size.width,subframe.size.height]];
        self.cameraController.subframe = subframe;
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

- (void)showLibraryView
{
    if (!self.libraryViewController){
        self.libraryViewController = [[CASLibraryBrowserViewController alloc] initWithNibName:@"CASLibraryBrowserViewController" bundle:nil];
        self.libraryViewController.exposuresController = self.exposuresController;
        self.libraryViewController.exposureDelegate = self;
    }
    
    // drop the library view into the same container as the image view
    if (![self.libraryViewController.view superview]){
        self.libraryViewController.view.frame = CGRectInset(self.imageView.frame, -1, -1);
        [self.imageView.superview addSubview:self.libraryViewController.view];
        self.libraryViewController.view.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
        self.imageView.hidden = YES;
    }
}

- (void)hideLibraryView
{
    if ([self.libraryViewController.view superview]){
        [self.libraryViewController.view removeFromSuperview];
        self.imageView.hidden = NO;
        [self displayExposure:_currentExposure];
    }
}

- (void)cameraWasSelected:(id)cameraController
{
    [self hideLibraryView];
    
    self.cameraController = cameraController;
}

- (void)libraryWasSelected:(id)library
{
    self.cameraController = nil;
    
    if (!library){
        [self hideLibraryView];
    }
    else{
        [self showLibraryView];
    }
}

#pragma mark Library delegate

- (void)focusOnExposure:(CASCCDExposure*)exposure
{
    [self hideLibraryView];
    self.currentExposure = exposure;
}

@end

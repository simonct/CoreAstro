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
#import "CASHistogramView.h"
#import "CASImageControlsView.h"
#import "CASExposuresController.h"
#import "CASExposureTableView.h"
#import "CASImageView.h"
#import <CoreAstro/CoreAstro.h>

@interface CASCameraWindowController ()
@property (nonatomic,assign) BOOL invert;
@property (nonatomic,assign) BOOL equalise;
@property (nonatomic,assign) BOOL divideFlat;
@property (nonatomic,assign) BOOL subtractDark;
@property (nonatomic,assign) BOOL showHistogram;
@property (nonatomic,assign) CGFloat rotationAngle, zoomFactor;
@property (nonatomic,strong) CASCCDExposure* currentExposure;
@property (nonatomic,strong) NSLayoutConstraint* detailLeadingConstraint;
@property (nonatomic,strong) CASHistogramView* histogramView;
@property (nonatomic,strong) CASImageProcessor* imageProcessor;
@property (nonatomic,weak) IBOutlet NSTextField *exposuresStatusText;
@property (nonatomic,weak) IBOutlet NSPopUpButton *captureMenu;
@property (nonatomic,weak) IBOutlet CASImageControlsView *imageControlsView;
@property (nonatomic,weak) IBOutlet NSLayoutConstraint *imageViewBottomConstraint;
@property (nonatomic,assign) NSUInteger captureMenuSelectedIndex;
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
    self.cameraController.rotationAngle += M_PI/2;
}

- (void)rotateImageRight:sender {
    [self.cameraController.imageView rotateImageRight:sender];
    self.cameraController.rotationAngle -= M_PI/2;
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

- (id)initWithWindow:(NSWindow *)window
{
    self = [super initWithWindow:window];
    if (self) {
        self.zoomFactor = 1;
    }
    
    return self;
}

- (void)windowDidLoad
{
    [super windowDidLoad];
    
    self.imageProcessor = [CASImageProcessor imageProcessorWithIdentifier:nil];

    // hide the image controls strip for now
    {
        self.imageControlsView.hidden = YES;
        self.imageViewBottomConstraint.constant = 0;
    }

    [self.exposuresController setSortDescriptors:[NSArray arrayWithObject:[NSSortDescriptor sortDescriptorWithKey:@"date" ascending:NO]]];
    [self.exposuresController setSelectedObjects:nil];
    [self.exposuresController setSelectsInsertedObjects:YES];
    [self.exposuresController addObserver:self forKeyPath:@"selectedObjects" options:0 context:nil];
        
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
    [self.guidersArrayController addObserver:self forKeyPath:@"arrangedObjects" options:NSKeyValueObservingOptionInitial context:nil];
    [self.guidersArrayController addObserver:self forKeyPath:@"selectedObjects" options:NSKeyValueObservingOptionInitial context:nil];

    //[self.window visualizeConstraints:[self.equaliseCheckbox.superview.superview constraints]];
    
    self.histogramView = [[CASHistogramView alloc] initWithFrame:NSMakeRect(10, 10, 400, 200)];
    [self.imageView addSubview:self.histogramView];
    self.histogramView.hidden = YES;

    [self.darksController addObserver:self forKeyPath:@"selectedObjects" options:0 context:nil];
    [self.flatsController addObserver:self forKeyPath:@"selectedObjects" options:0 context:nil];
    
    [self.exposuresController bind:@"contentArray" toObject:self withKeyPath:@"exposures" options:nil];

    [self configureForCameraController];
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

- (NSArray*)exposures
{
    return [[CASCCDExposureLibrary sharedLibrary] exposures];
}

- (void)setExposures:(NSMutableArray*)exposures
{
    [[CASCCDExposureLibrary sharedLibrary] setExposures:exposures];
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
        
        [_currentExposure reset]; // unload the current exposures pixels
        _currentExposure = currentExposure;
        
        // hide/show the histogram view
        if (_currentExposure){
            self.histogramView.alphaValue = 1;
        }
        else {
            self.histogramView.alphaValue = 0;
        }
        
        // unobserve the darks and flats controllers so that they're not triggered by resetting the content in the methods below
        [self.darksController removeObserver:self forKeyPath:@"selectedObjects"];
        [self.flatsController removeObserver:self forKeyPath:@"selectedObjects"];

        [self updateFlatsForExposure:_currentExposure];
        [self updateDarksForExposure:_currentExposure];
        
        // observe the darks and flats controller again
        [self.darksController addObserver:self forKeyPath:@"selectedObjects" options:0 context:nil];
        [self.flatsController addObserver:self forKeyPath:@"selectedObjects" options:0 context:nil];

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
            [self updateExposuresMenu];
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
            NSLog(@"guidersArrayController: %@",change);
        }
        else if (object == [NSApp delegate]){
            if ([keyPath isEqualToString:@"cameraControllers"]){
                [self.camerasArrayController rearrangeObjects]; // can I avoid this step by binding the array controller directly to the app delegate ?
            }
        }
        else if (object == self.cameraController){
            if ([keyPath isEqualToString:@"exposureStart"]){
                [self updateExposureIndicator];
            }
            if ([keyPath isEqualToString:@"capturing"]){
                if (!self.cameraController.capturing){
                    self.progressStatusText.hidden = self.progressIndicator.hidden = YES;
                    self.captureButton.title = NSLocalizedString(@"Capture", @"Button title");
                    self.captureButton.action = @selector(capture:);
                }
                else {
                    self.progressStatusText.stringValue = @"Capturing...";
                    self.captureButton.title = NSLocalizedString(@"Cancel", @"Button title");
                    self.captureButton.action = @selector(cancelCapture:);
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
            
            CASCCDDevice* camera = self.cameraController.camera;

            [self.sensorSizeField setStringValue:[NSString stringWithFormat:@"%ld x %ld",camera.params.width,camera.params.height]];
            [self.sensorDepthField setStringValue:[NSString stringWithFormat:@"%ld bits per pixel",camera.params.bitsPerPixel]];
            [self.sensorPixelsField setStringValue:[NSString stringWithFormat:@"%0.2fµm x %0.2fµm",camera.params.pixelWidth,camera.params.pixelHeight]];
        }
    }];
    
    if (self.cameraController){
        [self.exposuresController setFilterPredicate:[NSPredicate predicateWithFormat:@"%K == %@",@"deviceID",self.cameraController.camera.uniqueID]];
    }
    else {
        [self.exposuresController setFilterPredicate:nil];
    }
    
    if ([self.exposuresController.arrangedObjects count] > 0){
        [self.exposuresController setSelectionIndex:0];
    }
    else {
        [self.exposuresController setSelectedObjects:nil];
    }
    
    if (!self.cameraController.captureCount && !self.cameraController.continuous){
        self.cameraController.captureCount = 1;
    }
}

- (void)_resetAndRedisplayCurrentExposure
{
    [self.exposures makeObjectsPerformSelector:@selector(reset)]; // reset all
    [self displayExposure:[self currentlySelectedExposure]];
}

- (void)setEqualise:(BOOL)equalise
{
    if (_equalise != equalise){
        _equalise = equalise;
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
        self.cameraController.continuous = (_captureMenuSelectedIndex == self.captureMenu.numberOfItems - 1);
        if (self.cameraController.continuous){
            self.cameraController.captureCount = 0;
        }
        else {
            self.cameraController.captureCount = _captureMenuSelectedIndex + 1;
        }
    }
}

- (void)setShowHistogram:(BOOL)showHistogram
{
    if (_showHistogram != showHistogram){
        _showHistogram = showHistogram;
        self.histogramView.hidden = !_showHistogram;
        if (_showHistogram){
            [self updateHistogram];
        }
    }
}

- (void)updateExposureIndicator
{
    NSDate* start = self.cameraController.exposureStart;
    if (self.cameraController.exposureStart){
        const double interval = [[NSDate date] timeIntervalSinceDate:start];
        const NSInteger scaling = (self.cameraController.exposureUnits == 0) ? 1 : 1000;
        self.progressIndicator.hidden = NO;
        self.progressIndicator.doubleValue = (interval * scaling) / self.cameraController.exposure;
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
        if (self.cameraController.continuous){
            self.progressIndicator.indeterminate = NO;
            self.progressIndicator.doubleValue = 1 - (self.cameraController.continuousNextExposureTime - [NSDate timeIntervalSinceReferenceDate])/(double)self.cameraController.interval;
            [self performSelector:@selector(updateExposureIndicator) withObject:nil afterDelay:0.05];
        }
        else {
            self.progressIndicator.hidden = YES;
            self.progressIndicator.doubleValue = 0;
            [self.progressIndicator stopAnimation:self];
        }
    }
}

- (void)disableAnimations:(void(^)(void))block {
    [CATransaction begin];
    [CATransaction setValue:[NSNumber numberWithFloat:0] forKey:kCATransactionAnimationDuration];
    if (block){
        block();
    }
    [CATransaction commit];
}

- (void)displayExposure:(CASCCDExposure*)exposure
{
    if (!exposure){
        [self.imageView setImage:nil imageProperties:nil];
        return;
    }
    
    NSString* title = self.cameraController.camera.deviceName;
    NSDateFormatter* exposureFormatter = [[NSDateFormatter alloc] init];
    [exposureFormatter setDateStyle:NSDateFormatterNoStyle];
    [exposureFormatter setTimeStyle:NSDateFormatterLongStyle];
    if (title){
        title = [NSString stringWithFormat:@"%@ (%@)",title,[NSString stringWithFormat:@"%@ %@",[exposureFormatter stringFromDate:exposure.date],exposure.displayExposure]];
    }
    else {
        title = [NSString stringWithFormat:@"%@ %@ %@",exposure.displayDeviceName,[exposureFormatter stringFromDate:exposure.date],exposure.displayExposure];
    }
    self.window.title = title;
    
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

    // todo: async
    [self updateHistogram];

    CASCCDImage* image = [exposure createImage];
    if (!image){
        [self.imageView setImage:nil imageProperties:nil];
        return;
    }
    
    const CASExposeParams params = exposure.params;

    const CGRect subframe = CGRectMake(params.origin.x, params.origin.y, params.size.width, params.size.height);
    
    CGImageRef CGImage = image.CGImage;
    if (CGImage){
        
        const CGRect frame = CGRectMake(0, 0, params.size.width, params.size.height);
        if (!CGRectEqualToRect(subframe, frame)){
                        
            CGContextRef bitmap = [CASCCDImage createBitmapContextWithSize:CASSizeMake(params.frame.width, params.frame.height) bitsPerPixel:params.bps];
            if (!bitmap){
                CGImage = nil;
            }
            else {
                CGContextSetRGBFillColor(bitmap,0.35,0.35,0.35,1);
                CGContextFillRect(bitmap,CGRectMake(0, 0, params.frame.width, params.frame.height));
                CGContextDrawImage(bitmap,CGRectMake(subframe.origin.x, params.frame.height - (subframe.origin.y + subframe.size.height), subframe.size.width, subframe.size.height),CGImage);
                CGImage = CGBitmapContextCreateImage(bitmap);
            }
        }
        
        if (CGImage){
            
            CGSize currentSize = CGSizeZero;
            CGImageRef currentImage = self.imageView.image;
            if (currentImage){
                currentSize = CGSizeMake(CGImageGetWidth(currentImage), CGImageGetHeight(currentImage));
            }
            
            [self disableAnimations:^{
                
                // first clear the old image (vague attempt to stop crashing when setting a new image)
                [self.imageView setImage:nil imageProperties:nil];

                // flashes when updated, hide and then show again ? draw the new image into the old image ?...
                [self.imageView setImage:CGImage imageProperties:nil];
                
                // ensure the histogram view remains at the front.
                [self.histogramView removeFromSuperview];
                [self.imageView addSubview:self.histogramView];
                
                const CGSize size = CGSizeMake(CGImageGetWidth(CGImage), CGImageGetHeight(CGImage));
                if (!currentImage || !CGSizeEqualToSize(size, currentSize)) {
                    [self.imageView zoomImageToFit:nil];  
                    self.zoomFactor = self.imageView.zoomFactor;
                }
                else {
                    const NSPoint centre = NSMakePoint(params.size.width/2,params.size.height/2);
                    if (self.zoomFactor != self.imageView.zoomFactor){
                        [self.imageView setImageZoomFactor:self.zoomFactor centerPoint:centre]; // <-- frequent crash...
                    }
                    if (self.rotationAngle != self.imageView.rotationAngle){
                        [self.imageView setRotationAngle:self.rotationAngle centerPoint:centre];
                    }
                }
            }];
        }
    }
}

- (void)updateHistogram
{
    if (self.showHistogram){
        if (!_currentExposure){
            self.histogramView.histogram = nil;
        }
        else {
            self.histogramView.histogram = [self.imageProcessor histogram:_currentExposure];
        }
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

- (void)updateExposuresMenu
{
    // todo; put most recent day/today at the top level ?
    
    NSCalendar* cal = [NSCalendar currentCalendar];

    NSMutableDictionary* dict = [NSMutableDictionary dictionaryWithCapacity:100];
    for (CASCCDExposure* exposure in self.exposuresController.arrangedObjects){
        NSDateComponents* comps = [cal components:NSYearCalendarUnit|NSMonthCalendarUnit|NSDayCalendarUnit fromDate:exposure.date];
        NSMutableArray* array = [dict objectForKey:comps];
        if (!array){
            array = [NSMutableArray arrayWithCapacity:100];
            [dict setObject:array forKey:comps];
        }
        [array addObject:exposure];
    }
    
    [self.exposuresMenu removeAllItems];
    
    NSDateFormatter* sectionFormatter = [[NSDateFormatter alloc] init];
    [sectionFormatter setDateStyle:NSDateFormatterMediumStyle];
    [sectionFormatter setTimeStyle:NSDateFormatterNoStyle];

    NSDateFormatter* exposureFormatter = [[NSDateFormatter alloc] init];
    [exposureFormatter setDateStyle:NSDateFormatterNoStyle];
    [exposureFormatter setTimeStyle:NSDateFormatterMediumStyle];
    
    NSArray* keys = [[dict allKeys] sortedArrayUsingComparator:^NSComparisonResult(NSDateComponents* obj1, NSDateComponents* obj2) {
        switch ([[cal dateFromComponents:obj1] compare:[cal dateFromComponents:obj2]]) {
            case NSOrderedAscending:
                return NSOrderedDescending;
            case NSOrderedDescending:
                return NSOrderedAscending;
            default:
                break;
        }
        return NSOrderedSame;
    }];
    for (NSDateComponents* key in keys){
        
        NSMenu* submenu = [[NSMenu alloc] initWithTitle:@""];
        for (CASCCDExposure* exp in [dict objectForKey:key]) {
            
            NSString* expTitle = [NSString stringWithFormat:@"%@\t %@\t %@",[exposureFormatter stringFromDate:exp.date],exp.displayDeviceName,exp.displayExposure];
            NSMenuItem* item = [[NSMenuItem alloc] initWithTitle:expTitle action:nil keyEquivalent:@""];
            [item setTarget:self];
            [item setAction:@selector(selectExposure:)];
            [item setRepresentedObject:exp];
            [submenu addItem:item];
        }
        
        NSDate* keyDate = [cal dateFromComponents:key];
        NSMenuItem* item = [[NSMenuItem alloc] initWithTitle:[sectionFormatter stringFromDate:keyDate] action:nil keyEquivalent:@""];
        [self.exposuresMenu.menu  addItem:item];
        [self.exposuresMenu.menu setSubmenu:submenu forItem:item];
    }
}

#pragma mark - Actions

- (IBAction)capture:(NSButton*)sender
{
    self.progressIndicator.maxValue = 1;
    self.progressIndicator.doubleValue = 0;
    self.progressStatusText.hidden = self.progressIndicator.hidden = NO;
    
    // grab the current controller
    CASCameraController* cameraController = self.cameraController;
    
    // issue the capture command
    [cameraController captureWithBlock:^(NSError *error,CASCCDExposure* exposure) {
    
        if (error){
            [NSApp presentError:error];
        }
        else{
            
            // check it's the still the currently displayed camera
            if (cameraController == self.cameraController){
                
                if (self.cameraController.continuous){
                    [self.exposuresController setSelectedObjects:nil];
                    [self displayExposure:exposure]; // do this *after* clearing the selection
                }
                else {
                    
                    // yuk
                    [self willChangeValueForKey:@"exposures"];
                    [self didChangeValueForKey:@"exposures"];
                    
                    [self.exposuresController setSelectionIndex:0];
                }
            }
            
            if (!self.cameraController.continuous){
                self.progressStatusText.hidden = self.progressIndicator.hidden = YES;
                [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(updateExposureIndicator) object:nil];
            }
            else {
                self.progressStatusText.stringValue = @"Waiting...";
            }
        }
    }];
}

- (IBAction)cancelCapture:(NSButton*)sender
{
    // this only works with continuous capture
    self.cameraController.continuous = NO;
    self.cameraController.captureCount = 0;
}

- (IBAction)saveAs:(id)sender
{
    if (!self.imageView.image){
        return;
    }
    
    IKSaveOptions* options = [[IKSaveOptions alloc] initWithImageProperties:nil imageUTType:nil];

    NSSavePanel* save = [NSSavePanel savePanel];
    
    [options addSaveOptionsAccessoryViewToSavePanel:save];
        
    [save beginSheetModalForWindow:self.window completionHandler:^(NSInteger result) {
        
        if (result == NSFileHandlingPanelOKButton){
            
            CGImageDestinationRef dest = CGImageDestinationCreateWithURL((__bridge CFURLRef)save.URL,(__bridge CFStringRef)[options imageUTType],1,NULL);
            if (dest) {
                CGImageDestinationAddImage(dest, self.imageView.image, (__bridge CFDictionaryRef)[options imageProperties]);
                CGImageDestinationFinalize(dest);
                CFRelease(dest);
            }
        }
    }];
}

#define ZOOM_IN_FACTOR  1.414214
#define ZOOM_OUT_FACTOR 0.7071068

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
    if (sender.selectedSegment == 0){
        self.imageView.currentToolMode = IKToolModeSelect;
    }
    else {
        self.imageView.currentToolMode = IKToolModeMove;
        [self selectionRectRemoved:self.imageView]; // clear the selection
        
    }
}

- (IBAction)zoomIn:(id)sender
{
    self.zoomFactor = self.zoomFactor * ZOOM_IN_FACTOR;
    self.imageView.zoomFactor = self.zoomFactor;
}

- (IBAction)zoomOut:(id)sender
{
    self.zoomFactor = self.zoomFactor * ZOOM_OUT_FACTOR;
    self.imageView.zoomFactor = self.zoomFactor;
}

- (IBAction)toggleDevices:(id)sender
{
    if (!self.detailLeadingConstraint.constant){
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
    NSString* message = (count == 1) ? @"Are you sure you want to delete this exposure ? This cannot be undone." : [NSString stringWithFormat:@"Are you sure you want to delete these %ld exposures ? This cannot be undone.",count];
    
    NSAlert* alert = [NSAlert alertWithMessageText:@"Delete Exposure"
                                     defaultButton:nil
                                   alternateButton:@"Cancel"
                                       otherButton:nil
                         informativeTextWithFormat:message,nil];
    
    [alert beginSheetModalForWindow:self.window modalDelegate:self didEndSelector:@selector(deleteConfirmSheetCompleted:returnCode:contextInfo:) contextInfo:nil];
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

- (IBAction)toggleInvertImage:(id)sender
{
    self.invert = !self.invert;
}

- (IBAction)toggleEqualiseHistogram:(id)sender
{
    self.equalise = !self.equalise;
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
    }
    return YES;
}

#pragma mark NSResponder

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

#pragma mark IKImageView delegate

- (void) selectionRectAdded: (IKImageView *) imageView
{
    NSLog(@"selectionRectAdded");
}

- (void) selectionRectRemoved: (IKImageView *) imageView
{
    self.cameraController.subframe = CGRectZero;
    [self.subframeDisplay setStringValue:@"Make a selection to define a subframe"];
}

- (void) selectionRectChanged: (IKImageView *) imageView
{
    const CGRect rect = self.imageView.selectionRect;
    CASCCDParams* params = self.cameraController.camera.params;
    CGRect subframe = CGRectMake(rect.origin.x, params.height - rect.origin.y - rect.size.height, rect.size.width,rect.size.height);;
    subframe = CGRectIntersection(subframe, CGRectMake(0, 0, params.width, params.height));
    [self.subframeDisplay setStringValue:[NSString stringWithFormat:@"x=%.0f y=%.0f\nw=%.0f h=%.0f",subframe.origin.x,subframe.origin.y,subframe.size.width,subframe.size.height]];
    self.cameraController.subframe = subframe;
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

@end

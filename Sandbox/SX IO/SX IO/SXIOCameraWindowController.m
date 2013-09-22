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
#import "CASProgressWindowController.h"
#import "CASShadowView.h"
#import "CASCaptureWindowController.h"

#import <Quartz/Quartz.h>

@interface CASControlsContainerView : NSView
@end
@implementation CASControlsContainerView
@end

@interface SXIOExposureView : CASExposureView
@end
@implementation SXIOExposureView
@end

@interface SXIOCameraWindowController ()<CASExposureViewDelegate>

@property (weak) IBOutlet NSToolbar *toolbar;
@property (weak) IBOutlet CASControlsContainerView *controlsContainerView;
@property (weak) IBOutlet NSTextField *progressStatusText;
@property (weak) IBOutlet NSProgressIndicator *progressIndicator;
@property (weak) IBOutlet NSButton *captureButton;
@property (strong) IBOutlet NSSegmentedControl *zoomControl;
@property (strong) IBOutlet NSSegmentedControl *zoomFitControl;
@property (strong) IBOutlet NSSegmentedControl *selectionControl;

@property (nonatomic,strong) CASCCDExposure *currentExposure;
@property (strong) SXIOSaveTargetViewController *saveTargetControlsViewController;
@property (strong) CASCameraControlsViewController *cameraControlsViewController;
@property (assign) BOOL equalise;

@property (nonatomic,strong) CASImageDebayer* imageDebayer;
@property (nonatomic,strong) CASImageProcessor* imageProcessor;

@property (assign) BOOL calibrate;
@property (nonatomic,strong) CASCaptureController* captureController;
@property (nonatomic,strong) CASCaptureWindowController* captureWindowController;

@end

@implementation SXIOCameraWindowController {
    NSURL* _targetFolder;
    BOOL _capturedFirstImage:1;
}

- (void)windowDidLoad
{
    [super windowDidLoad];
    
    // set up some helpers
    self.imageDebayer = [CASImageDebayer imageDebayerWithIdentifier:nil];
    self.exposureView.imageProcessor = self.imageProcessor = [CASImageProcessor imageProcessorWithIdentifier:nil];

    // set up the toolbar
    self.toolbar.displayMode = NSToolbarDisplayModeIconOnly;
    
    // watch for selection changes
    self.exposureView.exposureViewDelegate = self;

    // drop shadow
    [CASShadowView attachToView:self.exposureView.enclosingScrollView.superview edge:NSMaxXEdge];

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
    [self.saveTargetControlsViewController bind:@"cameraController" toObject:self withKeyPath:@"cameraController" options:nil];
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

- (void)presentAlertWithTitle:(NSString*)title message:(NSString*)message
{
    [[NSAlert alertWithMessageText:title
                     defaultButton:nil
                   alternateButton:nil
                       otherButton:nil
         informativeTextWithFormat:@"%@",message] runModal];
}

- (NSString*)currentDeviceExposurePathWithName:(NSString*)name
{
    NSString* path = [_targetFolder path];
    return (name && path) ? [[path stringByAppendingPathComponent:name] stringByAppendingPathExtension:[[NSUserDefaults standardUserDefaults] stringForKey:@"SXIODefaultExposureFileType"]] : nil;
}

- (CASCCDExposure*)calibrationExposureOfType:(NSString*)suffix matchingExposure:(CASCCDExposure*)exposure
{
    if (!suffix || !_targetFolder){
        return nil;
    }
    NSString* filename = [self exposureSaveNameWithSuffix:suffix];
    NSURL* fullURL = [_targetFolder URLByAppendingPathComponent:filename];
    CASCCDExposure* exp = [[CASCCDExposure alloc] init];
    if (![[CASCCDExposureIO exposureIOWithPath:[fullURL path]] readExposure:exp readPixels:YES error:nil]){
        return nil;
    }
    // check binning and dimenions match
    return exposure;
}

#pragma mark - Actions

- (NSURL*)beginAccessToSaveTarget
{
    // check we have somewhere to save the file, a prefix and a sequence number
    __block NSURL* url;
    BOOL securityScoped = NO;
    NSData* bookmark = self.saveTargetControlsViewController.saveFolderBookmark;
    if (bookmark){
        url = [NSURL URLByResolvingBookmarkData:bookmark options:NSURLBookmarkResolutionWithSecurityScope relativeToURL:nil bookmarkDataIsStale:nil error:nil];
        if (url){
            securityScoped = YES;
        }
    }
    if (!url) {
        url = self.saveTargetControlsViewController.saveFolderURL;
    }
    if (!url){
        [self presentAlertWithTitle:@"Save Folder" message:@"You need to specify a folder to save the images into"];
        return nil;
    }
    if (securityScoped && ![url startAccessingSecurityScopedResource]){
        [self presentAlertWithTitle:@"Save Folder" message:@"You don't have permission to access the image save folder or it cannot be found"];
        return nil;
    }
    
    _targetFolder = url;
    
    return url;
}

- (NSString*)exposureSaveNameWithSuffix:(NSString*)suffix
{
    NSString* prefix = self.saveTargetControlsViewController.saveImagesPrefix;
    if (!prefix){
        prefix = @"image";
    }
    if (suffix){
        prefix = [prefix stringByAppendingFormat:@"_%@",suffix];
    }
    return [prefix stringByAppendingPathExtension:[[NSUserDefaults standardUserDefaults] stringForKey:@"SXIODefaultExposureFileType"]];
}

- (IBAction)capture:(NSButton*)sender
{
    // check we have somewhere to save the file, a prefix and a sequence number
    const BOOL saveToFile = self.saveTargetControlsViewController.saveImages && !self.cameraController.continuous;
    __block NSURL* url = [self beginAccessToSaveTarget];
    
    // do not save to the library todo; replace with an exposure sink interface
    self.cameraController.autoSave = NO;
    
    // ensure this is recorded as a light frame
    self.cameraController.exposureType = kCASCCDExposureLightType;

    // issue the capture command
    [self.cameraController captureWithBlock:^(NSError *error,CASCCDExposure* exposure) {
        
        @try {

            if (error){
                // todo; run completion actions e.g. email, run processing scripts, etc
                [NSApp presentError:error];
            }
            else{
                
                // todo; async
                
                // save to 'latest' - do we really want to do this with large files ?
                // [self saveExposure:exposure withName:@"latest"];
                
                // save to the designated folder with the current settings as a fits file
                if (exposure && saveToFile){
                    
                    const NSInteger sequence = self.saveTargetControlsViewController.saveImagesSequence;
                    NSURL* finalUrl = [url URLByAppendingPathComponent:[self exposureSaveNameWithSuffix:[NSString stringWithFormat:@"%03ld",sequence+1]]];
                    ++self.saveTargetControlsViewController.saveImagesSequence;
                                        
                    CASCCDExposureIO* io = [CASCCDExposureIO exposureIOWithPath:[finalUrl path]];
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
                }

                const BOOL resetDisplay = !_capturedFirstImage || [self.exposureView shouldResetDisplayForExposure:exposure];
                [self setCurrentExposure:exposure resetDisplay:resetDisplay];
                _capturedFirstImage = YES;
            }
        }
        @finally {
            
            if (!self.cameraController.capturing){
                
                if (!self.cameraController.cancelled){
                    
                    NSUserNotification* note = [[NSUserNotification alloc] init];
                    note.title = NSLocalizedString(@"Capture Complete", @"Notification title");
                    NSString* exposureUnits = (self.cameraController.exposureUnits == 0) ? @"s" : @"ms";
                    if (self.cameraController.captureCount == 1){
                        note.subtitle = [NSString stringWithFormat:@"%ld exposure of %ld%@",(long)self.cameraController.captureCount,self.cameraController.exposure,exposureUnits];
                    }
                    else {
                        note.subtitle = [NSString stringWithFormat:@"%ld exposures of %ld%@",(long)self.cameraController.captureCount,self.cameraController.exposure,exposureUnits];
                    }
                    note.soundName = NSUserNotificationDefaultSoundName;
                    [[NSUserNotificationCenter defaultUserNotificationCenter] deliverNotification:note];

                }

                [url stopAccessingSecurityScopedResource];
            }
        }
    }];
}

- (IBAction)cancelCapture:(id)sender
{
    self.captureButton.enabled = NO;
    [self.cameraController cancelCapture];
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
        [self.exposureView zoomImageToFit:self];
    }
    else {
        [self.exposureView zoomImageToActualSize:self];
    }
}

- (IBAction)selection:(NSSegmentedControl*)sender
{
    if (sender.selectedSegment == 0 && !self.exposureView.displayingScaledSubframe){
        self.exposureView.showSelection = YES;
    }
    else {
        self.exposureView.showSelection = NO;
        [self selectionRectChanged:self.exposureView];
    }
}

- (IBAction)zoomIn:(id)sender
{
    [self.exposureView zoomIn:sender];
}

- (IBAction)zoomOut:(id)sender
{
    [self.exposureView zoomOut:sender];
}

- (IBAction)zoomImageToFit:sender
{
    [self.exposureView zoomImageToFit:sender];
}

- (IBAction)zoomImageToActualSize:sender
{
    [self.exposureView zoomImageToActualSize:sender];
}

- (IBAction)saveAs:(id)sender
{
    if (!self.currentExposure){
        return;
    }
    
    NSSavePanel* save = [NSSavePanel savePanel];
    save.canCreateDirectories = YES;
    
    IKSaveOptions* options = [[IKSaveOptions alloc] initWithImageProperties:nil imageUTType:nil]; // leaks ?
    [options addSaveOptionsAccessoryViewToSavePanel:save];
    
    // run the save panel and save the exposures to the selected location
    [self runSavePanel:save forExposures:@[self.currentExposure] withProgressLabel:NSLocalizedString(@"Saving...", @"Progress text") exportBlock:^(CASCCDExposure* exposure) {
        
        NSData* data = [[exposure newImage] dataForUTType:options.imageUTType options:options.imageProperties];
        if (!data){
            NSLog(@"*** Failed to create image from exposure");
        }
        else {
            
            NSError* error;
            [data writeToFile:save.URL.path options:NSDataWritingAtomic error:&error];
            if (error){
                dispatch_async(dispatch_get_main_queue(), ^{
                    [NSApp presentError:error];
                });
            }
        }
    } completionBlock:nil];
}

- (IBAction)saveToFITS:(id)sender
{
    if (!self.currentExposure){
        return;
    }
    
    NSSavePanel* save = [NSSavePanel savePanel];
    save.canCreateDirectories = YES;
    
    save.allowedFileTypes = [[NSUserDefaults standardUserDefaults] arrayForKey:@"SXIODefaultExposureFileTypes"];
    
    [self runSavePanel:save forExposures:@[self.currentExposure] withProgressLabel:NSLocalizedString(@"Exporting...", @"Progress text") exportBlock:^(CASCCDExposure* exposure) {
        
        NSURL* url = save.URL;
        if (![save.allowedFileTypes containsObject:url.pathExtension]){
            url = [save.URL URLByAppendingPathExtension:[[NSUserDefaults standardUserDefaults] stringForKey:@"SXIODefaultExposureFileType"]];
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

- (void)presentCaptureControllerWithMode:(NSInteger)mode
{
    if (!self.cameraController || self.cameraController.capturing){
        return;
    }
    
    NSURL* url = [self beginAccessToSaveTarget];
    if (!url){
        // alert
        return;
    }
    
    // do not save to the library todo; replace with an exposure sink interface
    self.cameraController.autoSave = NO;

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
                progress.canCancel = YES;
                
                self.captureController.imageProcessor = self.imageProcessor;
                self.captureController.cameraController = self.cameraController;
                
                // self.cameraController pushExposureSettings
                
                __block BOOL inPostProcessing = NO;
                
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
                        progress.progressBar.doubleValue++;
                    });
                    
                } completion:^(NSError *error,CASCCDExposure* result) {
                    
                    if (error){
                        [NSApp presentError:error];
                    }
                    else {
                        
                        if (!self.captureController.cancelled){
                            
                            NSString* name = nil;
                            switch (mode) {
                                case kCASCaptureModelModeDark:
                                    name = @"dark";
                                    break;
                                case kCASCaptureModelModeBias:
                                    name = @"bias";
                                    break;
                                case kCASCaptureModelModeFlat:
                                    name = @"flat";
                                    break;
                            }
                            
                            NSURL* finalUrl = [url URLByAppendingPathComponent:[self exposureSaveNameWithSuffix:name]];
                            
                            // remove existing one
                            [[NSFileManager defaultManager] removeItemAtURL:finalUrl error:nil];
                            
                            // save new one
                            NSError* error;
                            [[CASCCDExposureIO exposureIOWithPath:[finalUrl path]] writeExposure:result writePixels:YES error:&error];
                            if (error){
                                [NSApp presentError:error];
                            }
                            
                            self.currentExposure = result;
                        }
                    }
                    
                    [progress endSheetWithCode:NSOKButton];
                    
                    // self.cameraController popExposureSettings
                }];
            }
            
            [url stopAccessingSecurityScopedResource];
        }
    }];
}

- (IBAction)captureDarks:(id)sender
{
    [self presentCaptureControllerWithMode:kCASCaptureModelModeDark];
}

- (IBAction)deleteDarks:(id)sender
{
//    [self removeExposureWithName:@"dark"];
}

- (IBAction)captureBias:(id)sender
{
    [self presentCaptureControllerWithMode:kCASCaptureModelModeBias];
}

- (IBAction)deleteBias:(id)sender
{
//    [self removeExposureWithName:@"bias"];
}

- (IBAction)captureFlats:(id)sender
{
    [self presentCaptureControllerWithMode:kCASCaptureModelModeFlat];
}

- (IBAction)deleteFlats:(id)sender
{
//    [self removeExposureWithName:@"flat"];
}

#pragma mark - Save Utilities

- (void)runSavePanel:(NSSavePanel*)save forExposures:(NSArray*)exposures withProgressLabel:(NSString*)progressLabel exportBlock:(void(^)(CASCCDExposure*))exportBlock completionBlock:(void(^)(void))completionBlock
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

#pragma mark - Exposure Display

- (void)configureForCameraController
{
    NSString* title = self.cameraController.camera.deviceName;
    if (title){
        self.window.title = title;
    }
    else {
        self.window.title = @"";
    }
    
    if (!self.cameraController){
        
        self.currentExposure = nil;
    }
    else {
        
        // set the current displayed exposure to the last one recorded by this camera controller
        // (specifically check for pixels as this will detect if the backing store has been deleted)
        if (self.cameraController.lastExposure.pixels){
            self.currentExposure = self.cameraController.lastExposure;
        }
        else{
            self.currentExposure = nil; // [self exposureWithName:@"latest"];
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
        
        [self zoomImageToFit:nil];
    }
    
    // set progress display if this camera is capturing
    [self updateExposureIndicator];
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
                if (self.cameraController.captureCount > 1){
                    self.progressStatusText.stringValue = [NSString stringWithFormat:@"Capturing %ld of %ld...",self.cameraController.currentCaptureIndex+1,self.cameraController.captureCount];
                }
                else {
                    self.progressStatusText.stringValue = @"Capturing...";
                }
            }
        }
            break;
    }
    
    if (self.progressIndicator.isIndeterminate){
        self.progressIndicator.usesThreadedAnimation = YES;
        [self.progressIndicator startAnimation:nil];
    }
    else {
        [self.progressIndicator stopAnimation:nil];
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
    [self displayExposure:exposure resetDisplay:YES];
}

- (void)displayExposure:(CASCCDExposure*)exposure resetDisplay:(BOOL)resetDisplay
{
    if (!exposure){
        self.exposureView.currentExposure = nil;
        return;
    }
        
    // check image view is actually visible before bothering to display it
    if (!self.exposureView.isHiddenOrHasHiddenAncestor){
        
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
            CASCCDExposure* debayeredExposure = [self.imageDebayer debayer:exposure adjustRed:1 green:1 blue:1 all:1];
            if (debayeredExposure){
                exposure = debayeredExposure;
            }
        }
        
        // optionally live calibrate using saved bias and flat frames
        if (/*self.calibrate*/1){
            
            NSURL* url = [self beginAccessToSaveTarget];
            if (url){
                
                __block BOOL called = NO;
                __block CASCCDExposure* corrected = exposure;
                CASCCDCorrectionProcessor* corrector = [[CASCCDCorrectionProcessor alloc] init];
                corrector.dark = [self calibrationExposureOfType:@"dark" matchingExposure:exposure];
                corrector.bias = [self calibrationExposureOfType:@"bias" matchingExposure:exposure];
                corrector.flat = [self calibrationExposureOfType:@"flat" matchingExposure:exposure];
                [corrector processWithProvider:^(CASCCDExposure **exposurePtr, NSDictionary **info) {
                    if (!called){
                        *exposurePtr = exposure;
                    }
                    else {
                        *exposurePtr = nil;
                    }
                    called = YES;
                } completion:^(NSError *error, CASCCDExposure *result) {
                    if (!error){
                        corrected = result;
                    }
                }];
                exposure = corrected;
                
                [url stopAccessingSecurityScopedResource];
            }
        }
        
        // optionally equalise
        if (self.equalise){
            exposure = [self.imageProcessor equalise:exposure];
        }
        
        [self.exposureView setCurrentExposure:exposure resetDisplay:resetDisplay];
    }
}

- (void)clearSelection
{
    self.selectionControl.selectedSegment = 1;
    [self selection:self.selectionControl]; // yuk
}

- (void)setCurrentExposure:(CASCCDExposure *)currentExposure
{
    [self setCurrentExposure:currentExposure resetDisplay:YES];
}

- (void)setCurrentExposure:(CASCCDExposure *)currentExposure resetDisplay:(BOOL)resetDisplay
{
    if (_currentExposure != currentExposure){
        
        // unload the current exposure's pixels
        [_currentExposure reset];
        
        _currentExposure = currentExposure;
        
        // display the exposure
        [self displayExposure:_currentExposure resetDisplay:resetDisplay];
        
        // clear selection - necessary ?
        if (!_currentExposure){
            [self clearSelection];
        }
    }
}

- (void)resetAndRedisplayCurrentExposure
{
    if (self.currentExposure){
        [self.currentExposure reset];
        [self displayExposure:self.currentExposure];
    }
}

#pragma mark - CASExposureView delegate

- (void) selectionRectChanged: (CASExposureView*) imageView
{
    //    NSLog(@"selectionRectChanged: %@",NSStringFromRect(imageView.selectionRect));
    
    if (self.exposureView.image){
        
        const CGRect rect = self.exposureView.selectionRect;
        if (CGRectIsEmpty(rect)){
            
            self.cameraController.subframe = CGRectZero;
        }
        else {
            
            CGSize size = CGSizeZero;
            CASCCDProperties* sensor = self.cameraController.camera.sensor;
            if (sensor){
                size = CGSizeMake(sensor.width, sensor.height);
            }
            else {
                size = CGSizeMake(CGImageGetWidth(self.exposureView.CGImage), CGImageGetHeight(self.exposureView.CGImage));
            }
            
            CGRect subframe = CGRectMake(rect.origin.x, size.height - rect.origin.y - rect.size.height, rect.size.width,rect.size.height);
            subframe = CGRectIntersection(subframe, CGRectMake(0, 0, size.width, size.height));
            self.cameraController.subframe = subframe;
        }
    }
}

#pragma mark - NSToolbar delegate

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
    return [NSArray arrayWithObjects:@"ZoomInOut",@"ZoomFit",@"Selection",nil];
}

#pragma mark - Menu validation

- (IBAction)toggleShowHistogram:(id)sender
{
    self.exposureView.showHistogram = !self.exposureView.showHistogram;
}

- (IBAction)toggleShowReticle:(id)sender
{
    self.exposureView.showReticle = !self.exposureView.showReticle;
}

- (IBAction)toggleShowStarProfile:(id)sender
{
    self.exposureView.showStarProfile = !self.exposureView.showStarProfile;
}

- (IBAction)toggleShowImageStats:(id)sender
{
    self.exposureView.showImageStats = !self.exposureView.showImageStats;
}

- (IBAction)toggleInvertImage:(id)sender
{
    self.exposureView.invert = !self.exposureView.invert;
}

- (IBAction)toggleMedianFilter:(id)sender
{
    self.exposureView.medianFilter = !self.exposureView.medianFilter;
}

- (IBAction)toggleEqualiseHistogram:(id)sender
{
    self.equalise = !self.equalise;
    [self resetAndRedisplayCurrentExposure];
}

- (IBAction)toggleContrastStretch:(id)sender
{
    self.exposureView.contrastStretch = !self.exposureView.contrastStretch;
}

- (IBAction)toggleCalibrate:(id)sender
{
    self.calibrate = !self.calibrate;
    [self resetAndRedisplayCurrentExposure];
}

- (IBAction)applyDebayer:(NSMenuItem*)sender
{
    switch (sender.tag) {
        case 11000:
            self.imageDebayer.mode = kCASImageDebayerNone;
            break;
        case 11001:
            self.imageDebayer.mode = kCASImageDebayerRGGB;
            break;
        case 11002:
            self.imageDebayer.mode = kCASImageDebayerGRBG;
            break;
        case 11003:
            self.imageDebayer.mode = kCASImageDebayerBGGR;
            break;
        case 11004:
            self.imageDebayer.mode = kCASImageDebayerGBRG;
            break;
    }
    [self resetAndRedisplayCurrentExposure];
}

- (BOOL)validateMenuItem:(NSMenuItem*)item
{
    BOOL enabled = YES;
    
    if (item.action == @selector(saveAs:) || item.action == @selector(saveToFITS:)){
        enabled = self.currentExposure != nil;
    }
    else switch (item.tag) {
            
        case 10000:
            item.state = self.exposureView.showHistogram;
            break;
            
        case 10001:
            item.state = self.exposureView.invert;
            break;
            
        case 10002:
            item.state = self.equalise;
            break;
            
        case 10006:
            item.state = self.exposureView.medianFilter;
            break;
            
        case 10030:
            item.state = self.exposureView.contrastStretch;
            break;

        case 10003:
            item.state = self.exposureView.showReticle;
            break;
            
        case 10004:
            item.state = self.exposureView.showStarProfile;
            break;
            
        case 10005:
            item.state = self.exposureView.showImageStats;
            break;
            
        case 10010:
            item.state = self.exposureView.scaleSubframe;
            break;
                        
        case 10012:
            enabled = (self.currentExposure != nil && !self.cameraController.capturing);
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
            
            // todo; option to show debayerd image as luminance image
            
        case 11100:
            item.state = self.calibrate;
            break;
        case 11101:
            break;

    }
    return enabled;
}

@end

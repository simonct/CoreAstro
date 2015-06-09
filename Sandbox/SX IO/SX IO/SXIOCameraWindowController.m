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
#import "CASFilterWheelControlsViewController.h"
#import "CASProgressWindowController.h"
#import "CASShadowView.h"
#import "CASCaptureWindowController.h"
#import "SXIOPlateSolveOptionsWindowController.h"
#import "SXIOSequenceEditorWindowController.h"
#import "CASMountWindowController.h"
#import "SXIOFocuserWindowController.h"
#import <CoreAstro/ORSSerialPortManager.h>

#import <Quartz/Quartz.h>
#import <CoreLocation/CoreLocation.h>

static NSString* const kSXIOCameraWindowControllerDisplayedSleepWarningKey = @"SXIOCameraWindowControllerDisplayedSleepWarning";

@interface CASControlsInnerContainerView : NSView
@end
@implementation CASControlsInnerContainerView
- (BOOL)isFlipped
{
    return YES;
}
@end

@interface SXIOExposureView : CASExposureView
@end
@implementation SXIOExposureView
@end

@interface SXIOCameraWindowController ()<CASExposureViewDelegate,CASCameraControllerSink,CASMountWindowControllerDelegate>

@property (weak) IBOutlet NSToolbar *toolbar;
@property (weak) IBOutlet NSScrollView *containerScrollView;
@property (weak) IBOutlet NSTextField *progressStatusText;
@property (weak) IBOutlet NSProgressIndicator *progressIndicator;
@property (weak) IBOutlet NSButton *captureButton;
@property (strong) IBOutlet NSSegmentedControl *zoomControl;
@property (strong) IBOutlet NSSegmentedControl *zoomFitControl;
@property (strong) IBOutlet NSSegmentedControl *selectionControl;

@property (nonatomic,strong) CASCCDExposure *currentExposure;
@property (strong) SXIOSaveTargetViewController *saveTargetControlsViewController;
@property (strong) CASCameraControlsViewController *cameraControlsViewController;
@property (strong) CASFilterWheelControlsViewController *filterWheelControlsViewController;
@property (assign) BOOL equalise;

@property (nonatomic,strong) CASImageDebayer* imageDebayer;
@property (nonatomic,strong) CASImageProcessor* imageProcessor;
@property (nonatomic,strong) CASGuideAlgorithm* guideAlgorithm; // used for star detection - todo; probably put into image metrics

@property (assign) BOOL calibrate;
@property (nonatomic,strong) CASCaptureController* captureController;
@property (nonatomic,strong) CASCaptureWindowController* captureWindowController;

@property (nonatomic,strong) SXIOPlateSolveOptionsWindowController* plateSolveOptionsWindowController;
@property (nonatomic,strong) SXIOSequenceEditorWindowController* sequenceEditorWindowController;

@property (assign) BOOL showPlateSolution;
@property (nonatomic,strong) CASPlateSolver* plateSolver;
@property (nonatomic,readonly) NSString* cachesDirectory;

@property (nonatomic,copy) NSString* cameraDeviceID;

// mount control
@property (strong) CASMount* mount;
@property (weak) ORSSerialPort* selectedSerialPort;
@property (strong) ORSSerialPortManager* serialPortManager;
@property (strong) IBOutlet NSWindow *mountConnectWindow;
@property (strong) CASMountWindowController* mountWindowController;

@property (strong) CASProgressWindowController* mountFlipProgress;

// focusing
@property (strong) SXIOFocuserWindowController* focuserWindowController;

@end

@implementation SXIOCameraWindowController {
    NSURL* _targetFolder;
    BOOL _capturedFirstImage:1;
}

static void* kvoContext;

- (void)windowDidLoad
{
    [super windowDidLoad];
    
    // set up some helpers
    self.imageDebayer = [CASImageDebayer imageDebayerWithIdentifier:nil];
    self.exposureView.imageProcessor = self.imageProcessor = [CASImageProcessor imageProcessorWithIdentifier:nil];
    self.exposureView.guideAlgorithm = self.guideAlgorithm = [CASGuideAlgorithm guideAlgorithmWithIdentifier:nil];;

    // set up the toolbar
    self.toolbar.displayMode = NSToolbarDisplayModeIconOnly;
    
    // watch for selection changes
    self.exposureView.exposureViewDelegate = self;

    // drop shadow
    [CASShadowView attachToView:self.exposureView.enclosingScrollView.superview edge:NSMaxXEdge];

    NSView* container = [[CASControlsInnerContainerView alloc] initWithFrame:CGRectZero];
    
    // slot the camera controls into the controls container view todo; make this layout code part of the container view or its controller
    self.cameraControlsViewController = [[CASCameraControlsViewController alloc] initWithNibName:@"CASCameraControlsViewController" bundle:nil];
    self.cameraControlsViewController.view.translatesAutoresizingMaskIntoConstraints = NO;
    [container addSubview:self.cameraControlsViewController.view];
    
    // layout camera controls
    id cameraControlsViewController1 = self.cameraControlsViewController.view;
    NSDictionary* viewNames = NSDictionaryOfVariableBindings(cameraControlsViewController1);
    [container addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|[cameraControlsViewController1]|" options:0 metrics:nil views:viewNames]];
    [container addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|[cameraControlsViewController1(==height)]" options:NSLayoutFormatAlignAllCenterX metrics:@{@"height":@(self.cameraControlsViewController.view.frame.size.height)} views:viewNames]];

    // filter wheel controls
    self.filterWheelControlsViewController = [[CASFilterWheelControlsViewController alloc] initWithNibName:@"CASFilterWheelControlsViewController" bundle:nil];
    self.filterWheelControlsViewController.view.translatesAutoresizingMaskIntoConstraints = NO;
    [container addSubview:self.filterWheelControlsViewController.view];
    
    // layout filter wheel controls
    id filterWheelControlsViewController1 = self.filterWheelControlsViewController.view;
    viewNames = NSDictionaryOfVariableBindings(cameraControlsViewController1,filterWheelControlsViewController1);
    [container addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|[filterWheelControlsViewController1]|" options:0 metrics:nil views:viewNames]];
    [container addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:[cameraControlsViewController1][filterWheelControlsViewController1(==height)]" options:NSLayoutFormatAlignAllCenterX metrics:@{@"height":@(self.filterWheelControlsViewController.view.frame.size.height)} views:viewNames]];

    // save target controls
    self.saveTargetControlsViewController = [[SXIOSaveTargetViewController alloc] initWithNibName:@"SXIOSaveTargetViewController" bundle:nil];
    self.saveTargetControlsViewController.view.translatesAutoresizingMaskIntoConstraints = NO;
    [container addSubview:self.saveTargetControlsViewController.view];
    
    // layout save target controls
    id saveTargetControlsViewController1 = self.saveTargetControlsViewController.view;
    viewNames = NSDictionaryOfVariableBindings(filterWheelControlsViewController1,saveTargetControlsViewController1);
    [container addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|[saveTargetControlsViewController1]|" options:0 metrics:nil views:viewNames]];
    [container addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:[filterWheelControlsViewController1][saveTargetControlsViewController1(==height)]" options:NSLayoutFormatAlignAllCenterX metrics:@{@"height":@(self.saveTargetControlsViewController.view.frame.size.height)} views:viewNames]];
    
    CGFloat height = 0;
    for (NSView* view in container.subviews){
        height += CGRectGetHeight(view.frame);
    }
    container.frame = CGRectMake(0, 0, CGRectGetWidth(self.containerScrollView.frame) - 2, height); // -2 prevents horizontal scrolling
    self.containerScrollView.documentView = container;
    
    // bind the controllers
    [self.cameraControlsViewController bind:@"cameraController" toObject:self withKeyPath:@"cameraController" options:nil];
    [self.cameraControlsViewController bind:@"exposure" toObject:self withKeyPath:@"currentExposure" options:nil];
    [self.saveTargetControlsViewController bind:@"cameraController" toObject:self withKeyPath:@"cameraController" options:nil];
    [self.filterWheelControlsViewController bind:@"cameraController" toObject:self withKeyPath:@"cameraController" options:nil];
    
    // observe the save target vc for save url changes; get the initial one and request access to it
    [self.saveTargetControlsViewController addObserver:self forKeyPath:@"saveFolderURL" options:NSKeyValueObservingOptionInitial context:&kvoContext];
    
    // bind the exposure view's auto contrast stretch flag to the defaults controlled by the menu view
    [self.exposureView bind:@"autoContrastStretch" toObject:[NSUserDefaults standardUserDefaults] withKeyPath:@"SXIOAutoContrastStretch" options:nil];
    
    // listen to mount flipped notifications (todo; put in camera controller/capture controller?)
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(mountFlipped:) name:CASMountFlippedNotification object:nil];
    
    // map close button to hide window
    NSButton* close = [self.window standardWindowButton:NSWindowCloseButton];
    [close setTarget:self];
    [close setAction:@selector(hideWindow:)];
}

- (void)dealloc
{
    if (_targetFolder){
        [_targetFolder stopAccessingSecurityScopedResource];
    }
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)hideWindow:sender
{
    if (self.cameraController){
        [self.window orderOut:nil];
    }
    else {
        [self close];
    }
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if (context == &kvoContext) {
        
        if (object == self.cameraController){
            if ([keyPath isEqualToString:@"state"] || [keyPath isEqualToString:@"progress"]){
                [self updateExposureIndicator];
            }
        }
        
        if (object == self.saveTargetControlsViewController){
            if ([keyPath isEqualToString:@"saveFolderURL"]){
                if (self.saveTargetControlsViewController.saveFolderURL && ![self beginAccessToSaveTarget]){
                    self.saveTargetControlsViewController.saveFolderURL = nil;
                }
            }
        }
    }
    else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

- (NSString*) cachesDirectory
{
    NSString* cache = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) firstObject];
    cache = [cache stringByAppendingPathComponent:[[NSBundle mainBundle] bundleIdentifier]];
    return cache;
}

- (void)setCameraController:(CASCameraController *)cameraController
{
    if (_cameraController != cameraController){
        if (_cameraController){
            [_cameraController removeObserver:self forKeyPath:@"state" context:&kvoContext];
            [_cameraController removeObserver:self forKeyPath:@"progress" context:&kvoContext];
            if (!cameraController) {
                self.window.title = [NSString stringWithFormat:@"%@ (Disconnected)",self.cameraController.camera.deviceName];
            }
        }
        _cameraController = cameraController;
        if (_cameraController){
            [_cameraController addObserver:self forKeyPath:@"state" options:0 context:&kvoContext];
            [_cameraController addObserver:self forKeyPath:@"progress" options:0 context:&kvoContext];
            [self configureForCameraController];
        }
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

#pragma mark - Actions

- (NSURL*)beginAccessToSaveTarget // todo; NSError** param with reasons for failure
{
    if (_targetFolder){
        [_targetFolder stopAccessingSecurityScopedResource];
    }
    _targetFolder = nil;
    
    // check we have somewhere to save the file, a prefix and a sequence number
    __block NSURL* url;
    BOOL securityScoped = NO;
    NSData* bookmark = self.saveTargetControlsViewController.saveFolderBookmark;
    if (bookmark){
        url = [NSURL URLByResolvingBookmarkData:bookmark options:NSURLBookmarkResolutionWithSecurityScope relativeToURL:nil bookmarkDataIsStale:nil error:nil];
        if (url){
            // folder might be in the Trash
            NSString* path = [url path];
            for (NSURL* trash in [[NSFileManager defaultManager] URLsForDirectory:NSTrashDirectory inDomains:NSAllDomainsMask]){
                NSString* trashPath = [trash path];
                if (![trashPath hasSuffix:@"/"]){
                    trashPath = [trashPath stringByAppendingString:@"/"];
                }
                if ([path hasPrefix:trashPath]){
                    NSLog(@"Looks like %@ is in the Trash located at %@",path,trashPath);
                    url = nil;
                    break;
                }
            }
            if (url){
                securityScoped = YES;
            }
        }
    }
    if (!url) {
        url = self.saveTargetControlsViewController.saveFolderURL;
    }
    
    if (![[NSFileManager defaultManager] fileExistsAtPath:url.path]){
        NSLog(@"Couldn't locate %@",url);
        url = nil;
    }
    else if (securityScoped && ![url startAccessingSecurityScopedResource]){
        NSLog(@"Failed to get access to %@",url);
        url = nil;
    }
    
    _targetFolder = url;
    
    return url;
}

// todo; belongs in its own class ?
- (NSString*)exposureSaveNameWithSuffix:(NSString*)suffix fileType:(NSString*)fileType
{
    NSString* prefix = self.saveTargetControlsViewController.saveImagesPrefix;
    if (!prefix){
        prefix = @"image";
    }
    if (suffix){
        prefix = [prefix stringByAppendingFormat:@"_%@",suffix];
    }
    
    if (!fileType){
        fileType = [[NSUserDefaults standardUserDefaults] stringForKey:@"SXIODefaultExposureFileType"];
    }
    return [prefix stringByAppendingPathExtension:fileType];
}

- (IBAction)capture:(NSButton*)sender
{
    // todo; need a more generic mechanism to express 'ready to capture'
    NSError* error;
    if (![self prepareToStartSequenceWithError:&error]){
        [NSApp presentError:error];
        return;
    }
    
    // pop a sleep warning alert
    if (![[NSUserDefaults standardUserDefaults] boolForKey:kSXIOCameraWindowControllerDisplayedSleepWarningKey]){
        
        NSAlert* alert = [NSAlert alertWithMessageText:@"System Sleep"
                                         defaultButton:@"OK"
                                       alternateButton:@"Cancel"
                                           otherButton:nil
                             informativeTextWithFormat:@"%@ prevents your Mac from sleeping during exposures. Please ensure that your Mac has sufficient battery power to complete the session or is plugged into a power source.",[[NSBundle mainBundle] objectForInfoDictionaryKey:(NSString*)kCFBundleNameKey]];
        alert.showsSuppressionButton = YES;
        if ([alert runModal] != NSOKButton){
            return;
        }
        if (alert.suppressionButton.state){
            [[NSUserDefaults standardUserDefaults] setBool:YES forKey:kSXIOCameraWindowControllerDisplayedSleepWarningKey];
        }
    }

    [self captureWithCompletion:^(NSError* error) {
        if (error){
            [NSApp presentError:error];
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
        if (!self.cameraController.camera.canSubframe){
            NSBeep(); // alert ?
            sender.selectedSegment = 1;
            self.exposureView.showSelection = NO;
        }
        else {
            self.exposureView.showSelection = YES;
        }
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

- (IBAction)openDocument:(id)sender
{
    if (self.cameraController.capturing){
        return;
    }
    
    NSOpenPanel* openPanel = [NSOpenPanel openPanel];
    
    openPanel.allowedFileTypes = [[NSUserDefaults standardUserDefaults] arrayForKey:@"SXIODefaultExposureFileTypes"];
    
    [openPanel beginSheetModalForWindow:self.window completionHandler:^(NSInteger result) {
        if (result == NSFileHandlingPanelOKButton){
            [self openExposureAtPath:openPanel.URL.path];
        }
    }];
}

- (BOOL)openExposureAtPath:(NSString*)path
{
    NSError* error;
    CASCCDExposure* exposure = [CASCCDExposureIO exposureWithPath:path readPixels:YES error:nil];
    if (exposure){
        self.currentExposure = exposure;
        [self.cameraController updateSettingsWithExposure:exposure];
        [self updateWindowTitleWithExposurePath:path];
        [[NSDocumentController sharedDocumentController] noteNewRecentDocumentURL:[NSURL fileURLWithPath:path]];
    }
    else if (error){
        [NSApp presentError:error];
    }
    return (error == nil);
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
        // running this on the default queue results in KVO errors when the save panel's dismissed so run on main
        dispatch_async(dispatch_get_main_queue(), ^{
            [self saveCIImage:self.exposureView.filteredCIImage toPath:save.URL.path type:options.imageUTType properties:options.imageProperties];
        });
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
        // running this on the default queue results in KVO errors when the save panel's dismissed so run on main
        dispatch_async(dispatch_get_main_queue(), ^{
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
        });
    } completionBlock:nil];
}

- (void)presentCaptureControllerWithMode:(NSInteger)mode
{
    if (!self.cameraController || self.cameraController.capturing){
        return;
    }
    
    if (!self.saveTargetControlsViewController.saveImages || !_targetFolder){
        [self presentAlertWithTitle:@"Save Folder" message:@"You need to specify a folder to save the images into"];
        return;
    }
    
    self.captureWindowController = [CASCaptureWindowController createWindowController];
    self.captureWindowController.model.captureCount = 25;
    self.captureWindowController.model.captureMode = mode;
    self.captureWindowController.model.combineMode = kCASCaptureModelCombineAverage;
    
    BOOL (^saveExposure)() = ^BOOL(CASCCDExposure* exposure,NSInteger mode,NSInteger sequence,NSError** error){
        
        // check for a user-entered filter name
        NSString* filterName = self.filterWheelControlsViewController.filterName;
        if ([filterName length]){
            exposure.filters = @[filterName];
        }
        
        // construct the exposure name
        NSURL* finalUrl;
        NSString* prefix = self.saveTargetControlsViewController.saveImagesPrefix;
        if ([prefix rangeOfString:@"$type"].location == NSNotFound){
            prefix = [prefix stringByAppendingString:@"_$type"];
        }
        if (sequence > 0){
            prefix = [NSString stringWithFormat:@"%@_%03ld",prefix,sequence];
        }
        finalUrl = [[_targetFolder URLByAppendingPathComponent:[exposure stringBySubstitutingPlaceholders:prefix]] URLByAppendingPathExtension:@"fits"];
        
        // remove existing one
        [[NSFileManager defaultManager] removeItemAtURL:finalUrl error:nil];
        
        // save new one
        return [[CASCCDExposureIO exposureIOWithPath:[finalUrl path]] writeExposure:exposure writePixels:YES error:error];
    };
    
    [self.captureWindowController beginSheetModalForWindow:self.window completionHandler:^(NSInteger result) {
        
        if (result == NSOKButton){
            
            self.captureController = [CASCaptureController captureControllerWithWindowController:self.captureWindowController];
            self.captureWindowController = nil;
            if (self.captureController){
                
                CASProgressWindowController* progress = [CASProgressWindowController createWindowController];
                [progress beginSheetModalForWindow:self.window];
                [progress configureWithRange:NSMakeRange(0, self.captureController.model.captureCount) label:NSLocalizedString(@"Capturing...", @"Progress sheet label")];
                progress.canCancel = YES;
                progress.cancelBlock = ^(){
                    [self.captureController cancelCapture];
                };
                
                self.captureController.imageProcessor = self.imageProcessor;
                self.captureController.cameraController = self.cameraController;
                
                // self.cameraController pushExposureSettings
                
                __block NSInteger sequence = 0;
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
                        if (self.captureController.model.combineMode == kCASCaptureModelCombineNone){
                            NSError* error;
                            saveExposure(exposure,mode,++sequence,&error);
                            if (error){
                                dispatch_async(dispatch_get_main_queue(), ^{
                                    [NSApp presentError:error];
                                });
                            }
                        }
                        progress.progressBar.doubleValue++;
                    });
                    
                } completion:^(NSError *error,CASCCDExposure* result) {
                    
                    if (error){
                        [NSApp presentError:error];
                    }
                    else if (result) {
                        
                        if (!self.captureController.cancelled){
                            
                            NSError* error;
                            saveExposure(result,mode,0,&error);
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
        }
    }];
}

- (IBAction)captureDarks:(id)sender
{
    [self presentCaptureControllerWithMode:kCASCaptureModelModeDark];
}

- (IBAction)captureBias:(id)sender
{
    [self presentCaptureControllerWithMode:kCASCaptureModelModeBias];
}

- (IBAction)captureFlats:(id)sender
{
    [self presentCaptureControllerWithMode:kCASCaptureModelModeFlat];
}

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

- (IBAction)toggleShowPlateSolution:(id)sender
{
    self.showPlateSolution = !self.showPlateSolution;
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

- (IBAction)toggleFlipVertical:(id)sender
{
    self.exposureView.flipVertical = !self.exposureView.flipVertical;
}

- (IBAction)toggleFlipHorizontal:(id)sender
{
    self.exposureView.flipHorizontal = !self.exposureView.flipHorizontal;
}

- (IBAction)sequence:(id)sender
{
    self.sequenceEditorWindowController = [SXIOSequenceEditorWindowController createWindowController];
    self.sequenceEditorWindowController.target = self;
    [self.sequenceEditorWindowController beginSheetModalForWindow:self.window completionHandler:^(NSInteger result) {
        self.sequenceEditorWindowController = nil;
    }];
}

#pragma mark - Mount Control

- (IBAction)connectToMount:(id)sender
{
    if (!self.serialPortManager){
        self.serialPortManager = [ORSSerialPortManager sharedSerialPortManager];
    }
    self.selectedSerialPort = [self.serialPortManager.availablePorts firstObject];
    [self.mountConnectWindow makeKeyAndOrderFront:nil]; // sheet ? todo; config UI should come from the driver...
}

- (IBAction)connectButtonPressed:(id)sender
{
    if (!self.selectedSerialPort){
        return;
    }
    
    if (self.selectedSerialPort.isOpen){
        [self presentAlertWithTitle:nil message:@"Selected serial port is already open"];
        return;
    }
    
    [self.mountConnectWindow orderOut:nil];
    
    self.mount = [[iEQMount alloc] initWithSerialPort:self.selectedSerialPort];
    
    if (self.mount.slewing){
        [self presentAlertWithTitle:nil message:@"Mount is slewing. Please try again when it's stopped"];
        return;
    }
    
    self.mountWindowController = [[CASMountWindowController alloc] initWithWindowNibName:@"CASMountWindowController"];
    [self.mountWindowController connectToMount:self.mount completion:^(NSError* error) {
        if (error){
            [self presentAlertWithTitle:nil message:[error localizedDescription]];
        }
        else {
            self.mountWindowController.cameraController = self.cameraController;
            self.mountWindowController.mountWindowDelegate = self;
            CASPlateSolveSolution* solution = self.exposureView.plateSolveSolution;
            if (solution){
                [self.mountWindowController setTargetRA:solution.centreRA dec:solution.centreDec];
            }
        }
    }];
}

- (void)mountFlipped
{
    // stop phd2 guiding whether we're capturing or not
    [self.cameraController.phd2Client stop];

    // could be a manual flip, only handle if we're capturing - possibly have a timeout alert?
    if (!self.cameraController.capturing){
        NSLog(@"Not handling flip as the camera is not currently capturing");
        return;
    }
    
    // cancel any current capture
    [self.cameraController cancelCapture];
    
    // if we've got a locked solution, attempt to recover after the flip
    if (!self.exposureView.lockedPlateSolveSolution){
        [self presentAlertWithTitle:@"Exposure Cancelled" message:@"A mount flip was detected without a locked solution."];
    }
    else {
        
        // check for the mount window as that currently handles slew and sync (job for a mount controller class probably)
        if (!self.mountWindowController){
            [self presentAlertWithTitle:@"Exposure Cancelled" message:@"A mount flip was detected without a connected mount."];
        }
        else {
            
            // check to see if we're in a commanded slew before attempting to handle
            
            // present a sheet with some status info
            self.mountFlipProgress = [CASProgressWindowController createWindowController];
            [self.mountFlipProgress beginSheetModalForWindow:self.window];
            self.mountFlipProgress.label.stringValue = NSLocalizedString(@"Waiting for mount to flip...", @"Progress sheet status label");
            [self.mountFlipProgress.progressBar setIndeterminate:YES];
            self.mountFlipProgress.canCancel = NO;
            
            // wait for the mount to complete flipping
            [self checkMountFinishedFlip];
        }
    }
}

- (void)checkMountFinishedFlip
{
    if (self.mount.slewing){
        
        NSLog(@"Mount still slewing, waiting 5s...");
        [self performSelector:_cmd withObject:nil afterDelay:5]; // todo; need to be able to cancel this
    }
    else {
        
        CASPlateSolveSolution* solution = self.exposureView.lockedPlateSolveSolution;
        if (solution){
            
            NSLog(@"Mount slew complete, re-syncing to locked solution");
            
            self.mountFlipProgress.label.stringValue = NSLocalizedString(@"Syncing mount...", @"Progress sheet status label");
            
            // slew and solve to target
            self.mountWindowController.cameraController = self.cameraController;
            self.mountWindowController.mountWindowDelegate = self;
            self.mountWindowController.usePlateSolvng = YES;
            [self.mountWindowController.mountSynchroniser handleMountFlipCompletedWithRA:solution.centreRA dec:solution.centreDec];
        }
    }
}

#pragma mark - Mount Window Controller Delegate

- (void)mountWindowController:(CASMountWindowController*)windowController didCaptureExposure:(CASCCDExposure*)exposure
{
    [self setCurrentExposure:exposure resetDisplay:YES];
}

- (void)mountWindowController:(CASMountWindowController*)windowController didSolveExposure:(CASPlateSolveSolution*)solution
{
    self.exposureView.plateSolveSolution = solution;
}

- (void)mountWindowController:(CASMountWindowController*)windowController didCompleteWithError:(NSError*)error
{
    if (error){
        [self presentAlertWithTitle:@"Slew Failed" message:[error localizedDescription]];
        return;
    }
    
    if (!self.mountFlipProgress){
        [self presentAlertWithTitle:@"Slew Complete" message:@"The mount is now on the selected target"];
    }
    else{
        
        // looks like we were syncing after a flip
        void (^dismissSheet)() = ^(){
            [self.mountFlipProgress endSheetWithCode:NSOKButton];
            self.mountFlipProgress = nil;
        };
        
        if (error){
            dismissSheet();
        }
        else{
        
            self.mountFlipProgress.label.stringValue = NSLocalizedString(@"Restarting guiding...", @"Progress sheet status label");

            if (!self.cameraController.phd2Client.connected){
                // restart capture
                [self capture:nil];
            }
            else {
                
                // flip and restart guiding - no, only if we were guiding before the flip...
                [self.cameraController.phd2Client flipWithCompletion:^(BOOL success) {
                    
                    dismissSheet();
                    
                    if (!success){
                        [self presentAlertWithTitle:@"Guide Failed" message:@"PHD2 failed to restart guiding"];
                    }
                    else {
                        
                        // restart capture
                        [self capture:nil];
                    }
                }];
            }
        }
    }
}

#pragma mark - Focuser

- (IBAction)showFocuserWindow:(id)sender
{
    if (!self.focuserWindowController){
        self.focuserWindowController = [[SXIOFocuserWindowController alloc] initWithWindowNibName:@"SXIOFocuserWindowController"];
    }
    self.focuserWindowController.cameraController = self.cameraController;
    // delegate
    [self.focuserWindowController showWindow:nil];
}

#pragma mark - Plate Solving

- (NSURL*)plateSolutionURLForExposure:(CASCCDExposure*)exposure
{
    NSString* uuid = exposure.uuid;
    if (![uuid length]){
        uuid = [exposure.io.url lastPathComponent];
    }
    if (![uuid length]){
        return nil;
    }
    NSString* caches = [self.cachesDirectory stringByAppendingPathComponent:@"Plate Solutions"];
    [[NSFileManager defaultManager] createDirectoryAtPath:caches withIntermediateDirectories:YES attributes:nil error:nil];
    return [NSURL fileURLWithPath:[[caches stringByAppendingPathComponent:uuid] stringByAppendingPathExtension:@"caPlateSolution"]];
}

- (void)preparePlateSolveWithCompletion:(void(^)(NSError*))completion
{
    NSParameterAssert(completion);
    
    if (self.plateSolver){
        // todo; solvers should be per exposure
        NSLog(@"Already solving something");
        completion(NO);
        return;
    }
    
    CASCCDExposure* exposure = self.currentExposure;
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
        }
        else if (error.code == 2) {
            
            [self presentAlertWithTitle:@"astrometry.net not installed" message:@"Please install the command line tools from astrometry.net before running this command."];
        }
    }
}

- (void)plateSolveWithFieldSize:(CGSize)fieldSize arcsecsPerPixel:(float)arcsecsPerPixel
{
    CASCCDExposure* exposure = self.currentExposure;
    
    NSError* error;
    if (![self.plateSolver canSolveExposure:exposure error:&error]){
        [NSApp presentError:error];
    }
    else{
        
        // todo; should be per exposure rather than blocking the whole app
        // todo; show the spinner on the plate solution hud
        // todo; autosolve when show plate solution is on, lose the plate solve command
        CASProgressWindowController* progress = [CASProgressWindowController createWindowController];
        [progress beginSheetModalForWindow:self.window];
        progress.label.stringValue = NSLocalizedString(@"Solving...", @"Progress sheet status label");
        [progress.progressBar setIndeterminate:YES];
        
        // solve async - beware of races here since we're doing this async
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            
            self.plateSolver.fieldSizeDegrees = fieldSize;
            self.plateSolver.arcsecsPerPixel = arcsecsPerPixel;

            [self.plateSolver solveExposure:exposure completion:^(NSError *error, NSDictionary * results) {
                
                if (!error){
                    
                    // cache the plate solution - todo; do we want to share this in iCloud ?
                    NSURL* url = [self plateSolutionURLForExposure:exposure];
                    if (url){
                        NSData* solutionData = [NSKeyedArchiver archivedDataWithRootObject:results[@"solution"]];
                        if (!solutionData){
                            NSLog(@"Failed to archive solution data");
                        }
                        else{
                            if (![solutionData writeToURL:url options:NSDataWritingAtomic error:&error]){
                                NSLog(@"Failed to write solution data: %@",error);
                            }
                        }
                    }
                }

                dispatch_async(dispatch_get_main_queue(), ^{
                    
                    [progress endSheetWithCode:NSOKButton];
                    
                    if (error){
                        [NSApp presentError:error];
                    }
                    else {
                        self.showPlateSolution = YES;
                        self.exposureView.plateSolveSolution = results[@"solution"];
                        [self resetAndRedisplayCurrentExposure];
                    }
                    self.plateSolver = nil;
                });
            }];
        });
    }
}

- (IBAction)plateSolve:(id)sender
{
    [self preparePlateSolveWithCompletion:^(NSError* error) {
        if (!error){
            [self plateSolveWithFieldSize:CGSizeZero arcsecsPerPixel:0];
        }
        else {
            self.plateSolver = nil;
        }
    }];
}

- (IBAction)plateSolveWithOptions:(id)sender
{
    [self preparePlateSolveWithCompletion:^(NSError* error) {
        if (!error){
            self.plateSolveOptionsWindowController = [SXIOPlateSolveOptionsWindowController createWindowController];
            self.plateSolveOptionsWindowController.exposure = self.currentExposure;
            self.plateSolveOptionsWindowController.cameraController = self.cameraController;
            [self.plateSolveOptionsWindowController beginSheetModalForWindow:self.window completionHandler:^(NSInteger result) {
                if (result == NSOKButton) {
                    const CGSize fieldSize = self.plateSolveOptionsWindowController.enableFieldSize ? self.plateSolveOptionsWindowController.fieldSizeDegrees : CGSizeZero;
                    const float arcsecsPerPixel = self.plateSolveOptionsWindowController.enablePixelSize ? self.plateSolveOptionsWindowController.arcsecsPerPixel: 0;
                    [self plateSolveWithFieldSize:fieldSize arcsecsPerPixel:arcsecsPerPixel];
                }
                else {
                    self.plateSolver = nil;
                }
                self.plateSolveOptionsWindowController = nil;
            }];
        }
        else {
            self.plateSolver = nil;
        }
    }];
}

- (void)lockSolution:sender
{
    if (self.exposureView.lockedPlateSolveSolution){
        self.exposureView.lockedPlateSolveSolution = nil;
    }
    else {
        self.exposureView.lockedPlateSolveSolution = self.exposureView.plateSolveSolution;
    }
}

#pragma mark - Path & Save Utilities

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
    // look for a matching calibration frame
    NSString* filename = [self exposureSaveNameWithSuffix:suffix fileType:@"fits"];
    NSURL* fullURL = [_targetFolder URLByAppendingPathComponent:filename];
    CASCCDExposure* calibration = [[CASCCDExposure alloc] init];
    if (![[CASCCDExposureIO exposureIOWithPath:[fullURL path]] readExposure:calibration readPixels:YES error:nil]){
        return nil;
    }
    // check binning and dimenions match
    const CASSize exposureSize = exposure.actualSize;
    const CASSize calibrationSize = calibration.actualSize;
    if (exposureSize.width != calibrationSize.width || exposureSize.height != calibrationSize.height){
        return nil;
    }
    return calibration;
}

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

- (void)saveCIImage:(CIImage*)image toPath:(NSString*)path type:(NSString*)type properties:(NSDictionary*)properties
{
    NSParameterAssert(image);
    NSParameterAssert(path);
    
    const CGRect extent = image.extent;
    CGContextRef context = [CASCCDImage newRGBBitmapContextWithSize:CASSizeMake(extent.size.width, extent.size.height)];
    if (!context){
        NSLog(@"*** Failed to create save image context");
    }
    else {
        
        CIContext* ciContext = [CIContext contextWithCGContext:context options:nil];
        CGImageRef displayCGImage = [ciContext createCGImage:image fromRect:[image extent]];
        NSData* data = [CASCCDImage dataWithImage:displayCGImage forUTType:type options:properties];
        if (!data){
            NSLog(@"*** Failed to create image from exposure");
        }
        else {
            
            NSError* error;
            [data writeToFile:path options:NSDataWritingAtomic error:&error];
            if (error){
                dispatch_async(dispatch_get_main_queue(), ^{
                    [NSApp presentError:error];
                });
            }
        }
        CGContextRelease(context);
    }
}

#pragma mark - Exposure Display

- (void)updateWindowTitleWithExposurePath:(NSString*)path
{
    NSString* cameraName = self.cameraController.camera.deviceName;
    if (cameraName){
        
        if (path){
            self.window.title = [cameraName stringByAppendingFormat:@" [%@]",[[NSFileManager defaultManager] displayNameAtPath:path]];
            [self.window setRepresentedFilename:path];
        }
        else {
            self.window.title = cameraName;
            [self.window setRepresentedFilename:@""];
        }
        [self.window setFrameAutosaveName:cameraName];
    }
    else {
        self.window.title = @"";
    }
}

- (void)configureForCameraController
{
    [self updateWindowTitleWithExposurePath:nil];
    
    if (self.cameraController){
        
        // only set the cameraDeviceID when setting the controller, not when clearing it
        self.cameraDeviceID = self.cameraController.device.uniqueID;

        // use the sink interface to save the exposure if requested
        self.cameraController.sink = self;

        // set the current displayed exposure to the last one recorded by this camera controller
        // (specifically check for pixels as this will detect if the backing store has been deleted)
        if (self.cameraController.lastExposure.pixels){
            self.currentExposure = self.cameraController.lastExposure;
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
    
    // Subframes on the M26C aren't currently supported
    if (!self.cameraController.camera.canSubframe){
        [self.selectionControl setEnabled:NO forSegment:0];
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
            
        case CASCameraControllerStateWaitingForGuider:{
            commonShowProgressSetup(@"Waiting for PHD2...",NO);
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
                NSString* statusText;
                if (self.cameraController.settings.captureCount > 1 && !self.cameraController.settings.continuous){
                    statusText = [NSString stringWithFormat:@"Capturing %ld of %ld...",self.cameraController.settings.currentCaptureIndex+1,self.cameraController.settings.captureCount];
                }
                else {
                    statusText = @"Capturing...";
                }
                if (self.cameraController.settings.exposureUnits == 0){
                    const NSTimeInterval timeRemaining = self.cameraController.settings.exposureDuration - [[NSDate date] timeIntervalSinceDate:self.cameraController.exposureStart];
                    if (timeRemaining > 0){
                        statusText = [statusText stringByAppendingFormat:@" %.0fs",timeRemaining];
                    }
                }
                self.progressStatusText.stringValue = statusText;
            }
        }
            break;
            
        case CASCameraControllerStateDithering:{
            commonShowProgressSetup(@"Dithering...",NO);
            self.progressIndicator.indeterminate = YES;
        }
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
        
        // grab any solution data before we start reusing the exposure variable
        NSData* solutionData = nil;
        if (self.showPlateSolution){
            
            // first try the cache
            solutionData = [NSData dataWithContentsOfURL:[self plateSolutionURLForExposure:exposure]];
            if (!solutionData){
                
                // then look for a solution file alongside the exposure
                NSURL* exposureUrl = exposure.io.url;
                if (exposureUrl){
                    NSURL* solutionUrl = [[exposureUrl URLByDeletingPathExtension] URLByAppendingPathExtension:@"caPlateSolution"];
                    solutionData = [NSData dataWithContentsOfURL:solutionUrl];
                }
            }
        }
        
        // live calibrate using saved bias and flat frames
        if (self.calibrate){
            
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
            }
        }
        
        // debayer
        if (self.imageDebayer.mode != kCASImageDebayerNone){
            CASCCDExposure* debayeredExposure = [self.imageDebayer debayer:exposure adjustRed:1 green:1 blue:1 all:1];
            if (debayeredExposure){
                exposure = debayeredExposure;
            }
        }

        // equalise
        if (self.equalise){
            exposure = [self.imageProcessor equalise:exposure];
        }
        
        // set the exposure
        [self.exposureView setCurrentExposure:exposure resetDisplay:resetDisplay];
        
        // check for plate solution - do this after setting the exposure as that clears the annotations layer
        CASPlateSolveSolution* solution;
        if (self.showPlateSolution){
            if ([solutionData length]){
                @try {
                    solution = [NSKeyedUnarchiver unarchiveObjectWithData:solutionData];
                    if (![solution isKindOfClass:[CASPlateSolveSolution class]]){
                        NSLog(@"Root object in solution archive is a %@ and not a CASPlateSolveSolution",NSStringFromClass([solution class]));
                        solution = nil;
                    }
                }
                @catch (NSException *exception) {
                    NSLog(@"Exception opening solution data: %@",exception);
                }
            }
            if (!solution){
                // todo; start plate solve for this exposure, show solution hud but with a spinner
            }
        }
        self.exposureView.plateSolveSolution = solution;
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
        
        [self willChangeValueForKey:@"currentExposure"];
        
        @try {
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
        @catch (NSException *exception) {
            NSLog(@"*** Exception setting exposure: %@",exception);
        }
        
        [self didChangeValueForKey:@"currentExposure"];
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
            
            self.cameraController.settings.subframe = CGRectZero;
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
            self.cameraController.settings.subframe = subframe;
        }
    }
}

#pragma mark - CASCameraControllerSink

- (void)cameraController:(CASCameraController*)controller didCompleteExposure:(CASCCDExposure*)exposure error:(NSError*)error
{
    if (exposure){
        
        NSURL* finalUrl;
        
        // check we have somewhere to save the file, a prefix and a sequence number
        const BOOL saveToFile = (self.saveTargetControlsViewController.saveImages) && !self.cameraController.settings.continuous;
        if (saveToFile){
            
            // check for a user-entered filter name
            NSString* filterName = self.filterWheelControlsViewController.filterName;
            if ([filterName length]){
                exposure.filters = @[filterName];
            }
            
            // construct the filename
            const NSInteger sequence = self.saveTargetControlsViewController.saveImagesSequence;
            NSString* filename = [self exposureSaveNameWithSuffix:[NSString stringWithFormat:@"%03ld",sequence+1] fileType:nil];
            ++self.saveTargetControlsViewController.saveImagesSequence;
            
            // handle any placeholders
            filename = [exposure stringBySubstitutingPlaceholders:filename];
            
            // ensure we have a unique filename (for instance, in case the sequence was reset)
            NSInteger suffix = 2;
            finalUrl = [_targetFolder URLByAppendingPathComponent:filename];
            while ([[NSFileManager defaultManager] fileExistsAtPath:finalUrl.path]) {
                NSString* uniqueFilename = [[[filename stringByDeletingPathExtension] stringByAppendingFormat:@"_%ld",suffix++] stringByAppendingPathExtension:[filename pathExtension]];
                finalUrl = [_targetFolder URLByAppendingPathComponent:uniqueFilename];
                if (suffix > 999){
                    NSLog(@"*** Gave up trying to find a unique filename");
                    finalUrl = nil;
                    break;
                }
            }
        }
        
        // display the exposure
        const BOOL resetDisplay = !_capturedFirstImage || [self.exposureView shouldResetDisplayForExposure:exposure];
        [self setCurrentExposure:exposure resetDisplay:resetDisplay];
        _capturedFirstImage = YES;
        
        // save the file
        if (finalUrl){
            
            // todo; incorporate into CASCCDExposureIO ?
            if ([@"png" isEqualToString:[[finalUrl path] pathExtension]]){
                exposure.pngURL = finalUrl;
                [self saveCIImage:[self.exposureView filteredCIImage] toPath:[finalUrl path] type:(id)kUTTypePNG properties:nil];
            }
            else {
                
                NSNumber* latitude = [[NSUserDefaults standardUserDefaults] objectForKey:@"SXIOSiteLatitude"];
                NSNumber* longitude = [[NSUserDefaults standardUserDefaults] objectForKey:@"SXIOSiteLongitude"];
                if (latitude && longitude){
                    NSMutableDictionary* meta = [NSMutableDictionary dictionaryWithDictionary:exposure.meta];
                    meta[@"latitude"] = latitude;
                    meta[@"longitude"] = longitude;
                    exposure.meta = [meta copy];
                }
                
//                NSNumber* ra = self.mount.ra;
//                NSNumber* dec = self.mount.dec;
//                if (ra && dec){
//                    NSMutableDictionary* meta = [NSMutableDictionary dictionaryWithDictionary:exposure.meta];
//                    meta[@"ra"] = ra;
//                    meta[@"dec"] = dec;
//                    exposure.meta = [meta copy];
//                }

                [CASCCDExposureIO writeExposure:exposure toPath:[finalUrl path] error:&error];
            }
            
            [[NSDocumentController sharedDocumentController] noteNewRecentDocumentURL:finalUrl];
        }
        
        [self updateWindowTitleWithExposurePath:finalUrl.path];
    }
    
    if (error){
        dispatch_async(dispatch_get_main_queue(), ^{
            [NSApp presentError:error];
        });
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

- (BOOL)validateMenuItem:(NSMenuItem*)item
{
    BOOL enabled = YES;
    
    if (item.action == @selector(saveAs:) || item.action == @selector(saveToFITS:)){
        enabled = self.currentExposure != nil;
    }
    else if (item.action == @selector(openDocument:)) {
        enabled = !self.cameraController.capturing;
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
            
        case 10007:
            item.state = self.calibrate;
            break;

        case 10008:
            item.state = self.showPlateSolution;
            break;

        case 10010:
            item.state = self.exposureView.scaleSubframe;
            break;
                        
        case 10012:
            enabled = (self.currentExposure != nil && !self.cameraController.capturing);
            break;
            
        case 10013:
            item.state = self.exposureView.flipVertical;
            break;

        case 10014:
            item.state = self.exposureView.flipHorizontal;
            break;

        case 10020:
        case 10021:
        case 10022:
        case 10023:
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
        case 11102:
            break;
            
        case 11103: // Lock Solution
            if (self.exposureView.lockedPlateSolveSolution){
                item.title = @"Unlock Solution"; // add locked solution exposure name ?
            }
            else {
                item.title = @"Lock Solution";
                enabled = (self.exposureView.plateSolveSolution != nil);
            }
            break;
            
        case 11104: // Plate Solve...
            enabled = (self.plateSolver == nil && self.currentExposure != nil);
            break;
            
        case 11105: // Sequence...
            enabled = !self.cameraController.capturing;
            break;
            
        case 11106: // Connect to Mount...
            enabled = YES;
            break;
            
        case 11107: // Show Focuser...
            enabled = self.cameraController.settings && !self.cameraController.capturing && !CGRectEqualToRect(self.cameraController.settings.subframe, CGRectZero);
            break;
    }
    return enabled;
}

#pragma mark - Sequence Target

- (CASCameraController*) sequenceCameraController
{
    return self.cameraController;
}

- (CASFilterWheelController*) sequenceFilterWheelController
{
    return self.filterWheelControlsViewController.currentFilterWheel;
}

- (BOOL)prepareToStartSequenceWithError:(NSError**)error
{
    // todo; need a more generic mechanism to express 'ready to capture'
    if (self.filterWheelControlsViewController.currentFilterWheel.filterWheel.moving){
        if (error){
            *error = [NSError errorWithDomain:NSStringFromClass([self class])
                                         code:1
                                     userInfo:@{NSLocalizedDescriptionKey:@"The selected filter wheel is currently moving. Please wait until it's stopped before trying again"}];
        }
        return NO;
    }
    
    if (self.saveTargetControlsViewController.saveImages && !_targetFolder){
        if (error){
            *error = [NSError errorWithDomain:NSStringFromClass([self class])
                                         code:1
                                     userInfo:@{NSLocalizedDescriptionKey:@"You need to specify a folder to save the images into"}];
        }
        return NO;
    }
    
    return YES;
}

- (void)captureWithCompletion:(void(^)(NSError*))completion
{
    // disable idle sleep
    [CASPowerMonitor sharedInstance].disableSleep = YES;
    
    // ensure this is recorded as a light frame
    self.cameraController.settings.exposureType = kCASCCDExposureLightType;
    
    // issue the capture command
    [self.cameraController captureWithBlock:^(NSError *error,CASCCDExposure* exposure) {
        
        if (!self.cameraController.capturing){
            
            // might be flipping in which case this will be called again but with a nil completion block which
            // means the sequence controller will never hear about the completed exposures and be stuck
            
            // re-enable idle sleep
            [CASPowerMonitor sharedInstance].disableSleep = NO;
            
            if (!self.cameraController.cancelled){
                
                NSUserNotification* note = [[NSUserNotification alloc] init];
                note.title = NSLocalizedString(@"Capture Complete", @"Notification title");
                NSString* exposureUnits = (self.cameraController.settings.exposureUnits == 0) ? @"s" : @"ms";
                if (self.cameraController.settings.captureCount == 1){
                    note.subtitle = [NSString stringWithFormat:@"%ld exposure of %ld%@",(long)self.cameraController.settings.captureCount,self.cameraController.settings.exposureDuration,exposureUnits];
                }
                else {
                    note.subtitle = [NSString stringWithFormat:@"%ld exposures of %ld%@",(long)self.cameraController.settings.captureCount,self.cameraController.settings.exposureDuration,exposureUnits];
                }
                note.soundName = NSUserNotificationDefaultSoundName;
                [[NSUserNotificationCenter defaultUserNotificationCenter] deliverNotification:note];
            }
            
            [self endSequence];
            
            if (completion){
                completion(error);
            }
        }
    }];
}

- (void)endSequence
{
    [self cancelCapture:nil];
}

#pragma mark - Notifications

- (void)mountFlipped:(NSNotification*)note
{
    if (note.object == self.mount){
        if ([[NSUserDefaults standardUserDefaults] boolForKey:@"SXIOResyncAfterMeridianFlip"]){
            NSLog(@"Detected mount flip");
            [self mountFlipped];
        }
        else {
            NSLog(@"Ignoring mount flip");
        }
    }
}

@end

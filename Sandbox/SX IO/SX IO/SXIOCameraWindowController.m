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
#import "SXIOMountControlsViewController.h"
#import "CASFilterWheelControlsViewController.h"
#import "CASProgressWindowController.h"
#import "CASShadowView.h"
#import "CASCaptureWindowController.h"
#import "SXIOPlateSolveOptionsWindowController.h"
#import "SXIOSequenceEditorWindowController.h"
#import "CASMountWindowController.h"
#import "SXIOFocuserWindowController.h"
#import "SXIOBookmarkWindowController.h"
#import "SXIOPlateSolutionLookup.h"

#if defined(SXIO)
#import "SX_IO-Swift.h"
#else
#import "CCD_IO-Swift.h"
#endif
#import <CoreAstro/CoreAstro.h>

#import <Quartz/Quartz.h>
#import <CoreLocation/CoreLocation.h>

static NSString* const kSXIOCameraWindowControllerDisplayedSleepWarningKey = @"SXIOCameraWindowControllerDisplayedSleepWarning";

@interface CASToolbarItem : NSToolbarItem
@end
@implementation CASToolbarItem
- (NSSize)minSize
{
    return NSMakeSize(69, 25);
}
- (NSSize)maxSize
{
    return [self minSize];
}
@end

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

@interface SXIOMountState : NSObject
@property BOOL slewStarted;
@property BOOL capturingWhenSlewStarted;
@property CASMountPierSide pierSideWhenSlewStarted;
@property BOOL guidingWhenSlewStarted;
@property BOOL synchronisingWhenSlewStarted;
@property BOOL restoreStateWhenComplete;
@end

@implementation SXIOMountState

- (NSString*)description
{
    return [NSString stringWithFormat:@"slewStarted: %d, capturingWhenSlewStarted: %d, pierSideWhenSlewStarted: %ld, guidingWhenSlewStarted: %d",self.slewStarted,self.capturingWhenSlewStarted,(long)self.pierSideWhenSlewStarted,self.guidingWhenSlewStarted];
}

@end

@interface SXIOCameraWindowController ()<CASExposureViewDelegate,CASCameraControllerSink>

@property (weak) IBOutlet NSToolbar *toolbar;
@property (weak) IBOutlet NSScrollView *containerScrollView;
@property (weak) IBOutlet NSTextField *progressStatusText;
@property (weak) IBOutlet NSProgressIndicator *progressIndicator;
@property (weak) IBOutlet NSButton *captureButton;
@property (strong) IBOutlet NSSegmentedControl *zoomControl;
@property (strong) IBOutlet NSSegmentedControl *zoomFitControl;
@property (strong) IBOutlet NSSegmentedControl *selectionControl;
@property (strong) IBOutlet NSSegmentedControl *navigationControl;

@property (nonatomic,strong) CASCCDExposure *currentExposure;
@property (strong) CASCCDExposure *calibratedExposure;
@property (strong) CASCCDExposure* latestExposure;
@property (copy) NSString* currentExposureUUID;

@property (copy) void(^captureCompletion)(NSError*);

@property (strong) SXIOSaveTargetViewController *saveTargetControlsViewController;
@property (strong) SXIOMountControlsViewController *mountControlsViewController;
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

@property (copy) NSString* cameraDeviceID;

// mount control
@property (strong) SXIOMountState* mountState;
@property (strong,nonatomic) CASMountController* mountController;
@property (strong) CASProgressWindowController* mountSlewProgressSheet;

// focusing
@property (strong) SXIOFocuserWindowController* focuserWindowController;

// obsolete but required until the xib format is updated
@property (weak) IBOutlet id mountConnectWindow;
@property id serialPortManager, selectedSerialPort;

@property BOOL isRunningSequence; // used to track if we're running a sequence as part of mount slew handling

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
    
    // mount controls view
    self.mountControlsViewController = [[SXIOMountControlsViewController alloc] initWithNibName:@"SXIOMountControlsViewController" bundle:nil];
    self.mountControlsViewController.view.translatesAutoresizingMaskIntoConstraints = NO;
    self.mountControlsViewController.mountControllerHost = (id<SXIOMountControllerHost>)self;
    [container addSubview:self.mountControlsViewController.view];

    // layout mount controls
    id mountControlsViewController1 = self.mountControlsViewController.view;
    viewNames = NSDictionaryOfVariableBindings(filterWheelControlsViewController1,mountControlsViewController1);
    [container addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|[mountControlsViewController1]|" options:0 metrics:nil views:viewNames]];
    [container addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:[filterWheelControlsViewController1][mountControlsViewController1(==height)]" options:NSLayoutFormatAlignAllCenterX metrics:@{@"height":@(self.saveTargetControlsViewController.view.frame.size.height)} views:viewNames]];

    // layout save target controls
    id saveTargetControlsViewController1 = self.saveTargetControlsViewController.view;
    viewNames = NSDictionaryOfVariableBindings(mountControlsViewController1,saveTargetControlsViewController1);
    [container addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|[saveTargetControlsViewController1]|" options:0 metrics:nil views:viewNames]];
    [container addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:[mountControlsViewController1][saveTargetControlsViewController1(==height)]" options:NSLayoutFormatAlignAllCenterX metrics:@{@"height":@(self.saveTargetControlsViewController.view.frame.size.height)} views:viewNames]];
    
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
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(mountSlewingStateChanged:) name:CASMountSlewingNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(mountCapturedSyncExposure:) name:kCASMountControllerCapturedSyncExposureNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(mountSolvedSyncExposure:) name:kCASMountControllerSolvedSyncExposureNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(mountCompletedSync:) name:kCASMountControllerCompletedSyncNotification object:nil];

    // listen for mount removed notifications
    [[CASDeviceManager sharedManager] addObserver:self forKeyPath:@"mountControllers" options:NSKeyValueObservingOptionNew|NSKeyValueObservingOptionOld|NSKeyValueObservingOptionInitial context:&kvoContext];

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
    self.mountController = nil; // unobserve status
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [[CASDeviceManager sharedManager] removeObserver:self forKeyPath:@"mountControllers" context:&kvoContext];
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
        
        if (object == self.mountController){
            if ([keyPath isEqualToString:@"status"]){
                NSString* status = self.mountController.status;
                if (status){
                    self.mountSlewProgressSheet.label.stringValue = status;
                }
            }
        }
        
        if (object == [CASDeviceManager sharedManager]) {
            if ([change[NSKeyValueChangeKindKey] integerValue] == NSKeyValueChangeRemoval) {
                NSArray* mountControllers = change[NSKeyValueChangeOldKey];
                if ([mountControllers isKindOfClass:[NSArray class]]) {
                    [mountControllers enumerateObjectsUsingBlock:^(CASMountController* mountController, NSUInteger idx, BOOL * _Nonnull stop) {
                        if (mountController == self.mountController) {
                            self.mountController = nil;
                            // dismiss slew progress, etc ?
                        }
                    }];
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

- (void)setMountController:(CASMountController *)mountController
{
    if (mountController != _mountController){
        [_mountController removeObserver:self forKeyPath:@"status" context:&kvoContext];
        _mountController = mountController;
        [_mountController addObserver:self forKeyPath:@"status" options:0 context:&kvoContext];
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

- (BOOL)checkReadyToCapture:(NSError**)error
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
                                         code:2
                                     userInfo:@{NSLocalizedDescriptionKey:@"You need to specify a folder to save the images into"}];
        }
        return NO;
    }
    
    return YES;
}

- (IBAction)capture:(NSButton*)sender
{
    // todo; need a more generic mechanism to express 'ready to capture'
    NSError* error;
    if (![self checkReadyToCapture:&error]){
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

    // save the completion block
    self.captureCompletion = ^(NSError* error) {
        if (error){
            [NSApp presentError:error];
        }
    };
    
    // reset the capture index
    [self.cameraController resetCapture];
    
    // kick off the capture
    [self startCapture];
}

- (IBAction)cancelCapture:(id)sender
{
    self.captureButton.enabled = NO; // the button is in Cancel mode, so disable it until the camera state is updated
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

- (IBAction)navigate:(NSSegmentedControl*)sender
{
    if (sender.selectedSegment == 1){
        [self nextExposure:nil];
    }
    else {
        [self previousExposure:nil];
    }
}

- (IBAction)nextExposure:(id)sender
{
    // Xcode 7
//    NSArray<NSURL*>* exposures = self.cameraController.recentURLs;
    NSArray* exposures = self.cameraController.recentURLs;
    if (exposures.count > 0){
        const NSInteger index = [exposures indexOfObject:self.currentExposure.io.url];
        NSLog(@"nextExposure index: %ld, count: %ld",index,exposures.count);
        if (index != NSNotFound){
            if (index > 0){
                [self openExposureAtPath:((NSURL*)exposures[index-1]).path];
            }
            else {
                if (self.latestExposure){
                    self.currentExposure = self.latestExposure;
                }
            }
        }
    }
}

- (IBAction)previousExposure:(id)sender
{
    // Xcode 7
//    NSArray<NSURL*>* exposures = self.cameraController.recentURLs;
    NSArray* exposures = self.cameraController.recentURLs;
    if (exposures.count > 0){
        if (!self.currentExposure.io.url){
            [self openExposureAtPath:((NSURL*)exposures.firstObject).path];
        }
        else {
            const NSInteger index = [exposures indexOfObject:self.currentExposure.io.url];
            NSLog(@"previousExposure index: %ld, count: %ld",index,exposures.count);
            if (index != NSNotFound && index < exposures.count - 1){
                [self openExposureAtPath:((NSURL*)exposures[index+1]).path];
            }
        }
    }
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
    CASCCDExposure* exposure = [CASCCDExposureIO exposureWithPath:path readPixels:NO error:nil];
    if (exposure){
        self.currentExposure = exposure;
        [self.cameraController updateSettingsWithExposure:exposure];
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
        
        // ensure we have a unique filename
        NSURL* finalUrl;
        while (true) {
            
            // construct the exposure name
            NSString* prefix = self.saveTargetControlsViewController.saveImagesPrefix;
            if ([prefix rangeOfString:@"$type"].location == NSNotFound){
                prefix = [prefix stringByAppendingString:@"_$type"];
            }
            if (sequence > 0){
                prefix = [NSString stringWithFormat:@"%@_%03ld",prefix,sequence];
            }
            finalUrl = [[_targetFolder URLByAppendingPathComponent:[exposure stringBySubstitutingPlaceholders:prefix]] URLByAppendingPathExtension:@"fits"];
            
            if (![[NSFileManager defaultManager] fileExistsAtPath:finalUrl.path]){
                break;
            }
            
            sequence += 1;
        }
        
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
                    
                    // restore sleep setting
                    [CASPowerMonitor sharedInstance].disableSleep = NO;

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
    [self.cameraController.camera setDefaultsObject:@(self.exposureView.showHistogram) forKey:@"SXIODisplayShowHistogram"];
}

- (IBAction)toggleShowReticle:(id)sender
{
    self.exposureView.showReticle = !self.exposureView.showReticle;
    [self.cameraController.camera setDefaultsObject:@(self.exposureView.showReticle) forKey:@"SXIODisplayShowReticle"];
}

- (IBAction)toggleShowStarProfile:(id)sender
{
    self.exposureView.showStarProfile = !self.exposureView.showStarProfile;
    [self.cameraController.camera setDefaultsObject:@(self.exposureView.showStarProfile) forKey:@"SXIODisplayShowStarProfile"];
}

- (IBAction)toggleShowImageStats:(id)sender
{
    self.exposureView.showImageStats = !self.exposureView.showImageStats;
    [self.cameraController.camera setDefaultsObject:@(self.exposureView.showImageStats) forKey:@"SXIODisplayShowImageStats"];
}

- (IBAction)toggleInvertImage:(id)sender
{
    self.exposureView.invert = !self.exposureView.invert;
    [self.cameraController.camera setDefaultsObject:@(self.exposureView.invert) forKey:@"SXIODisplayInvert"];
}

- (IBAction)toggleMedianFilter:(id)sender
{
    self.exposureView.medianFilter = !self.exposureView.medianFilter;
    [self.cameraController.camera setDefaultsObject:@(self.exposureView.medianFilter) forKey:@"SXIODisplayMedian"];
}

- (IBAction)toggleEqualiseHistogram:(id)sender
{
    self.equalise = !self.equalise;
    [self resetAndRedisplayCurrentExposure];
    [self.cameraController.camera setDefaultsObject:@(self.equalise) forKey:@"SXIODisplayEqualise"];
}

- (IBAction)toggleContrastStretch:(id)sender
{
    self.exposureView.contrastStretch = !self.exposureView.contrastStretch;
    [self.cameraController.camera setDefaultsObject:@(self.exposureView.contrastStretch) forKey:@"SXIODisplayContrastStretch"];
}

- (IBAction)toggleCalibrate:(id)sender
{
    /*
    self.calibrate = !self.calibrate;
    [self resetAndRedisplayCurrentExposure];
    [self.cameraController.camera setDefaultsObject:@(self.equalise) forKey:@"SXIODisplayCalibrate"];
    */
    NSLog(@"toggleCalibrate: not implemented");
}

- (IBAction)toggleShowPlateSolution:(id)sender
{
    self.showPlateSolution = !self.showPlateSolution;
    if (!self.showPlateSolution){
        [[CASPlateSolveSolutionRegistery sharedRegistry] setSolution:nil forKey:self.cameraDeviceID];
    }
    [self resetAndRedisplayCurrentExposure];
    [self.cameraController.camera setDefaultsObject:@(self.showPlateSolution) forKey:@"SXIODisplayShowPlateSolution"];
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
    [self.cameraController.camera setDefaultsObject:@(self.imageDebayer.mode) forKey:@"SXIODisplayDebayerMode"];
}

- (IBAction)toggleFlipVertical:(id)sender
{
    self.exposureView.flipVertical = !self.exposureView.flipVertical;
    [self.cameraController.camera setDefaultsObject:@(self.exposureView.flipVertical) forKey:@"SXIODisplayFlipVertical"];
}

- (IBAction)toggleFlipHorizontal:(id)sender
{
    self.exposureView.flipHorizontal = !self.exposureView.flipHorizontal;
    [self.cameraController.camera setDefaultsObject:@(self.exposureView.flipVertical) forKey:@"SXIODisplayFlipHorizontal"];
}

- (IBAction)sequence:(id)sender
{
    self.sequenceEditorWindowController = [SXIOSequenceEditorWindowController sharedWindowController];
    if (self.sequenceEditorWindowController.target == nil) {
        self.sequenceEditorWindowController.target = self;
    }
    [self.sequenceEditorWindowController showWindow:nil];
}

#pragma mark - Mount Control

// obsolete but required until the xib format is updated
- (IBAction)connectButtonPressed:(id)sender {}

- (IBAction)connectToMount:(id)sender
{
    // keep things simple and have a single mount window across the app for now
    CASMountWindowController* mountWindowController = [CASMountWindowController sharedMountWindowController];
    
    
    // if the singleton mount window controller already has a connected mount just show the window, the user will have
    // to disconnect from the current mount before connecting to a new one
    if (mountWindowController.mountController.mount.connected) {
        [mountWindowController showWindow:nil];
        return;
    }
    
    // as the mount window to show the connect UI
    [mountWindowController connectToMount:^{
        
        self.mountController = mountWindowController.mountController; // only set this once it's connected as it observes the mount controller status

        mountWindowController.cameraController = self.cameraController; // set the mount and mount controller's camera to this camera conroller
        
        // if there's a current plate solution, set that as the current target - necessary? doesn't it appear in the popup now ?
        CASPlateSolveSolution* solution = self.exposureView.plateSolveSolution;
        if (solution){
            [self.mountController setTargetRA:solution.centreRA dec:solution.centreDec completion:^(NSError* error) {
                if (error){
                    [NSApp presentError:error];
                }
            }];
        }
    }];
}

// Slew to the mount's current position in order to trigger a meridian flip
//
// Called when a capture has completed and the mount has crossed the meridian and needs flipping
//
- (void)startMountMeridianFlip
{
    // grab the current locked solution or, if there is none, the current mount position
    NSNumber* ra, *dec;
    CASPlateSolveSolution* lockedSolution = self.exposureView.lockedPlateSolveSolution;
    if (lockedSolution){
        ra = @(lockedSolution.centreRA);
        dec = @(lockedSolution.centreDec);
    }
    else {
        id<CASMount> mount = self.mountController.mount;
        ra = mount.ra;
        dec = mount.dec;
    }
    
    if (!ra || !dec){
        [self presentAlertWithTitle:@"Failed to Slew Mount"
                            message:@"There is no current locked solution and the mount position is not available so the mount cannot be flipped"];
    }
    else {
        
        // todo; put in an 'at least' param for ap mounts
        // todo; 30s beeping countdown alert ?
        // todo; capture mount co-ordinates here and avoid the need for a locked solution ? e.g. slewToMountCurrentPosition
        
        [[CASLocalNotifier sharedInstance] postLocalNotification:@"Flipping mount"
                                                        subtitle:@"Mount has passed meridian while capturing, triggering flip"];
        
        // captures current mount state, suspends capture and stops guiding
        [self prepareForMountSlewHandling];
        
        // set the restore on complete flag; this is the *only* place we do this (this is cleared in -completeMountSlewHandling which nils out the state object)
        self.mountState.restoreStateWhenComplete = YES;
        
        // pop the slew sheet so that we can set the label text to something specific
        [self presentMountSlewSheetWithLabel:NSLocalizedString(@"Flipping mount...", @"Progress sheet status label")];

        self.mountController.cameraController = self.cameraController;
        self.mountController.usePlateSolving = YES;
        
        __weak __typeof(self) weakSelf = self;
        [self.mountController setTargetRA:ra.doubleValue dec:dec.doubleValue completion:^(NSError* error) {
            if (error){
                [weakSelf completeMountSlewHandling]; // clear the saved mount state, dismisses the progress sheet
                [NSApp presentError:error];
            }
            else {
                [weakSelf.mountController slewToTargetWithCompletion:^(NSError* _) {
                    // actual completion handling done in -mountCompletedSync:
                }];
            }
        }];
    }
}

// Restart guiding and/or capturing.
//
// Called when the mount has successfully re-synced after a triggered meridian flip
//
- (void)restoreStateAfterMountSlewCompleted // only called after the synchroniser has completed successfully
{
    const BOOL flipped = (self.mountState.pierSideWhenSlewStarted != self.mountController.mount.pierSide);
    
    void (^failWithAlert)(NSString*,NSString*) = ^(NSString* title,NSString* message){
        [self completeMountSlewHandling];
        [self presentAlertWithTitle:title message:message];
        [[CASLocalNotifier sharedInstance] postLocalNotification:@"Resuming capture failed" subtitle:message];
    };

    // final block to be called, dismiss the progress sheet and restart capturing
    void (^restartCapturing)() = ^(){
        if (self.mountState.capturingWhenSlewStarted){
            [[CASLocalNotifier sharedInstance] postLocalNotification:@"Resuming capture" subtitle:nil];
            [self startCapture]; // does this reset the camera controller's capture count ? - this probably resets the capture index so it'll start again
        }
        [self completeMountSlewHandling]; // call after checking the capturingWhenSlewStarted flag as this clears the mount state object
    };

    // restart guiding, then capturing
    void (^restartGuiding)() = ^(){
        [[CASLocalNotifier sharedInstance] postLocalNotification:@"Resuming guiding" subtitle:nil];
        [self.cameraController.phd2Client guideWithCompletion:^(BOOL success) {
            if (!success){
                failWithAlert(@"Guide Failed",@"Failed to restart guiding");
            }
            else {
                restartCapturing();
            }
        }];
    };
    
    // restart guiding, optionally flipping the calibration first then restart capturing
    void (^restartGuidingWithFlipped)(BOOL) = ^(BOOL flipped){
        if (!flipped){
            restartGuiding();
        }
        else {
            switch ([[NSUserDefaults standardUserDefaults] integerForKey:@"SXIOMeridianPHD2Behaviour"]) {
                case 0:
                    NSLog(@"No PHD2 meridian behaviour selected");
                    break;
                case 1:
                {
                    [[CASLocalNotifier sharedInstance] postLocalNotification:@"Flipping guide calibration" subtitle:nil];
                    [self.cameraController.phd2Client flipWithCompletion:^(BOOL success) {
                        if (!success){
                            failWithAlert(@"Guide Failed",@"Failed to flip guide calibration");
                        }
                        else {
                            restartGuiding();
                        }
                    }];
                }
                    break;
                case 2:
                {
                    [[CASLocalNotifier sharedInstance] postLocalNotification:@"Clearing guide calibration" subtitle:nil];
                    [self.cameraController.phd2Client clearWithCompletion:^(BOOL success) {
                        if (!success){
                            failWithAlert(@"Guide Failed",@"Failed to clear guide calibration");
                        }
                        else {
                            restartGuiding();
                        }
                    }];
                }
                    break;
                default:
                    break;
            }
        }
    };
    
    if (!self.mountState.guidingWhenSlewStarted){
        
        // we weren't guiding before the slew so just restart capture
        restartCapturing();
    }
    else {
        
        self.mountSlewProgressSheet.label.stringValue = NSLocalizedString(@"Restarting guiding...", @"Progress sheet status label");
        
        // ensure we're connected to PHD2
        NSLog(@"Connecting to PHD2");
        [self.cameraController.phd2Client disconnect];
        [self.cameraController.phd2Client connectWithCompletion:^{
            
            if (!self.cameraController.phd2Client.connected){
                failWithAlert(@"Guide Failed",@"Failed to reconnect to PHD2");
            }
            else {
                [[CASLocalNotifier sharedInstance] postLocalNotification:@"Connected to PHD2" subtitle:nil];
                restartGuidingWithFlipped(flipped);
            }
        }];
    }
}

- (void)prepareForMountSlewHandling
{
    // grab the current state but only if we haven't already done so
    if (!self.mountState){
        self.mountState = [SXIOMountState new];
        self.mountState.capturingWhenSlewStarted = self.cameraController.capturing;
        self.mountState.pierSideWhenSlewStarted = self.mountController.mount.pierSide;
        self.mountState.guidingWhenSlewStarted = self.cameraController.phd2Client.guiding;
    }
    
    // stop capture if we're not looping (which probably means we're framing the subject)
    if (!self.cameraController.settings.continuous){
        [self.cameraController suspendCapture];
    }
    
    // stop guiding and disconnect, we'll reconnect when the slew completes
    [self stopGuiding];
}

- (void)completeMountSlewHandling
{
    // clear the mount state
    self.mountState = nil;
    
    // get rid of the slew sheet
    if (self.mountSlewProgressSheet){
        [self.mountSlewProgressSheet endSheetWithCode:NSOKButton];
        self.mountSlewProgressSheet = nil;
    }
}

- (void)presentMountSlewSheetWithLabel:(NSString*)label
{
    if (!self.mountSlewProgressSheet){
        self.mountSlewProgressSheet = [CASProgressWindowController createWindowController];
        [self.mountSlewProgressSheet beginSheetModalForWindow:self.window];
        [self.mountSlewProgressSheet.progressBar setIndeterminate:YES];
        self.mountSlewProgressSheet.canCancel = NO;
    }
    self.mountSlewProgressSheet.label.stringValue = label;
}

// Handle the mount starting or ending slew, either triggered by us or externally
//
// Called from the mount slew state changed notification handler. There are a number of possible states
//
// 1. External slew e.g. slew buttons on mount window or handset. We cancel capture and guiding and wait for the mount to stop, no state is restored
//
// 2. User typed an object into the mount search field and hit slew and plate solve is OFF. Same behaviour as (1)
//
// 3. User typed an object into the mount search field and hit slew and plate solve is ON. Cancel capture and guiding, no state is restored.
//
// 4. Mount was flipped by us after crossing the meridian and will resync on the other side, plate solve is ON. Cancel capture and guiding, attempt to restore state when the mount controller finishes.
//
// 5. Mount is iterating towards its target and this is an intermediate slew, plate solve is ON. Cancel capture and guiding, wait until the sync completes and then restore state if appropriate.
//
- (void)handleMountSlewStateChanged
{
    if (!self.mountController){
        NSLog(@"Mount slew state changed but no connected mount controller");
        return;
    }
    
    if (self.mountController.mount.slewing){
        
        if (!self.mountState.slewStarted){
            
            // ensure capture and guiding are suspended and that we record the current state (if it wasn't already done when we triggered the slew)
            [self prepareForMountSlewHandling];
            
            NSLog(@"Slew started: %@",self.mountState);

            self.mountState.slewStarted = YES;

            // check to see if this is a slew triggered by the mount synchroniser which will happen after we've slewed and need to resync to the locked solution
            self.mountState.synchronisingWhenSlewStarted = self.mountController.synchronising;
            if (self.mountState.synchronisingWhenSlewStarted){
                
                NSLog(@"Mount slew started but being handled by mount synchroniser so not capturing state");
                
                if (self.mountState.capturingWhenSlewStarted){
                    [self presentMountSlewSheetWithLabel:NSLocalizedString(@"Synchronising mount...", @"Progress sheet status label")];
                }
            }
            else {
                
                NSLog(@"Mount slew started but being triggered externally so just cancel capture and guiding");

                [[CASLocalNotifier sharedInstance] postLocalNotification:@"Mount slew started" subtitle:@"External slew, cancelling capture and guiding"];
                
                if (self.mountState.capturingWhenSlewStarted){
                    [self presentMountSlewSheetWithLabel:NSLocalizedString(@"Waiting for mount to stop...", @"Progress sheet status label")];
                }
            }
        }
    }
    else {
        
        if (self.mountState.slewStarted){
            
            NSLog(@"Slew ended: %@",self.mountState);

            self.mountState.slewStarted = NO;

            // this was a slew triggered by the mount synchroniser so we wait until -mountCompletedSync: is called
            // (this may be called multiple times as the mount interates towards the target)
            if (self.mountState.synchronisingWhenSlewStarted){
                
                NSLog(@"Mount slew ended but it's being handled by the mount synchroniser so waiting until -mountCompletedSync: is called");
            }
            else {
                
                NSLog(@"Mount slew ended but we didn't start it so cleanup and complete");

                [[CASLocalNotifier sharedInstance] postLocalNotification:@"Mount slew ended" subtitle:@"Externally triggered slew completed, capture and guiding not restarted"];
                
                [self completeMountSlewHandling];
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
            
            [self presentAlertWithTitle:@"astrometry.net not installed" message:@"Please install the command line tools from astrometry.net before running this command."]; // link to blog page ?
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
        
        progress.canCancel = YES;
        progress.cancelBlock = ^{
            [self.plateSolver cancel];
        };
        
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
                        if (error){
                            [NSApp presentError:error];
                        }
                        else {
                            self.showPlateSolution = YES;
                            self.exposureView.plateSolveSolution = results[@"solution"];
                            [[CASPlateSolveSolutionRegistery sharedRegistry] setSolution:self.exposureView.plateSolveSolution forKey:self.cameraDeviceID];
                            // no longer resetting display as that then immediately nils out the solution
                        }
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

- (IBAction)lockSolution:sender
{
    if (self.exposureView.lockedPlateSolveSolution){
        self.exposureView.lockedPlateSolveSolution = nil;
        [[CASPlateSolveSolutionRegistery sharedRegistry] setSolution:self.exposureView.plateSolveSolution forKey:self.cameraDeviceID];
    }
    else {
        self.exposureView.lockedPlateSolveSolution = self.exposureView.plateSolveSolution;
        [[CASPlateSolveSolutionRegistery sharedRegistry] setSolution:self.exposureView.lockedPlateSolveSolution forKey:self.cameraDeviceID];
    }
}

#pragma mark - Bookmarks

- (void)openBookmarksWithSolution:(CASPlateSolveSolution*)solution
{
    [[SXIOBookmarkWindowController sharedController] showWindow:nil];
    
    if (solution){
        [[SXIOBookmarkWindowController sharedController] addSolutionBookmark:solution];
    }
}

- (IBAction)addBookmark:sender
{
    [self openBookmarksWithSolution:self.exposureView.plateSolveSolution];
}

- (IBAction)editBookmarks:sender
{
    [self openBookmarksWithSolution:nil];
}

#pragma mark - Path & Save Utilities

- (NSString*)currentDeviceExposurePathWithName:(NSString*)name
{
    NSString* path = [_targetFolder path];
    return (name && path) ? [[path stringByAppendingPathComponent:name] stringByAppendingPathExtension:[[NSUserDefaults standardUserDefaults] stringForKey:@"SXIODefaultExposureFileType"]] : nil;
}

/*
- (CASCCDExposure*)calibrationExposureOfType:(NSString*)suffix matchingExposure:(CASCCDExposure*)exposure
{
    if (!suffix || !_targetFolder){
        return nil;
    }
    
    // look for a matching calibration frame
    NSString* filename = [self exposureSaveNameWithSuffix:suffix fileType:@"fits"];
    NSURL* fullURL = [_targetFolder URLByAppendingPathComponent:filename];
    __block CASCCDExposure* calibration = [[CASCCDExposure alloc] init];
    if (![[CASCCDExposureIO exposureIOWithPath:[fullURL path]] readExposure:calibration readPixels:YES error:nil]){

        // reset
        calibration = nil;
        
        // look for files with the correct fits header
        CASCCDExposureType type = kCASCCDExposureUnknownType;
        if ([suffix isEqualToString:@"dark"]){
            type = kCASCCDExposureDarkType;
        }
        else if ([suffix isEqualToString:@"bias"]){
            type = kCASCCDExposureBiasType;
        }
        else if ([suffix isEqualToString:@"flat"]){
            type = kCASCCDExposureFlatType;
        }
        if (type != kCASCCDExposureUnknownType){
            [CASCCDExposureIO enumerateExposuresWithURL:_targetFolder block:^(CASCCDExposure* exposure,BOOL* stop){
                if (type == exposure.type){
                    calibration = exposure;
                    *stop = YES;
                }
            }];
        }
    }
    
    if (calibration){
        
        // check binning and dimensions match
        if (!CASSizeEqualToSize(exposure.params.size,calibration.params.size) || !CASSizeEqualToSize(calibration.params.bin,exposure.params.bin)){
            calibration = nil;
        }
        else if (exposure.isSubframe){
            
            // grab the matching subframe
            calibration = [calibration subframeWithRect:exposure.subframe];
            if (calibration){
                
                const CASRect exposureSubframe = exposure.subframe;
                const CASRect calibrationSubframe = calibration.subframe;
                if (CASRectEqualToRect(exposureSubframe, calibrationSubframe)){
                    NSLog(@"Calibration subframe %@ doesn't match exposure subframe %@",NSStringFromCASRect(calibrationSubframe),NSStringFromCASRect(exposureSubframe));
                    calibration = nil;
                }
            }
        }
    }
    return calibration;
}
*/

#pragma mark - Saving

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
        
        
        // restore menu settings
        self.equalise = [[self.cameraController.camera defaultsObjectForKey:@"SXIODisplayEqualise"] boolValue];
        self.calibrate = [[self.cameraController.camera defaultsObjectForKey:@"SXIODisplayCalibrate"] boolValue];
        self.showPlateSolution = [[self.cameraController.camera defaultsObjectForKey:@"SXIODisplayShowPlateSolution"] boolValue];
        
        self.exposureView.invert = [[self.cameraController.camera defaultsObjectForKey:@"SXIODisplayInvert"] boolValue];
        self.exposureView.medianFilter = [[self.cameraController.camera defaultsObjectForKey:@"SXIODisplayMedian"] boolValue];
        self.exposureView.contrastStretch = [[self.cameraController.camera defaultsObjectForKey:@"SXIODisplayContrastStretch"] boolValue];
        self.exposureView.showHistogram = [[self.cameraController.camera defaultsObjectForKey:@"SXIODisplayShowHistogram"] boolValue];
        self.exposureView.showReticle = [[self.cameraController.camera defaultsObjectForKey:@"SXIODisplayShowReticle"] boolValue];
        self.exposureView.showStarProfile = [[self.cameraController.camera defaultsObjectForKey:@"SXIODisplayShowStarProfile"] boolValue];
        self.exposureView.showImageStats = [[self.cameraController.camera defaultsObjectForKey:@"SXIODisplayShowImageStats"] boolValue];
        self.exposureView.flipVertical = [[self.cameraController.camera defaultsObjectForKey:@"SXIODisplayFlipVertical"] boolValue];
        self.exposureView.flipHorizontal = [[self.cameraController.camera defaultsObjectForKey:@"SXIODisplayFlipHorizontal"] boolValue];
        
        self.imageDebayer.mode = [[self.cameraController.camera defaultsObjectForKey:@"SXIODisplayDebayerMode"] integerValue];
    }
    
    // Subframes on the M26C aren't currently supported
    if (!self.cameraController.camera.canSubframe){
        [self.selectionControl setEnabled:NO forSegment:0];
    }
    
    // set progress display if this camera is capturing
    [self updateExposureIndicator];
}

- (void)setProgressStatusTextValue:(NSString*)text
{
    if (!text){
        text = @"";
    }
    if (![text isEqualToString:self.progressStatusText.stringValue]){ // seems to avoid significant performance problems with text fields
        self.progressStatusText.stringValue = text;
    }
}

- (void)updateExposureIndicator
{
    void (^commonShowProgressSetup)(NSString*,BOOL) = ^(NSString* statusText,BOOL showIndicator){
        self.progressIndicator.hidden = NO;
        self.progressIndicator.indeterminate = NO;
        [self setProgressStatusTextValue:statusText];
    };
    
    switch (self.cameraController.state) {
            
        case CASCameraControllerStateNone:{
            self.exposureView.showProgress = NO;
            self.progressIndicator.hidden = YES;
            [self setProgressStatusTextValue:nil];
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
                [self setProgressStatusTextValue:@"Downloading image..."];
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
                [self setProgressStatusTextValue:statusText];
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
        self.exposureView.plateSolveSolution = nil;
        return;
    }
    
    // check image view is actually visible before bothering to display it
    if (self.exposureView.isHiddenOrHasHiddenAncestor){
        return;
    }
    
    // lookup any cached solution if the exposure uuid has changed
    if (![exposure.uuid isEqualToString:self.currentExposureUUID]){
        
        // stash this as we may replace the exposure below and the uuids will no longer match
        self.currentExposureUUID = exposure.uuid;
        
        // clear any plate solution
        self.exposureView.plateSolveSolution = nil;
        
        if (self.showPlateSolution){
            
            // lookup any solution, this runs asynchronously so we need to track the current image uuid for when it completes
            [[SXIOPlateSolutionLookup sharedLookup] lookupSolutionForExposure:exposure completion:^(CASCCDExposure *solutionExposure, CASPlateSolveSolution *solution) {
                if (self.showPlateSolution && [solutionExposure.uuid isEqualToString:self.currentExposureUUID]){
                    self.exposureView.plateSolveSolution = solution;
                }
            }];
        }
        
        // live calibrate using saved bias and flat frames
        self.calibratedExposure = nil;
//        if (self.calibrate){
//            
//            NSURL* url = [self beginAccessToSaveTarget];
//            if (url){
//                
//                __block BOOL called = NO;
//                __block CASCCDExposure* corrected = exposure;
//                CASCCDCorrectionProcessor* corrector = [[CASCCDCorrectionProcessor alloc] init];
//                corrector.dark = [self calibrationExposureOfType:@"dark" matchingExposure:exposure];
//                corrector.bias = [self calibrationExposureOfType:@"bias" matchingExposure:exposure];
//                corrector.flat = [self calibrationExposureOfType:@"flat" matchingExposure:exposure];
//                [corrector processWithProvider:^(CASCCDExposure **exposurePtr, NSDictionary **info) {
//                    if (!called){
//                        *exposurePtr = exposure;
//                    }
//                    else {
//                        *exposurePtr = nil;
//                    }
//                    called = YES;
//                } completion:^(NSError *error, CASCCDExposure *result) {
//                    if (!error){
//                        corrected = result;
//                    }
//                }];
//                self.calibratedExposure = exposure = corrected;
//            }
//        }
    }
    
    // equalise
    if (self.equalise){
        exposure = [self.imageProcessor equalise:exposure];
    }
    
    // debayer (we do this as the last step as equalise only works with single-channel images, todo; make it work with rgba images as well)
    if (self.imageDebayer.mode != kCASImageDebayerNone){
        CASCCDExposure* debayeredExposure = [self.imageDebayer debayer:exposure adjustRed:1 green:1 blue:1 all:1];
        if (debayeredExposure){
            exposure = debayeredExposure;
        }
    }
    
    // set the exposure
    [self.exposureView setCurrentExposure:exposure resetDisplay:resetDisplay];
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
            
            // update the window title menu
            [self updateWindowTitleWithExposurePath:_currentExposure.io.url.path];

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

- (CGRect)validateSelectionRect:(CGRect)selection exposureView:(CASExposureView*)view
{
    CGSize size = CGSizeZero;
    CASCCDProperties* sensor = self.cameraController.camera.sensor;
    if (sensor){
        size = CGSizeMake(sensor.width, sensor.height);
    }
    else {
        size = CGSizeMake(CGImageGetWidth(self.exposureView.CGImage), CGImageGetHeight(self.exposureView.CGImage));
    }
    
    selection = CGRectIntersection(selection, CGRectMake(0, 0, size.width, size.height));
    
    const CASRect subframe = {
        .origin = CASPointMake(round(selection.origin.x), round(selection.origin.y)),
        .size = CASSizeMake(round(selection.size.width), round(selection.size.height))
    };
    const CASRect validatedSubframe = [self.cameraController.camera validateSubframe:subframe
                                                                             binning:CASSizeMake(self.cameraController.settings.binning,
                                                                                                 self.cameraController.settings.binning)];
    return CASCGRectFromCASRect(validatedSubframe);
}

- (void) selectionRectChanged: (CASExposureView*) imageView
{
    //    NSLog(@"selectionRectChanged: %@",NSStringFromRect(imageView.selectionRect));
    
    if (self.exposureView.image){
        const CGRect selectionRect = self.exposureView.selectionRect;
        if (CGRectIsEmpty(selectionRect)){
            self.cameraController.settings.subframe = CGRectZero;
        }
        else {
            self.cameraController.settings.subframe = selectionRect; // assuming -validateSelectionRect:exposureView: has been called
        }
    }
}

#pragma mark - CASCameraControllerSink

// todo; callback to allow the controller to check where the mount is pointing and to stop capture if the mount is below the horizon

- (void)cameraController:(CASCameraController*)controller didCompleteExposure:(CASCCDExposure*)exposure error:(NSError*)error
{
    NSString* const passedMeridianMessage = @"Mount has passed meridian so stopping tracking";
    
    // check to see if the exposure failed - if it did stop capture, tracking and guiding
    if (error){
        [self stopEverything:[NSString stringWithFormat:@"Capture error: %@",error.localizedDescription]];
        [NSApp presentError:error];
        return;
    }
    
    if (exposure){
        
        // save a reference to it (this is holding the pixels in memory though, may be better to store in a tmp file)
        self.latestExposure = exposure;
        
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

                if (![CASCCDExposureIO writeExposure:exposure toPath:[finalUrl path] error:&error]){
                    NSLog(@"Failed to write exposure to %@",[finalUrl path]);
                }
                else {
                    NSLog(@"Wrote exposure to %@",[finalUrl path]);
                    [[NSDocumentController sharedDocumentController] noteNewRecentDocumentURL:finalUrl];
                    [self.cameraController addRecentURL:finalUrl];
                    // todo; run any user-defined post-processing scripts e.g. NSUserAppleScriptTask
                }
                
                /*
                if (self.calibrate && self.calibratedExposure){
                    NSString* ext = [finalUrl pathExtension];
                    NSString* filename = [[[finalUrl lastPathComponent] stringByDeletingPathExtension] stringByAppendingString:@"_calibrated"];
                    NSString* calibratedPath = [[[[finalUrl path] stringByDeletingLastPathComponent] stringByAppendingPathComponent:filename] stringByAppendingPathExtension:ext];
                    
                    // todo; this is being written out as floating point...
                    
                    if (![CASCCDExposureIO writeExposure:self.calibratedExposure toPath:calibratedPath error:&error]){
                        NSLog(@"Failed to write calibrated exposure to %@",[finalUrl path]);
                    }
                    else {
                        NSLog(@"Wrote calibrated exposure to %@",[finalUrl path]);
                    }
                }
                */
            }
            
            // clear any calibrated exposure set in the display code
            self.calibratedExposure = nil;
        }
        
        // check to see if the mount is now pointing below the local horizon
        CASDevice<CASMount>* mount = self.mountController.mount;
        if (mount && ![mount horizonCheckRA:mount.ra.doubleValue dec:mount.dec.doubleValue]) {
            [self stopEverything:[NSString stringWithFormat:@"Mount is pointing below the local horizon"]];
            return;
        }
        
        // check to see if we crossed the meridian during the exposure
        if (self.mountController.mount.weightsHigh){
            
            switch ([[NSUserDefaults standardUserDefaults] integerForKey:@"SXIOMeridianMountBehaviour"]) {
                case 0:
                    NSLog(@"Mount crossed meridian but selected behaviour is to keep tracking");
                    break;
                    
                case 1:
                    if (controller.settings.currentCaptureIndex < controller.settings.captureCount - 1){
                        
                        NSLog(@"Mount crossed meridian - flipping mount after %ld out of %ld exposures",controller.settings.currentCaptureIndex,controller.settings.captureCount);
                        
                        // todo; stop exposures, etc
                        // todo; start flip spoken countdown
                        // todo; flip the mount
                        
                        // start the slew to the flipped position
                        [self startMountMeridianFlip];
                    }
                    else {
                        
                        NSLog(@"Mount crossed meridian and completed all exposures - stopping tracking");
                        [self stopEverything:passedMeridianMessage];
                    }
                    break;
                    
                case 2:
                default:
                    NSLog(@"Mount crossed meridian - stopping tracking");
                    [self stopEverything:passedMeridianMessage];
                    break;
            }
        }
        
        // todo; kick off a background plate solve for this exposure
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
    NSToolbarItem *item = [[CASToolbarItem alloc] initWithItemIdentifier:identifier];
    
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
    
    if ([@"Navigation" isEqualToString:itemIdentifier]){
        
        item = [self toolbarItemWithIdentifier:itemIdentifier
                                         label:@"Navigation"
                                   paleteLabel:@"Navigation"
                                       toolTip:nil
                                        target:self
                                   itemContent:self.navigationControl
                                        action:@selector(navigate:)
                                          menu:nil];
    }
    
    if ([NSToolbarFlexibleSpaceItemIdentifier isEqualToString:itemIdentifier]){
        item = [[NSToolbarItem alloc] initWithItemIdentifier:NSToolbarFlexibleSpaceItemIdentifier];
    }
    
    return item;
}

- (NSArray *)toolbarDefaultItemIdentifiers:(NSToolbar*)toolbar;
{
    return [NSArray arrayWithObjects:@"ZoomInOut",@"ZoomFit",@"Selection",NSToolbarFlexibleSpaceItemIdentifier,@"Navigation",nil];
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
            
        case 11108: // Add Bookmark...
            enabled = (self.exposureView.plateSolveSolution != nil);
            break;

        case 11109: // Edit Bookmarks...
            enabled = YES;
            break;
}
    return enabled;
}

#pragma mark - Sequence Target

- (CASMountController*) sequenceMountController // tmp
{
    return self.mountController;
}

- (BOOL)prepareToStartSequenceWithError:(NSError**)error
{
    if (![self checkReadyToCapture:error]){
        if (error){
            [NSApp presentError:*error];
        }
        return NO;
    }
    
    self.isRunningSequence = YES;
    
    return YES;
}

// this is the entry point from the sequence runner
- (void)captureWithCompletion:(void(^)(NSError*))completion
{
    // save the block ** todo; this will be cleared when the mount flips and the capture is cancelled so won't be called when the slew completes and capture restarts **
    self.captureCompletion = completion;

    // kick off the capture
    [self startCapture];
}

- (void)startCapture
{
    // disable idle sleep
    [CASPowerMonitor sharedInstance].disableSleep = YES;
    
    // ensure this is recorded as a light frame
    self.cameraController.settings.exposureType = kCASCCDExposureLightType;
    
    // suppress the next attempt to dither (this is relevant if we've restarted after a flip)
    self.cameraController.suppressDither = YES;
    
    // issue the capture command
    [self.cameraController captureWithBlock:^(NSError *error,CASCCDExposure* exposure) {
        
        if (!self.cameraController.capturing){
            
            // might be flipping in which case this will be called again but with a nil completion block which
            // means the sequence controller will never hear about the completed exposures and be stuck
            
            // re-enable idle sleep
            [CASPowerMonitor sharedInstance].disableSleep = NO;
            
            // post a completion notification if the capture wasn't cancelled
            if (!self.cameraController.cancelled){
                
                NSString* subtitle;
                NSString* title = NSLocalizedString(@"Capture Complete", @"Notification title");
                NSString* exposureUnits = (self.cameraController.settings.exposureUnits == 0) ? @"s" : @"ms";
                if (self.cameraController.settings.captureCount == 1){
                    subtitle = [NSString stringWithFormat:@"%ld exposure of %ld%@",(long)self.cameraController.settings.captureCount,self.cameraController.settings.exposureDuration,exposureUnits];
                }
                else {
                    subtitle = [NSString stringWithFormat:@"%ld exposures of %ld%@",(long)self.cameraController.settings.captureCount,self.cameraController.settings.exposureDuration,exposureUnits];
                }
                [[CASLocalNotifier sharedInstance] postLocalNotification:title subtitle:subtitle];
            }
            
            // only call the completion block if the camera isn't suspended
            // (this would happen if the exposure has been cancelled by a mount slew but will be restarted in which case we don't want to call the completion block just yet, this is just a temporary interruption)
            if (self.cameraController.settings.suspended){
                if (error){
                    [self captureCompletedWithError:error];
                }
                else {
                    NSLog(@"Camera completion block called while suspended so not calling calling capture completion block");
                }
            }
            else{
                [self captureCompletedWithError:error];
            }
        }
    }];
}

- (void)slewToBookmark:(NSDictionary*)bookmark plateSolve:(BOOL)plateSolve completion:(void(^)(NSError*))completion
{
    [self.mountController slewToBookmark:bookmark plateSolve:plateSolve completion:completion];
}

- (void)parkMountWithCompletion:(void(^)(NSError*))completion
{
    [self.mountController parkMountWithCompletion:completion];
}

- (void)captureCompletedWithError:(NSError*)error
{
    [self endSequence];
    
    if (self.captureCompletion){
        self.captureCompletion(error);
        self.captureCompletion = nil;
    }
}

- (void)endSequence
{
    self.isRunningSequence = NO;

    [self.cameraController cancelCapture]; // not calling the -cancelCapture: action on this class as that disables the Cancel button
}

- (void)stopGuiding
{
    if (self.cameraController.phd2Client.connected){
        [self.cameraController.phd2Client stop];
        [self.cameraController.phd2Client disconnect];
    }
}

- (void)stopEverything:(NSString*)message
{
    [[CASLocalNotifier sharedInstance] postLocalNotification:@"Stopping capture, guiding and tracking"
                                                    subtitle:message];
    
    [self.mountController stop]; // todo; option to park
    
    [self.cameraController cancelCapture];
    
    [self stopGuiding];
}

#pragma mark - Mount Notifications

- (void)mountSlewingStateChanged:(NSNotification*)note // todo; post from mount controller instead ?
{
    if (note.object == self.mountController.mount){
        [self handleMountSlewStateChanged];
    }
}

- (void)mountCapturedSyncExposure:(NSNotification*)note
{
    if (note.object == self.mountController){
        [self setCurrentExposure:note.userInfo[@"exposure"] resetDisplay:YES];
    }
}

- (void)mountSolvedSyncExposure:(NSNotification*)note
{
    if (note.object == self.mountController){
        self.exposureView.plateSolveSolution = note.userInfo[@"solution"];
    }
}

- (void)mountCompletedSync:(NSNotification*)note
{
    if (note.object == self.mountController){
        
        NSError* error = note.userInfo[@"error"];
        if (error){
            
            NSLog(@"Mount sync failed with error %@",error);
            
            [[CASLocalNotifier sharedInstance] postLocalNotification:@"Mount pointing failed" subtitle:error.localizedDescription];
            
            // get rid of the mount slewing sheet
            [self completeMountSlewHandling];
            
            // if we're running a sequence, propagate the error
            if (self.isRunningSequence) {
                [self captureCompletedWithError:error];
            }
            
            [self presentAlertWithTitle:@"Slew Failed" message:[error localizedDescription]];
        }
        else {
            
            NSLog(@"Mount sync completed successfully");
            
            // check to see if the slew was an intentional meridian flip and restart capture and guiding
            if (self.mountState.restoreStateWhenComplete){
                [self restoreStateAfterMountSlewCompleted];
            }
            else {
                // just clean up and we're done
                // this would happen if the synchroniser was running the slew but it wasn't as a result of us triggering the flip e.g. the user used the mount window to slew to a target
                [self completeMountSlewHandling];
                
                // pop a temporary alert to confirm the slew completed
                [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(dismissModal) object:nil];
                [self performSelector:@selector(dismissModal) withObject:nil afterDelay:5 inModes:@[NSRunLoopCommonModes]];
                [self presentAlertWithTitle:@"Slew Complete" message:@"The mount successfully synced to the target"];
            }
        }
        
        // todo; check to see if this is running a sequence step and call the completion block if it is (doing that now?)
    }
}

- (void)dismissModal
{
    [NSApp abortModal];
}

@end

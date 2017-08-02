//
//  SXIOAppDelegate.m
//  SX IO
//
//  Copyright (c) 2013, Simon Taylor
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

#import "SXIOAppDelegate.h"
#import "CASTemperatureTransformer.h"
#import "SXIOCameraWindowController.h"
#import "SXIOFilterWindowController.h"
#import "CASUpdateCheck.h"
#import "SXIOCalibrationWindowController.h"
#import "SXIOImageAdjustmentWindowController.h"
#import "SXIOExportMovieWindowController.h"
#import "SXIOPreferencesWindowController.h"
#import "CASProgressWindowController.h"
#import "CASCaptureCommand.h"
#import "CASCameraServer.h"
#import "CASMountWindowController.h"
#import "SXIOSequenceEditorWindowController.h"
#import "SXIOBookmarkWindowController.h"
#if defined(SXIO)
#import "SX_IO-Swift.h"
#else
#import "CCD_IO-Swift.h"
#endif
#import "SXIOM25CFixupTool.h"
#import <CoreAstro/CoreAstro.h>
#import <CoreAstro/CoreAstro-Swift.h>
#import <objc/runtime.h>

@interface SXIOAppDelegate ()
@property (weak) IBOutlet NSPanel *noDevicesHUD;
@property (strong) NSMutableArray *windows;
@property (strong) NSMenu *windowMenu;
@property (strong) SXIOCalibrationWindowController *calibrationWindow;
@property (strong) SXIOImageAdjustmentWindowController *imageAdjustment;
@property (strong) SXIOExportMovieWindowController *movieExportWindowController;
@property (strong) SXIOPreferencesWindowController *preferencesWindowController;
@end

@implementation SXIOAppDelegate

static void* kvoContext;

+ (void)initialize
{
    if (self == [SXIOAppDelegate class]){
        [NSValueTransformer setValueTransformer:[[CASTemperatureTransformer alloc] init] forName:@"CASTemperatureTransformer"];
        [[NSUserDefaults standardUserDefaults] registerDefaults:@{
         @"CASDefaultScopeAperture":@(101),
         @"CASDefaultScopeFNumber":@(5.4),
         @"SXIODefaultExposureFileType":@"fits",
         @"SXIODefaultExposureFileTypes":@[@"fits",@"fit"],
         @"SXIONoDevicesAlertOnStartup":@YES,
         @"SXIOAutoContrastStretch":@NO,
         @"SXIOCloseCameraWindowsOnDisconnect":@YES,
         @"SXIOSetMountLocationAndDateTimeOnConnect":@YES
         }];
    }
}

+ (instancetype)sharedInstance
{
    return (SXIOAppDelegate*)[NSApplication sharedApplication].delegate;
}

- (void)applicationWillFinishLaunching:(nonnull NSNotification *)notification
{
    [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"NSFullScreenMenuItemEverywhere"];
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    _windows = [NSMutableArray arrayWithCapacity:5];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        
#if SXIO_BETA
        NSString* const betaWarningKey = [NSString stringWithFormat:@"SXIOBetaWarningDisplayed%@",[[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"]];
        if (![[NSUserDefaults standardUserDefaults] boolForKey:betaWarningKey]){
            
            NSAlert* alert = [NSAlert alertWithMessageText:@"BETA SOFTWARE"
                                             defaultButton:@"Quit"
                                           alternateButton:@"OK"
                                               otherButton:nil
                                 informativeTextWithFormat:@"Please be aware that this is Beta software. There is no guarantee it will work correctly and there's no offical support although you can send comments to coreastro@icloud.com. If you're not OK with that please click Quit.",nil];
            
            alert.showsSuppressionButton = YES;
            
            if ([alert runModal] == NSOKButton){
                
                [NSApp terminate:nil];
                return;
            }
            else {
                
                if ([[alert suppressionButton] state]){
                    [[NSUserDefaults standardUserDefaults] setBool:YES forKey:betaWarningKey];
                }
            }
        }
#endif
        
        [CASBookmarks sharedInstance];
        [CASLocalNotifier sharedInstance];
        
        [[CASDeviceManager sharedManager] addObserver:self forKeyPath:@"cameraControllers" options:NSKeyValueObservingOptionNew|NSKeyValueObservingOptionOld|NSKeyValueObservingOptionInitial context:&kvoContext];
        [[CASDeviceManager sharedManager] addObserver:self forKeyPath:@"filterWheelControllers" options:NSKeyValueObservingOptionNew|NSKeyValueObservingOptionOld|NSKeyValueObservingOptionInitial context:&kvoContext];
        
        [[CASDeviceManager sharedManager] scan];
        
        [[CASUpdateCheck sharedUpdateCheck] checkForUpdate];
        
//        [[CASCameraServer sharedServer] start];

        // check after 1s to see if no devices are connected and if not show a one-time HUD indicating that something needs to be plugged in
        if ([[NSUserDefaults standardUserDefaults] boolForKey:@"SXIONoDevicesAlertOnStartup"]){
            
            double delayInSeconds = 1.0;
            dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
            dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
                if (![_windows count]){
                    [self.noDevicesHUD center];
                    [self.noDevicesHUD makeKeyAndOrderFront:nil];
                }
            });
        }
    });

    // Clone Window menu as we want to manage it ourselves
    NSMenu* existingWindowMenu = [NSApplication sharedApplication].windowsMenu;
    self.windowMenu = [[NSMenu alloc] initWithTitle:existingWindowMenu.title];
    for (NSMenuItem* item in existingWindowMenu.itemArray){
        [self.windowMenu addItem:[item copy]];
    }
    NSMenuItem *windowItem = [[NSMenuItem alloc] initWithTitle:existingWindowMenu.title action:NULL keyEquivalent:@""];
    [windowItem setSubmenu:self.windowMenu];
    
    [[[NSApplication sharedApplication] mainMenu] removeItemAtIndex:[[NSApplication sharedApplication] mainMenu].numberOfItems - 2];
    [NSApplication sharedApplication].windowsMenu = nil;

    [[NSApp mainMenu] insertItem:windowItem atIndex:[NSApp mainMenu].numberOfItems-1];
}

- (NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication *)sender
{
    for (CASCameraController* controller in [CASDeviceManager sharedManager].cameraControllers){
        
        if (controller.capturing){
            
            NSAlert* alert = [NSAlert alertWithMessageText:@"Are you sure you want to quit ?"
                                             defaultButton:@"Cancel"
                                           alternateButton:@"OK"
                                               otherButton:nil
                                 informativeTextWithFormat:@"There are exposures currently running.",nil];
            
            [alert beginSheetModalForWindow:[NSApplication sharedApplication].mainWindow modalDelegate:self didEndSelector:@selector(quitConfirmSheetCompleted:returnCode:contextInfo:) contextInfo:nil];
            
            return NSTerminateLater;
        }
    }
    
    return NSTerminateNow;
}

- (void)applicationWillTerminate:(NSNotification *)notification
{
    for (CASCameraController* controller in [CASDeviceManager sharedManager].cameraControllers){
        [controller disconnect];
    }
}

- (BOOL)application:(NSApplication *)sender openFile:(NSString *)filename
{
    BOOL result = NO;
    
    NSString* extension = [filename pathExtension];
    
    if ([extension isEqualToString:@"sxioSequence"]){
        
        SXIOSequenceEditorWindowController* editor = [SXIOSequenceEditorWindowController sharedWindowController];
        if (editor.stopped){ // just count steps ?
            result = [editor openURL:[NSURL fileURLWithPath:filename] doubleClicked:YES];
        }
    }
    else if ([extension isEqualToString:@"fit"] || [extension isEqualToString:@"fits"]){
        
        // todo; find the bext matching window for solution e.g. if possible for the camera that generated the exposure
        // todo; camera windows should work better with no connected camera esp. wrt device defaults
        
        // assume this is targeted at the frontmost camera window
        SXIOCameraWindowController* cameraWindow = [[[NSApplication sharedApplication] mainWindow] windowController];
        if ([cameraWindow isKindOfClass:[SXIOCameraWindowController class]]){
            result = [cameraWindow openExposureAtPath:filename];
        }
        else {
#if DEBUG
            SXIOCameraWindowController* cameraWindow = [[SXIOCameraWindowController alloc] initWithWindowNibName:@"SXIOCameraWindowController"];
            [cameraWindow.window makeKeyAndOrderFront:nil];
            [self addWindowToWindowMenu:cameraWindow];
            result = [cameraWindow openExposureAtPath:filename];
#endif
        }
    }
    
    return result;
}

- (NSError *)application:(NSApplication *)application willPresentError:(NSError *)error
{
    NSLog(@"willPresentError: %@",error); // broadcast error messages via email, text, etc
    return error;
}

- (void)quitConfirmSheetCompleted:(NSAlert*)sender returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo
{
    [NSApp replyToApplicationShouldTerminate:(returnCode == 0)];
}

- (NSWindowController*)findDeviceWindowController:(CASDeviceController*)controller
{
    for (id window in _windows){
        if ([window isKindOfClass:[SXIOCameraWindowController class]] && (((SXIOCameraWindowController*)window).cameraController == controller || [((SXIOCameraWindowController*)window).cameraDeviceID isEqualToString:controller.device.uniqueID])){
            return window;
        }
        if ([window isKindOfClass:[SXIOFilterWindowController class]] && ((SXIOFilterWindowController*)window).filterWheelController == controller){
            return window;
        }
    }

    return nil;
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if (context == &kvoContext) {
        
        switch ([[change objectForKey:NSKeyValueChangeKindKey] integerValue]) {
                
                // camera added, create/show the capture window
            case NSKeyValueChangeSetting:
            case NSKeyValueChangeInsertion:{
                [[change objectForKey:NSKeyValueChangeNewKey] enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {

                    NSWindowController* windowController = [self findDeviceWindowController:obj];
                    if ([windowController isKindOfClass:[SXIOCameraWindowController class]]){
                        SXIOCameraWindowController* cameraWindow = (SXIOCameraWindowController*)windowController;
                        cameraWindow.cameraController = obj;
                    }
                    else{
                    
                        if ([obj isKindOfClass:[CASCameraController class]]){
                            
                            SXIOCameraWindowController* cameraWindow = [[SXIOCameraWindowController alloc] initWithWindowNibName:@"SXIOCameraWindowController"];
                            cameraWindow.cameraController = obj;
                            windowController = cameraWindow;
                            {
                                CASCameraController* controller = (CASCameraController*)obj;
                                if (controller.camera.beta){
                                    NSString* const betaWarningKey = [NSString stringWithFormat:@"SXIODeviceBetaWarningDisplayed%@",controller.device.deviceName];
                                    if (![[NSUserDefaults standardUserDefaults] boolForKey:betaWarningKey]){
                                        
                                        NSAlert* alert = [NSAlert alertWithMessageText:@"BETA SUPPORT"
                                                                         defaultButton:@"OK"
                                                                       alternateButton:nil
                                                                           otherButton:nil
                                                             informativeTextWithFormat:@"Support for this camera is still in development. Please let me know if you encounter any problems at coreastro@icloud.com",nil];
                                        
                                        [[NSUserDefaults standardUserDefaults] setBool:YES forKey:betaWarningKey];
                                        
                                        alert.showsSuppressionButton = YES;
                                        
                                        [alert runModal];
                                        
                                        if ([[alert suppressionButton] state]){
                                            [[NSUserDefaults standardUserDefaults] setBool:YES forKey:betaWarningKey];
                                        }
                                    }
                                }
                            }
                        }
                        else if ([obj isKindOfClass:[CASFilterWheelController class]]){
                            
                            SXIOFilterWindowController* filterWindow = [[SXIOFilterWindowController alloc] initWithWindowNibName:@"SXIOFilterWindowController"];
                            filterWindow.filterWheelController = obj;
                            windowController = filterWindow;
                        }
                        
                        if (windowController){
                            [self.noDevicesHUD orderOut:nil];
                            [windowController setShouldCascadeWindows:YES];
                            [windowController.window makeKeyAndOrderFront:nil];
                            [self addWindowToWindowMenu:windowController];
                        }
                    }
                }];
            }
                break;
                
                // camera or filter wheel removed, close the related window
            case NSKeyValueChangeRemoval:{
                [[change objectForKey:NSKeyValueChangeOldKey] enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                    
                    NSWindowController* window = [self findDeviceWindowController:obj];
                    if (window){
                        
                        // default behaviour is to close the window and remove from the Window menu
                        BOOL closeWindow = YES;
                        
                        // but, there's an option to keep camera windows open, so we just nil out the camera controller instead
                        if ([window isKindOfClass:[SXIOCameraWindowController class]]){
                            if (![[NSUserDefaults standardUserDefaults] boolForKey:@"SXIOCloseCameraWindowsOnDisconnect"]){
                                SXIOCameraWindowController* camera = (SXIOCameraWindowController*)window;
                                camera.cameraController = nil;
                                closeWindow = NO;
                            }
                        }
                        
                        if (closeWindow){
                            [window close];
                            [self removeWindowFromWindowMenu:window];
                        }
                    }
                }];
            }
                break;
            default:
                break;
        }
                
    } else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

- (void)activateWindow:(NSMenuItem*)sender
{
    NSWindowController* window = sender.representedObject;
    if ([window isKindOfClass:[NSWindowController class]]){
        [window.window makeKeyAndOrderFront:nil];
    }
}

- (void)addWindowToWindowMenu:(NSWindowController*)windowController
{
    NSParameterAssert(windowController);
    
    if ([_windows containsObject:windowController]){
        return;
    }
    
    [_windows addObject:windowController];

    // add to Window menu
    if ([_windows count] == 1){
        [self.windowMenu addItem:[NSMenuItem separatorItem]];
    }
    
    // hook up the item to the -activateWindow: action
    NSMenuItem *windowControllerItem = [[NSMenuItem alloc] initWithTitle:windowController.window.title action:@selector(activateWindow:) keyEquivalent:@""];
    windowControllerItem.target = self;
    windowControllerItem.representedObject = windowController;
    [self.windowMenu addItem:windowControllerItem];
}

- (void)removeWindowFromWindowMenu:(NSWindowController*)windowController
{
    NSParameterAssert(windowController);

    if (![_windows containsObject:windowController]){
        return;
    }

    // remove from Window menu
    for (NSMenuItem* item in [self.windowMenu.itemArray copy]){
        if (item.representedObject == windowController){
            [self.windowMenu removeItem:item];
        }
    }
    
    [_windows removeObject:windowController];

    // remove trailing separator
    if ([_windows count] == 0){
        [self.windowMenu removeItemAtIndex:self.windowMenu.numberOfItems-1];
    }
}

- (void)updateWindowInWindowMenu:(NSWindowController*)windowController
{
    for (NSMenuItem* item in [self.windowMenu.itemArray copy]){
        if (item.representedObject == windowController){
            item.title = windowController.window.title;
        }
    }
}

- (IBAction)sendFeedback:(id)sender
{
    NSString* const feedback = @"coreastro@icloud.com";
    NSURL* mailUrl = [NSURL URLWithString:[NSString stringWithFormat:@"mailto:%@?subject=%@",feedback,@"SX%20IO%20Feedback"]];
    if (![[NSWorkspace sharedWorkspace] openURL:mailUrl]){
        [[NSAlert alertWithMessageText:@"Send Feedback"
                         defaultButton:@"OK"
                       alternateButton:nil
                           otherButton:nil
             informativeTextWithFormat:[NSString stringWithFormat:@"You don't appear to have a configured email account on this Mac. You can send feedback to %@",feedback],nil] runModal];
    }
}

- (IBAction)calibrate:(id)sender
{
    if (!_calibrationWindow){
        _calibrationWindow = [[SXIOCalibrationWindowController alloc] initWithWindowNibName:@"SXIOCalibrationWindowController"];
    }
    [_calibrationWindow showWindow:nil];
}

- (IBAction)imageAdjustment:(id)sender
{
    if (!_imageAdjustment){
        _imageAdjustment = [[SXIOImageAdjustmentWindowController alloc] initWithWindowNibName:@"SXIOImageAdjustmentWindowController"];
    }
    [_imageAdjustment showWindow:nil];
}

- (IBAction)makeMovie:(id)sender
{
    if (!self.movieExportWindowController){
        self.movieExportWindowController = [SXIOExportMovieWindowController loadWindowController];
    }
    
//    [self.movieExportWindowController.window center];
//    [self.movieExportWindowController.window makeKeyAndOrderFront:nil];
    
    // todo; use a single pipeline for everything, not just movie export
//    CASFilterPipeline* pipeline = [CASFilterPipeline new];
//    pipeline.equalise = self.equalise;
//    pipeline.invert = self.exposureView.invert;
//    pipeline.medianFilter = self.exposureView.medianFilter;
//    pipeline.contrastStretch = self.exposureView.contrastStretch;
//    pipeline.stretchMin = self.exposureView.stretchMin;
//    pipeline.stretchMax = self.exposureView.stretchMax;
//    pipeline.stretchGamma = self.exposureView.stretchGamma;
//    pipeline.flipVertical = self.exposureView.flipVertical;
//    pipeline.flipHorizontal = self.exposureView.flipHorizontal;
//    // todo; debayer
//    // todo; preprocessing
//    self.movieExportWindowController.filterPipeline = pipeline;
    
    [self.movieExportWindowController runWithCompletion:^(NSError *error, NSURL *movieURL) {
        
//        [self.movieExportWindowController.window orderOut:nil];
        self.movieExportWindowController = nil;
        
        if (error){
            [NSApp presentError:error];
        }
        else if (movieURL) {
            
            NSAlert* alert = [NSAlert alertWithMessageText:@"Export Complete"
                                             defaultButton:@"OK"
                                           alternateButton:@"Cancel"
                                               otherButton:nil
                                 informativeTextWithFormat:@"Open the output movie ?",nil];
            if ([alert runModal] == NSOKButton){
                [[NSWorkspace sharedWorkspace] openURL:movieURL];
            }
        }
    }];
}

- (IBAction)showPreferences:(id)sender
{
    if (!self.preferencesWindowController){
        self.preferencesWindowController = [[SXIOPreferencesWindowController alloc] initWithWindowNibName:@"SXIOPreferencesWindowController"];
    }
    [self.preferencesWindowController showWindow:nil];
}

- (IBAction)connectToMount:(id)sender
{
    [[CASMountWindowController sharedMountWindowController] connectToMount:^{
        // connected
    }];
}

- (IBAction)sequence:(id)sender
{
    SXIOSequenceEditorWindowController* sequence = [SXIOSequenceEditorWindowController sharedWindowController];
    [sequence showWindow:nil];
}

- (IBAction)editBookmarks:sender
{
    [[SXIOBookmarkWindowController sharedController] showWindow:nil];
}

- (IBAction)fixupM25CFrames:(id)sender
{
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"SXIOFixupM25CExplainerDisplayed"]){
        [self fixupM25CFramesImpl];
    }
    else{
    
        NSAlert* alert = [NSAlert alertWithMessageText:@"M25C Fixup"
                                         defaultButton:@"OK"
                                       alternateButton:@"Cancel"
                                           otherButton:nil
                             informativeTextWithFormat:@"This tool corrects unbinned, full frame exposures from the M25C taken by versions of SX IO prior to 1.0.8.\n\nSelect the frames you want to correct and the tool will save new versions that allow them to be debayered correctly.",nil];
        
        alert.showsSuppressionButton = YES;
        
        if ([alert runModal] == NSOKButton){
            
            if ([[alert suppressionButton] state]){
                [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"SXIOFixupM25CExplainerDisplayed"];
            }
            [self fixupM25CFramesImpl];
        }
    }
}

- (void)fixupM25CFramesImpl
{
    NSOpenPanel* openPanel = [NSOpenPanel openPanel];
    
    openPanel.canChooseFiles = YES;
    openPanel.canChooseDirectories = NO;
    openPanel.allowsMultipleSelection = YES;
    openPanel.allowedFileTypes = @[@"fit",@"fits"];
    
    __block NSInteger count = 0;
    
    [openPanel beginWithCompletionHandler:^(NSInteger result) {
        
        if (result == NSFileHandlingPanelOKButton){
            
            NSString* documentsPath = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject;

            CASProgressWindowController* progress = [CASProgressWindowController createWindowController];
            [progress beginSheetModalForWindow:nil];
            [progress configureWithRange:NSMakeRange(0, [openPanel.URLs count]) label:@"Fixing..."];
            progress.canCancel = YES;
            
            dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
                
                [openPanel.URLs enumerateObjectsUsingBlock:^(NSURL* url, NSUInteger idx, BOOL* stop) {
                    
                    if (progress.cancelled){
                        *stop = YES;
                    }
                    else {
                        dispatch_async(dispatch_get_main_queue(), ^{
                            progress.progressBar.doubleValue++;
                        });
                        @autoreleasepool {
                            SXIOM25CFixupTool* fixup = [[SXIOM25CFixupTool alloc] initWithPath:url.path saveFolder:documentsPath];
                            NSError* error;
                            if ([fixup fixupWithError:&error]){
                                ++count;
                            }
                            else {
                                NSLog(@"%@",error.localizedFailureReason); // todo; report
                            }
                        }
                    }
                }];
                
                dispatch_async(dispatch_get_main_queue(), ^{
                    [progress endSheetWithCode:NSOKButton];
                    
                    NSAlert* alert = [[NSAlert alloc] init];
                    alert.messageText = [NSString stringWithFormat:@"Fixed %ld out of %ld exposures",count,openPanel.URLs.count];
                    [alert runModal];
                    
                    if (count > 0){
                        [[NSWorkspace sharedWorkspace] selectFile:nil inFileViewerRootedAtPath:documentsPath];
                    }
                });
            });
        }
    }];
}

- (BOOL)validateMenuItem:(NSMenuItem*)item
{
    BOOL enabled = YES;
    
    switch (item.tag) {
        case 10030:{
            SXIOCameraWindowController* cameraWindow = [[[NSApplication sharedApplication] mainWindow] windowController];
            if ([cameraWindow isKindOfClass:[SXIOCameraWindowController class]]){
                item.state = cameraWindow.exposureView.contrastStretch;
            }
            else {
                item.state = NSOffState;
            }
        }
            break;
        default:{
            NSWindowController* windowController = item.representedObject;
            if ([windowController isKindOfClass:[NSWindowController class]]){
                item.state = (windowController.window == [NSApp mainWindow]);
            }
        }
            break;
    }
    
    return enabled;
}

@end

static NSMutableArray* gRecentExposures;

@interface NSApplication (SXIOScripting)
@end

@implementation NSApplication (SXIOScripting)

- (NSArray*)exposures
{
    return gRecentExposures;
}

- (void)scriptingMakeMovie:(NSScriptCommand*)command
{
    NSArray* urls = command.arguments[@"exposures"];
    if (!urls.count){
        command.scriptErrorNumber = paramErr;
        command.scriptErrorString = NSLocalizedString(@"No exposures to make into a movie have been specified", nil);
        return;
    }
    
    NSString* path = [command.arguments[@"file"] path];
    if (!path.length){
        command.scriptErrorNumber = paramErr;
        command.scriptErrorString = NSLocalizedString(@"The path to export the movie to has not been specified", nil);
        return;
    }

    SXIOAppDelegate* delegate = (SXIOAppDelegate*)self.delegate;

    if (delegate.movieExportWindowController){
        command.scriptErrorNumber = paramErr;
        command.scriptErrorString = NSLocalizedString(@"There is a movie already exporting", nil);
        return;
    }
    
    if (!delegate.movieExportWindowController){
        delegate.movieExportWindowController = [SXIOExportMovieWindowController loadWindowController];
    }
    
    (void)delegate.movieExportWindowController.window;

    // configure the exporter save url, etc
    delegate.movieExportWindowController.URLs = command.arguments[@"exposures"];
    delegate.movieExportWindowController.saveURL = command.arguments[@"file"];
    delegate.movieExportWindowController.showDateTime = [command.arguments[@"showDate"] boolValue];
    delegate.movieExportWindowController.showFilename = [command.arguments[@"showFilename"] boolValue];
    delegate.movieExportWindowController.customAnnotation = command.arguments[@"customAnnotation"];
    delegate.movieExportWindowController.showCustom = delegate.movieExportWindowController.customAnnotation.length > 0;

    [delegate.movieExportWindowController runExporterWithCompletion:^(NSError *error){
        delegate.movieExportWindowController = nil;
        if (error){
            [NSApp presentError:error]; // todo; return to caller
        }
    }];
}

- (void)scriptingMake:(NSScriptCommand*)command
{
    const NSInteger objectClass = [[command.arguments valueForKeyPath:@"ObjectClass"] integerValue];
    NSDictionary* properties = [command.arguments valueForKeyPath:@"KeyDictionary"];

    if (objectClass == 'CASM'){
        NSString* devicePath = properties[@"scriptingPath"];
        if (!devicePath){
            command.scriptErrorNumber = paramErr;
            command.scriptErrorString = NSLocalizedString(@"The device path to the mount has not been specified", nil);
        }
        else {
            // todo; optional param of associated camera controller
            [command suspendExecution];
            [[CASMountWindowController sharedMountWindowController] connectToMountAtPath:devicePath completion:^(NSError* error,CASMountController* mountController){
                if (error){
                    command.scriptErrorNumber = error.code;
                    command.scriptErrorString = error.localizedDescription;
                }
                [command resumeExecutionWithResult:mountController.objectSpecifier];
            }];
        }
    }
    else {
        command.scriptErrorNumber = paramErr;
        command.scriptErrorString = NSLocalizedString(@"Making that kind of object is not currently supported", nil);
    }
}

- (void)scriptingLookup:(NSScriptCommand*)command
{
    // get the object param, look up in simbad, slew to location
    NSString* object = command.arguments[@"object"];
    if (!object.length){
        command.scriptErrorNumber = paramErr;
        command.scriptErrorString = NSLocalizedString(@"You must specify the name of the object to lookup", nil);
        return;
    }
    
    [command suspendExecution];
    
    [[CASObjectLookup new] lookupObject:object withCompletion:^(CASObjectLookupResult* result) {
        if (!result.foundIt){
            command.scriptErrorNumber = paramErr;
            command.scriptErrorString = [NSString stringWithFormat:NSLocalizedString(@"Couldn't locate the object '%@'", nil),object];
            [command resumeExecutionWithResult:nil];
        }
        else {
            
            NSNumber* rise;
            NSNumber* set;
            NSNumber* transit;
            NSDictionary* coords = @{@"ra":@(result.ra),@"dec":@(result.dec)};

            NSNumber* siteLatitude = [[NSUserDefaults standardUserDefaults] objectForKey:@"SXIOSiteLatitude"];
            NSNumber* siteLongitude = [[NSUserDefaults standardUserDefaults] objectForKey:@"SXIOSiteLongitude"];
            if (siteLatitude && siteLongitude){
                CASNova* nova = [[CASNova alloc] initWithObserverLatitude:siteLatitude.doubleValue longitude:siteLongitude.doubleValue];
                const CASRST rst = [nova rstForObjectRA:result.ra dec:result.dec jd:[CASNova today]];
                rise = @(rst.rise);
                set = @(rst.set);
                transit = @(rst.transit);
            }
            
            NSDictionary* result;
            if (rise){
                result = @{@"coords":coords,@"rise":rise,@"set":set,@"transit":transit};
            }
            else {
                result = @{@"coords":coords};
            }
            [command resumeExecutionWithResult:result];
        }
    }];
}

@end

@interface SXIOCaptureCommand : CASCaptureCommand
@end

@implementation SXIOCaptureCommand

- (id)initWithCommandDescription:(NSScriptCommandDescription *)commandDef
{
    self = [super initWithCommandDescription:commandDef];
    if (self){
        gRecentExposures = nil; // reset the exposures list
    }
    return self;
}

- (void)resumeExecutionWithResult:(id)result
{
    if ([result isKindOfClass:[NSArray class]]){
        if (!gRecentExposures){
            gRecentExposures = [NSMutableArray arrayWithCapacity:10];
        }
        [gRecentExposures addObjectsFromArray:result]; // todo; use NSCache ?
        // reset exposures ?
    }
    [super resumeExecutionWithResult:result];
}

@end


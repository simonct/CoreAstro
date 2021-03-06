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
#import "CASCaptureCommand.h"
#import <CoreAstro/CoreAstro.h>
#import <objc/runtime.h>

@interface SXIOAppDelegate ()
@property (weak) IBOutlet NSPanel *noDevicesHUD;
@property (strong) NSMutableArray *windows;
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
         @"SXIONoDevicesAlertOnStartup":@YES
         }];
    }
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    // HACK; swizzle - (NSArray*)exposures
    method_exchangeImplementations(class_getInstanceMethod([NSApplication class],@selector(exposures)),class_getInstanceMethod([NSApplication class],@selector(sxioExposures)));

    _windows = [NSMutableArray arrayWithCapacity:5];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        
        // beta warning for this version
        NSString* const betaWarningKey = [NSString stringWithFormat:@"SXIOBetaWarningDisplayed%@",[[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"]];
        if (![[NSUserDefaults standardUserDefaults] boolForKey:betaWarningKey]){
            
            NSAlert* alert = [NSAlert alertWithMessageText:@"BETA SOFTWARE"
                                             defaultButton:@"Quit"
                                           alternateButton:@"OK"
                                               otherButton:nil
                                 informativeTextWithFormat:@"Please be aware that this is Beta software. There is no guarantee it will work correctly and there's no offical support although you can send comments to feedback@coreastro.org. If you're not OK with that please click Quit.",nil];
            
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
        
        [[CASDeviceManager sharedManager] addObserver:self forKeyPath:@"cameraControllers" options:NSKeyValueObservingOptionNew|NSKeyValueObservingOptionOld|NSKeyValueObservingOptionInitial context:&kvoContext];
        [[CASDeviceManager sharedManager] addObserver:self forKeyPath:@"filterWheelControllers" options:NSKeyValueObservingOptionNew|NSKeyValueObservingOptionOld|NSKeyValueObservingOptionInitial context:&kvoContext];
        
        [[CASDeviceManager sharedManager] scan];
        
        [[CASUpdateCheck sharedUpdateCheck] checkForUpdate];

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

- (void)quitConfirmSheetCompleted:(NSAlert*)sender returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo
{
    [NSApp replyToApplicationShouldTerminate:(returnCode == 0)];
}

- (NSWindowController*)findWindowController:(id)controller
{
    for (id window in [_windows copy]){
        if ([window isKindOfClass:[SXIOCameraWindowController class]] && ((SXIOCameraWindowController*)window).cameraController == controller){
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

                    NSWindowController* windowController = [self findWindowController:obj];
                    if (!windowController){
                        
                        if ([obj isKindOfClass:[CASCameraController class]]){
                            
                            SXIOCameraWindowController* cameraWindow = [[SXIOCameraWindowController alloc] initWithWindowNibName:@"SXIOCameraWindowController"];
                            cameraWindow.cameraController = obj;
                            windowController = cameraWindow;
                        }
                        else if ([obj isKindOfClass:[CASFilterWheelController class]]){
                            
                            SXIOFilterWindowController* filterWindow = [[SXIOFilterWindowController alloc] initWithWindowNibName:@"SXIOFilterWindowController"];
                            filterWindow.filterWheelController = obj;
                            windowController = filterWindow;
                        }
                    }
                    
                    if (windowController){
                        [self.noDevicesHUD orderOut:nil];
                        [windowController setShouldCascadeWindows:YES];
                        [windowController.window makeKeyAndOrderFront:nil];
                        [_windows addObject:windowController];
                    }
                }];
            }
                break;
                
                // camera or filter wheel removed, close the related window
            case NSKeyValueChangeRemoval:{
                [[change objectForKey:NSKeyValueChangeOldKey] enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                    
                    NSWindowController* window = [self findWindowController:obj];
                    if (window){
                        [window close];
                        [_windows removeObject:window];
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

- (IBAction)sendFeedback:(id)sender
{
    NSString* const feedback = @"feedback@coreastro.org";
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

@end

static NSMutableArray* gRecentExposures;

@interface NSApplication (SXIOScripting)
@end

@implementation NSApplication (SXIOScripting)

- (NSArray*)sxioExposures
{
    return gRecentExposures;
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


//
//  CASAppDelegate.m
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

#import "CASAppDelegate.h"
#import "CASCameraWindowController.h"
#import "CASPreferencesWindowController.h"
#import <CoreAstro/CoreAstro.h>

@interface CASTemperatureTransformer : NSValueTransformer
@end

@implementation CASTemperatureTransformer

- (id)transformedValue:(id)value
{
    return [NSNumber numberWithDouble:[value doubleValue]];
}

- (id)reverseTransformedValue:(id)value
{
    return [NSString stringWithFormat:@"%@",value];
}

@end

@interface CASAppDelegate () <CASCameraWindowControllerDelegate>
@property (nonatomic,strong) NSMutableArray* windows;
@property (nonatomic,strong) CASPreferencesWindowController* prefsController;
- (IBAction)showPreferences:(id)sender;
@end

@implementation CASAppDelegate

@synthesize windows;

+ (void)initialize
{
    if (self == [CASAppDelegate class]){
        [NSValueTransformer setValueTransformer:[[CASTemperatureTransformer alloc] init] forName:@"CASTemperatureTransformer"];
        [[NSUserDefaults standardUserDefaults] registerDefaults:@{@"CASDefaultScopeAperture":@(101),@"CASDefaultScopeFNumber":@(5.4)}];
    }
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    self.windows = [NSMutableArray arrayWithCapacity:10];

    CASCameraWindowController* cameraWindow = [[CASCameraWindowController alloc] initWithWindowNibName:@"CASCameraWindowController"];
    cameraWindow.delegate = self;
    cameraWindow.shouldCascadeWindows = NO;
    [cameraWindow.window makeKeyAndOrderFront:nil];
    [self.windows addObject:cameraWindow];

    dispatch_async(dispatch_get_main_queue(), ^{
        [[CASDeviceManager sharedManager] scan];
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

- (IBAction)showPreferences:(id)sender
{
    if (!self.prefsController){
        self.prefsController = [[CASPreferencesWindowController alloc] initWithWindowNibName:NSStringFromClass([CASPreferencesWindowController class])];
        [self.prefsController.window center];
    }
    [self.prefsController showWindow:nil];
}

@end

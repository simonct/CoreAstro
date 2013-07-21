//
//  CASAppDelegate.m
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

#import "CASAppDelegate.h"
#import "CASTemperatureTransformer.h"
#import "SXIOCameraWindowController.h"
#import <CoreAstro/CoreAstro.h>

@implementation CASAppDelegate {
    NSMutableArray* _cameraWindows;
}

static void* kvoContext;

+ (void)initialize
{
    if (self == [CASAppDelegate class]){
        [NSValueTransformer setValueTransformer:[[CASTemperatureTransformer alloc] init] forName:@"CASTemperatureTransformer"];
        [[NSUserDefaults standardUserDefaults] registerDefaults:@{@"CASDefaultScopeAperture":@(101),@"CASDefaultScopeFNumber":@(5.4)}];
    }
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    _cameraWindows = [NSMutableArray arrayWithCapacity:5];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        
        [[CASDeviceManager sharedManager] addObserver:self forKeyPath:@"cameraControllers" options:NSKeyValueObservingOptionNew|NSKeyValueObservingOptionOld|NSKeyValueObservingOptionInitial context:&kvoContext];
        
        [[CASDeviceManager sharedManager] scan];
        
        
//        SXIOCameraWindowController* cameraWindow = [[SXIOCameraWindowController alloc] initWithWindowNibName:@"SXIOCameraWindowController"];
//        cameraWindow.shouldCascadeWindows = NO;
//        [cameraWindow.window makeKeyAndOrderFront:nil];
//        
//        [_cameraWindows addObject:cameraWindow];

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

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if (context == &kvoContext) {
        
        switch ([[change objectForKey:NSKeyValueChangeKindKey] integerValue]) {
                
                // camera added, create/show the capture window
            case NSKeyValueChangeSetting:
            case NSKeyValueChangeInsertion:{
                [[change objectForKey:NSKeyValueChangeNewKey] enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {

                    if ([obj isKindOfClass:[CASCameraController class]]){
                        
                        SXIOCameraWindowController* cameraWindow = [[SXIOCameraWindowController alloc] initWithWindowNibName:@"SXIOCameraWindowController"];
                        cameraWindow.cameraController = obj;
                        cameraWindow.shouldCascadeWindows = NO;
                        [cameraWindow.window makeKeyAndOrderFront:nil];
                        
                        [_cameraWindows addObject:cameraWindow];
                    }
                }];
            }
                break;
                
                // camera removed, close the capture window
            case NSKeyValueChangeRemoval:{
                [[change objectForKey:NSKeyValueChangeOldKey] enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                    
                    for (SXIOCameraWindowController* cameraWindow in [_cameraWindows copy]){
                        if (cameraWindow.cameraController == obj){
                            [cameraWindow close];
                            [_cameraWindows removeObject:cameraWindow];
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

@end

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
#import "CASCameraController.h"
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
@end

@implementation CASAppDelegate

@synthesize windows, cameraControllers;

+ (void)initialize {
    [NSValueTransformer setValueTransformer:[[CASTemperatureTransformer alloc] init] forName:@"CASTemperatureTransformer"];
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    self.windows = [NSMutableArray arrayWithCapacity:10];
    self.cameraControllers = [NSMutableArray arrayWithCapacity:10];

    CASCameraWindowController* cameraWindow = [[CASCameraWindowController alloc] initWithWindowNibName:@"CASCameraWindowController"];
    cameraWindow.delegate = self;
    cameraWindow.shouldCascadeWindows = NO;
    [cameraWindow.window makeKeyAndOrderFront:nil];
    [self.windows addObject:cameraWindow];

    dispatch_async(dispatch_get_main_queue(), ^{
        
        [[CASDeviceManager sharedManager] addObserver:self forKeyPath:@"devices" options:NSKeyValueObservingOptionInitial|NSKeyValueObservingOptionOld context:nil];
        [[CASDeviceManager sharedManager] scan];
    });
}

- (NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication *)sender
{
    for (CASCameraController* controller in self.cameraControllers){
        
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
    for (CASCameraController* controller in self.cameraControllers){
        [controller disconnect];
    }
}

- (void)quitConfirmSheetCompleted:(NSAlert*)sender returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo
{
    [NSApp replyToApplicationShouldTerminate:(returnCode == 0)];
}

- (CASCameraWindowController*)windowControllerForCamera:(CASDevice*)camera
{
    for (CASCameraWindowController* controller in self.windows){
        if (controller.cameraController.camera == camera){
            return controller;
        }
    }
    return nil;
}

- (void)cameraWindowWillClose:(CASCameraWindowController*)window
{
    [self.windows removeObject:window];
}

// todo; most of this should probably be in the device manager
- (void)processDevices:(NSArray*)devices
{
    for (CASDevice* device in devices){
        
        CASCCDDevice* ccd = (CASCCDDevice*)device;
        if ([ccd isKindOfClass:[CASCCDDevice class]]){ // todo; need a CASCCDDevice protocol and check for that instead of a class
                        
            [ccd connect:^(NSError* error) {
                                
                if (error){
                    [NSApp presentError:error]; // todo: specific error message
                }
                else {
                    
                    if (![self.windows count]){
                        CASCameraWindowController* cameraWindow = [[CASCameraWindowController alloc] initWithWindowNibName:@"CASCameraWindowController"];
                        cameraWindow.delegate = self;
                        cameraWindow.shouldCascadeWindows = NO;
                        [cameraWindow.window makeKeyAndOrderFront:nil];
                        [self.windows addObject:cameraWindow];
                    }
                    CASCameraController* cameraController = [[CASCameraController alloc] initWithCamera:ccd];
                    if (cameraController){
                        cameraController.imageProcessor = [CASImageProcessor imageProcessorWithIdentifier:nil];
                        cameraController.guideAlgorithm = [CASGuideAlgorithm guideAlgorithmWithIdentifier:nil];
                        [self willChangeValueForKey:@"cameraControllers"];
                        [self.cameraControllers addObject:cameraController];
                        [self didChangeValueForKey:@"cameraControllers"];
                    }
                    if ([self.windows count] == 1){
                        CASCameraWindowController* cameraWindow = [self.windows lastObject];
                        if (!cameraWindow.cameraController){
                            cameraWindow.cameraController = cameraController;
                        }
                    }
                }
            }];
        }
        
        // todo; check for compliance with CASGuider and add to the guiders list
        if (0){
            
        }
    }
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if (context == nil) {
        
        switch ([[change objectForKey:NSKeyValueChangeKindKey] integerValue]) {
                
            case NSKeyValueChangeSetting:
            case NSKeyValueChangeInsertion: {
                NSArray* devices = nil;
                NSIndexSet* indexes = [change objectForKey:NSKeyValueChangeIndexesKey];
                if (indexes){
                    devices = [[CASDeviceManager sharedManager].devices objectsAtIndexes:indexes];
                }
                else {
                    devices = [CASDeviceManager sharedManager].devices;
                }
                [self processDevices:devices];
            }
                break;
                
            case NSKeyValueChangeRemoval: {
                NSArray* old = [change objectForKey:NSKeyValueChangeOldKey];
                if (old){
                    if (![old isKindOfClass:[NSArray class]]){
                        old = [NSArray arrayWithObject:old];
                    }
                    for (CASDevice* device in old){
                        CASCameraWindowController* cameraWindow = [self windowControllerForCamera:device];
                        if (cameraWindow){
                            [cameraWindow.cameraController disconnect];
                            [self willChangeValueForKey:@"cameraControllers"];
                            [self.cameraControllers removeObject:cameraWindow.cameraController];
                            [self didChangeValueForKey:@"cameraControllers"];
                            if ([self.windows count] > 1){
                                [cameraWindow close];
                                [self.windows removeObject:cameraWindow];
                            }
                            else {
                                cameraWindow.cameraController = nil;
                            }
                        }
                    }
                }
            }
                break;
        }

    } else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

@end

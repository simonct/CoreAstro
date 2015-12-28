//
//  SXIOAppDelegate.m
//  fli-test
//
//  Created by Simon Taylor on 29/11/2013.
//  Copyright (c) 2013 Simon Taylor. All rights reserved.
//

#import "SXIOAppDelegate.h"
#import "FLISDK.h"
#import "FLICCDDevice.h"
#import "CASCCDExposureIO.h"

@interface SXIOAppDelegate ()
@property (weak) IBOutlet NSTableView *tableView;
@property (weak) IBOutlet NSArrayController *devicesArrayController;
@property (strong) FLISDK* sdk;
@property NSInteger exposureMS;
@property BOOL exposing;
@end

@implementation SXIOAppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)notification
{
    self.sdk = [FLISDK new];
    
    __weak __typeof (self) weakSelf = self;
    self.sdk.deviceAdded = ^(NSString* path,CASDevice* device){
        [weakSelf.devicesArrayController addObject:device];
        [device connect:^(NSError* error) {
            if (error){
                dispatch_async(dispatch_get_main_queue(), ^{
                    [NSApp presentError:error];
                });
            }
        }];
    };
    
    [self.sdk scan];
}

- (void)applicationWillTerminate:(NSNotification *)notification
{
    [self.devicesArrayController.arrangedObjects makeObjectsPerformSelector:@selector(disconnect)];
}

- (IBAction)capture:(id)sender
{
    if (self.exposing){
        NSLog(@"Busy");
        return;
    }
    FLICCDDevice* ccd = self.devicesArrayController.selectedObjects.firstObject;
    if (![ccd isKindOfClass:[FLICCDDevice class]]){
        NSLog(@"No selected ccd");
        return;
    }
    if (self.exposureMS < 1){
        NSLog(@"Exposure time < 1");
        return;
    }

    const CASExposeParams params = {
        .bin = CASSizeMake(1, 1),
        .origin = CASPointMake(0, 0),
        .size = CASSizeMake(ccd.sensor.width, ccd.sensor.height),
        .frame = CASSizeMake(ccd.sensor.width, ccd.sensor.height),
        .bps = 16,
        .ms = self.exposureMS
    };
    
    self.exposing = YES;
    
    [ccd exposeWithParams:params type:kCASCCDExposureLightType block:^(NSError* error, CASCCDExposure *exposure) {
        
        self.exposing = NO;
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if (error){
                [NSApp presentError:error];
            }
            else {
                NSSavePanel* save = [NSSavePanel savePanel];
                save.allowedFileTypes = @[@"fit"];
                save.canCreateDirectories = YES;
                [save beginWithCompletionHandler:^(NSInteger result) {
                    
                    if (result == NSFileHandlingPanelOKButton){
                        NSError* error;
                        CASCCDExposureIO* io = [CASCCDExposureIO exposureIOWithPath:save.URL.path];
                        [io writeExposure:exposure writePixels:YES error:&error];
                        if (error){
                            [NSApp presentError:error];
                        }
                    }
                }];
            }
        });
    }];
}

@end

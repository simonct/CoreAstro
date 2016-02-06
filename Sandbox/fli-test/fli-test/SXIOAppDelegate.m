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
@property NSInteger binning;
@property BOOL exposing;
@end

@implementation SXIOAppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)notification
{
    self.sdk = [FLISDK new];
    self.exposureMS = 1000;
    self.binning = 1;
    
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

- (void)showErrorAlert:(NSString*)message
{
    NSAlert* alert = [NSAlert alertWithMessageText:@"Error"
                                     defaultButton:@"OK"
                                   alternateButton:nil
                                       otherButton:nil
                         informativeTextWithFormat:@"%@",message];
    
    [alert runModal];
}

- (IBAction)capture:(id)sender
{
    if (self.exposing){
        [self showErrorAlert:@"Exposure already in progress"];
        return;
    }
    FLICCDDevice* ccd = self.devicesArrayController.selectedObjects.firstObject;
    if (![ccd isKindOfClass:[FLICCDDevice class]]){
        [self showErrorAlert:@"There's no selected CCD"];
        return;
    }
    if (self.exposureMS < 1){
        [self showErrorAlert:@"Exposure time is < 1ms"];
        return;
    }
    if (![ccd.binningModes containsObject:@(self.binning)]){
        [self showErrorAlert:@"Invalid binning"];
        return;
    }

    const CASExposeParams params = {
        .bin = CASSizeMake(self.binning, self.binning),
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

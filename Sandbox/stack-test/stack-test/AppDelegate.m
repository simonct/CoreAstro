//
//  AppDelegate.m
//  stack-test
//
//  Created by Simon Taylor on 21/11/2012.
//  Copyright (c) 2012 Simon Taylor. All rights reserved.
//

#import "AppDelegate.h"
#import "CASCCDExposureIO.h"
#import "CASExposuresView.h"

@interface AppDelegate ()
@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    // Insert code here to initialize your application
}

- (void)openDocument:(id)sender
{
    NSOpenPanel* open = [NSOpenPanel openPanel];
    
    open.allowedFileTypes = @[@"caExposure"]; // get from CASCCDExposureIO
    open.allowsMultipleSelection = YES;
    
    [open beginSheetModalForWindow:self.window completionHandler:^(NSInteger result) {
        
        if (result == NSFileHandlingPanelOKButton){
                        
            NSMutableArray* exposures = [NSMutableArray arrayWithCapacity:10];
            
            for (NSURL* url in open.URLs){
                CASCCDExposureIO* io = [CASCCDExposureIO exposureIOWithPath:url.path];
                if (io){
                    CASCCDExposure* exposure = [[CASCCDExposure alloc] init];
                    exposure.io = io;
                    [exposures addObject:exposure];
                }
            }
            
            self.imageView.exposures = [exposures copy];
        }
    }];
}

- (void)saveDocument:(id)sender
{
    if (!self.imageView.currentExposure){
        return;
    }
    
    NSSavePanel* save = [NSSavePanel savePanel];
    save.allowedFileTypes = @[@"fits",@"fit"];
    [save beginSheetModalForWindow:self.window completionHandler:^(NSInteger result) {
        
        if (result == NSFileHandlingPanelOKButton){
            
            CASCCDExposureIO* io = [CASCCDExposureIO exposureIOWithPath:[save.URL path]];
            if (!io){
                NSLog(@"*** Failed to create FITS exporter");
            }
            else {
                NSError* error = nil;
                [io writeExposure:self.imageView.currentExposure writePixels:YES error:&error];
                if (error){
                    [NSApp presentError:error];
                }
            }
        }
    }];
}

@end

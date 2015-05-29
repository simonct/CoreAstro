//
//  CaptureWindowController.m
//  astrometry-test
//
//  Created by Simon Taylor on 5/29/15.
//  Copyright (c) 2015 Simon Taylor. All rights reserved.
//

#import "CaptureWindowController.h"

@interface CaptureWindowController ()
@property NSInteger exposureTime;
@property NSInteger binningIndex;
@property (weak) id<CASINDICamera> selectedCamera;
@property (weak) NSWindow* parent;
@end

@implementation CaptureWindowController

- (void)windowDidLoad {
    [super windowDidLoad];
    self.exposureTime = 5;
    self.binningIndex = 2;
}

- (void)beginSheet:(NSWindow*)window completionHandler:(void(^)(NSModalResponse))completion
{
    self.parent = window;
    
    for (CASINDIDevice* device in self.container.devices){
        [device connect];
    }
    self.selectedCamera = self.container.cameras.firstObject;
    [window beginSheet:self.window completionHandler:completion];
}

- (IBAction)close:(id)sender
{
    // cancel exposure ?
    
    [self.parent endSheet:self.window returnCode:NSModalResponseStop];
}

- (IBAction)capture:(id)sender
{
    self.selectedCamera.exposureTime = self.exposureTime;
    
    switch (self.binningIndex) {
        case 0:
            self.selectedCamera.binning = 1;
            break;
        case 1:
            self.selectedCamera.binning = 2;
            break;
        case 2:
            self.selectedCamera.binning = 4;
            break;
    }

    [self.selectedCamera captureWithCompletion:^(NSData *exposureData) {
        NSLog(@"Exposure read %ld bytes of data",exposureData.length);
        if (exposureData.length > 0){
//            [exposureData writeToFile:[@"~/indi-camera.fit" stringByExpandingTildeInPath] atomically:YES];
            [self.captureDelegate captureWindow:self didCapture:exposureData];
        }
    }];
}

- (void)setNilValueForKey:(NSString *)key
{
    if ([@"exposureTime" isEqualToString:key]){
        self.exposureTime = 0;
        return;
    }
    if ([@"binningIndex" isEqualToString:key]){
        self.binningIndex = 0;
        return;
    }
    [super setNilValueForKey:key];
}

+ (instancetype)loadWindow
{
    return [[CaptureWindowController alloc] initWithWindowNibName:@"CaptureWindowController"];
}

@end

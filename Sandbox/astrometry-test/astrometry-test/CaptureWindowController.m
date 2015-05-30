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
@property NSInteger secondsRemaining;
@property (weak) id<CASINDICamera> selectedCamera;
@property (weak) NSWindow* parent;
@property (strong) IBOutlet NSArrayController *camerasArrayController;
@property BOOL capturing;
@end

@implementation CaptureWindowController

- (void)windowDidLoad {
    [super windowDidLoad];
    self.exposureTime = 5;
    self.binningIndex = 2;
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(cameraAdded:) name:kCASINDIContainerAddedCameraNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(vectorUpdated:) name:kCASINDIUpdatedVectorNotification object:nil];
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
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

- (void)endSheet
{
    [self.parent endSheet:self.window returnCode:NSModalResponseContinue];
}

- (void)cameraAdded:(NSNotification*)note
{
    id<CASINDICamera> camera = note.userInfo[@"camera"];
    if (camera && !self.selectedCamera){
        [self.camerasArrayController rearrangeObjects];
        self.selectedCamera = camera;
    }
}

- (void)vectorUpdated:(NSNotification*)note
{
    CASINDIVector* vector = note.object;
    CASINDIValue* value = note.userInfo[@"value"];
    if ([vector.name isEqualToString:@"CCD_EXPOSURE"] && [value.name isEqualToString:@"CCD_EXPOSURE_VALUE"] && vector.device == self.selectedCamera){
        self.secondsRemaining = [value.value integerValue];
    }
}

- (IBAction)close:(id)sender
{
    // cancel exposure ?
    
    [self.parent endSheet:self.window returnCode:NSModalResponseStop];
}

- (IBAction)capture:(id)sender
{
    if (self.exposureTime < 1){
        NSBeep();
        return;
    }
    
    self.capturing = YES;
    
    self.selectedCamera.exposureTime = self.exposureTime;
    
    switch (self.binningIndex) {
        default:
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
        if (exposureData.length > 0){
            [self.captureDelegate captureWindow:self didCapture:exposureData];
        }
        self.capturing = NO;
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

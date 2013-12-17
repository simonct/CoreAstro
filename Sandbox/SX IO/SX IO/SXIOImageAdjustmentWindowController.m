//
//  SXIOImageAdjustmentWindowController.m
//  SX IO
//
//  Created by Simon Taylor on 12/17/13.
//  Copyright (c) 2013 Simon Taylor. All rights reserved.
//

#import "SXIOImageAdjustmentWindowController.h"
#import "SXIOCameraWindowController.h"
#import "SMDoubleSlider.h"

@interface SXIOImageAdjustmentWindowController ()
@property (nonatomic,strong) SXIOCameraWindowController* cameraWindowController;
@property (weak) IBOutlet NSButton *contrastStretchCheckbox;
@property (weak) IBOutlet SMDoubleSlider *contrastStretchSlider;
@property (weak) IBOutlet NSSlider *gammaSlider;
@property (weak) IBOutlet NSButton *autoContrastStretchCheckbox;
@property (weak) IBOutlet NSTextField *blackValueLabel;
@property (weak) IBOutlet NSTextField *whiteValueLabel;
@property (weak) IBOutlet NSTextField *gammaValueLabel;
@end

@implementation SXIOImageAdjustmentWindowController {
    BOOL _registeredNotificationHandlers:1;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    self.cameraWindowController = nil;
}

- (void)windowDidLoad
{
    [super windowDidLoad];
    
    [self windowDidBecomeMain:[NSApplication sharedApplication].mainWindow];
    
    if (!_registeredNotificationHandlers){
        _registeredNotificationHandlers = YES;
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(windowDidBecomeMainNotification:) name:NSWindowDidBecomeMainNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(windowDidResignMainNotification:) name:NSWindowDidResignMainNotification object:nil];
    }
}

- (void)setCameraWindowController:(SXIOCameraWindowController *)cameraWindowController
{
    if (cameraWindowController != _cameraWindowController){
        
        // can't set these up in IB so do it in code
        if (_cameraWindowController){
            [self.contrastStretchSlider unbind:@"objectLoValue"];
            [self.contrastStretchSlider unbind:@"objectHiValue"];
        }
        _cameraWindowController = cameraWindowController;
        if (_cameraWindowController){
            [self.contrastStretchSlider bind:@"objectLoValue" toObject:_cameraWindowController withKeyPath:@"exposureView.stretchMin" options:nil];
            [self.contrastStretchSlider bind:@"objectHiValue" toObject:_cameraWindowController withKeyPath:@"exposureView.stretchMax" options:nil];
        }
    }
}

- (NSString*)blackDisplayValue
{
    return self.cameraWindowController ? [NSString stringWithFormat:@"%d",(int)floor(self.cameraWindowController.exposureView.stretchMin * 65535)] : @"";
}

+ (NSSet*)keyPathsForValuesAffectingBlackDisplayValue
{
    return [NSSet setWithObject:@"cameraWindowController.exposureView.stretchMin"];
}

- (NSString*)whiteDisplayValue
{
    return self.cameraWindowController ? [NSString stringWithFormat:@"%d",(int)floor(self.cameraWindowController.exposureView.stretchMax * 65535)] : @"";
}

+ (NSSet*)keyPathsForValuesAffectingWhiteDisplayValue
{
    return [NSSet setWithObject:@"cameraWindowController.exposureView.stretchMax"];
}

- (NSString*)gammaDisplayValue
{
    return self.cameraWindowController ? [NSString stringWithFormat:@"%.2f",self.cameraWindowController.exposureView.stretchGamma] : @"";
}

+ (NSSet*)keyPathsForValuesAffectingGammaDisplayValue
{
    return [NSSet setWithObject:@"cameraWindowController.exposureView.stretchGamma"];
}

- (void)windowDidBecomeMainNotification:(NSNotification*)notification
{
    [self windowDidBecomeMain:(NSWindow*)[notification object]];
}

- (void)windowDidBecomeMain:(NSWindow*)window
{
    SXIOCameraWindowController* cameraWindow = (SXIOCameraWindowController*)window.windowController;
    if ([cameraWindow isKindOfClass:[SXIOCameraWindowController class]]){
        self.cameraWindowController = cameraWindow;
    }
    else{
        self.cameraWindowController = nil;
    }
}

- (void)windowDidResignMainNotification:(NSNotification*)notification
{
    [self windowDidResignMain:(NSWindow*)[notification object]];
}

- (void)windowDidResignMain:(NSWindow*)window
{
    SXIOCameraWindowController* cameraWindow = (SXIOCameraWindowController*)window.windowController;
    if ([cameraWindow isKindOfClass:[SXIOCameraWindowController class]]){
        self.cameraWindowController = nil;
    }
}

@end

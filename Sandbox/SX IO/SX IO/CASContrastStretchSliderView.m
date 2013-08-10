//
//  CASContrastStretchSliderView.m
//  SX IO
//
//  Created by Simon Taylor on 8/10/13.
//  Copyright (c) 2013 Simon Taylor. All rights reserved.
//

#import "CASContrastStretchSliderView.h"
#import "SMDoubleSlider.h"
#import "SXIOCameraWindowController.h"

@implementation CASContrastStretchSliderView

- (void)viewWillMoveToWindow:(NSWindow *)newWindow;
{
    SXIOCameraWindowController* controller = [NSApplication sharedApplication].keyWindow.windowController;
    self.controller = [controller isKindOfClass:[SXIOCameraWindowController class]] ? controller : nil;
}

- (void)viewDidMoveToWindow
{
    if (self.window && self.controller){
        
        self.slider.floatLoValue = self.controller.exposureView.stretchMin;
        self.slider.floatHiValue = self.controller.exposureView.stretchMax;
        
        self.slider.target = self;
        self.slider.action = @selector(sliderChanged:);
        self.slider.enabled = YES;
        
        self.checkbox.target = self;
        self.checkbox.action = @selector(checkboxChanged:);
        self.checkbox.enabled = YES;
    }
    else {
        
        self.slider.floatLoValue = 0;
        self.slider.floatHiValue = 1;
        
        self.slider.target = nil;
        self.slider.action = nil;
        self.slider.enabled = NO;
        
        self.checkbox.target = nil;
        self.checkbox.action = nil;
        self.checkbox.enabled = NO;
    }
}

- (void)sliderChanged:sender
{
    if (self.controller){
        self.controller.exposureView.stretchMin = self.slider.floatLoValue;
        self.controller.exposureView.stretchMax = self.slider.floatHiValue;
    }
}

- (void)checkboxChanged:sender
{
    const BOOL contrastStretch = self.checkbox.intValue != 0;
    self.controller.exposureView.contrastStretch = self.slider.enabled = contrastStretch;
}

@end

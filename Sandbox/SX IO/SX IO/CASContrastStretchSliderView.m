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

@interface CASContrastStretchSliderView ()
@end

@implementation CASContrastStretchSliderView

static void* kvoContext;

- (void)viewWillMoveToWindow:(NSWindow *)newWindow
{
    // grab the frontmost camera window as we're about to be displayed
    SXIOCameraWindowController* controller = [NSApplication sharedApplication].keyWindow.windowController;
    self.controller = [controller isKindOfClass:[SXIOCameraWindowController class]] ? controller : nil;
}

- (void)viewDidMoveToWindow
{
    if (self.window && self.controller){
        
        // menu has been displayed
        [[NSUserDefaultsController sharedUserDefaultsController] addObserver:self forKeyPath:@"values.SXIOAutoContrastStretch" options:0 context:&kvoContext];
    }
    else {
        
        // menu has been dismissed
        [[NSUserDefaultsController sharedUserDefaultsController] removeObserver:self forKeyPath:@"values.SXIOAutoContrastStretch"];
    }
    
    [self syncControls];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if (context == &kvoContext) {
        [self syncControls];
    } else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

- (void)sliderChanged:sender
{
    if (self.controller){
        self.controller.exposureView.stretchMin = self.slider.floatLoValue;
        self.controller.exposureView.stretchMax = self.slider.floatHiValue;
        self.controller.exposureView.stretchGamma = self.gammaSlider.floatValue;
        [self updateLabels];
    }
}

- (void)checkboxChanged:sender
{
    if (self.controller){
        const BOOL contrastStretch = self.checkbox.intValue != 0;
        self.controller.exposureView.contrastStretch = self.slider.enabled = self.gammaSlider.enabled = contrastStretch;
    }
}

- (void)syncControls
{
    if (self.window && self.controller){
        
        self.slider.floatLoValue = self.controller.exposureView.stretchMin;
        self.slider.floatHiValue = self.controller.exposureView.stretchMax;
        self.gammaSlider.floatValue = self.controller.exposureView.stretchGamma;

        self.slider.target = self;
        self.slider.action = @selector(sliderChanged:);
        self.slider.enabled = self.controller.exposureView.contrastStretch;
        
        self.gammaSlider.target = self;
        self.gammaSlider.action = @selector(sliderChanged:);
        self.gammaSlider.enabled = self.controller.exposureView.contrastStretch;

        self.checkbox.target = self;
        self.checkbox.action = @selector(checkboxChanged:);
        self.checkbox.enabled = self.controller.exposureView.contrastStretch;
        
        if ([[NSUserDefaults standardUserDefaults] boolForKey:@"SXIOAutoContrastStretch"]){
            self.checkbox.enabled = self.slider.enabled = NO;
            self.checkbox.integerValue = 1;
        }
        
        [self updateLabels];
    }
    else {
        
        self.slider.floatLoValue = 0;
        self.slider.floatHiValue = 1;
        
        self.slider.target = nil;
        self.slider.action = nil;
        self.slider.enabled = NO;
        
        self.gammaSlider.target = nil;
        self.gammaSlider.action = nil;
        self.gammaSlider.enabled = NO;

        self.checkbox.target = nil;
        self.checkbox.action = nil;
        self.checkbox.enabled = NO;
    }
}

- (void)updateLabels
{
    if (self.window && self.controller){
        self.blackLabel.stringValue = [NSString stringWithFormat:@"%d",(int)floor(self.slider.floatLoValue * 65535)]; // actually current image max value
        self.whiteLabel.stringValue = [NSString stringWithFormat:@"%d",(int)floor(self.slider.floatHiValue * 65535)];
        self.gammaLabel.stringValue = [NSString stringWithFormat:@"%.2f",self.gammaSlider.floatValue];
    }
    else{
        self.whiteLabel.stringValue = self.blackLabel.stringValue = self.gammaLabel.stringValue = @"";
    }
}

@end

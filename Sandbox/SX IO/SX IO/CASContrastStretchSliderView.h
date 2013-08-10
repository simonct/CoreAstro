//
//  CASContrastStretchSliderView.h
//  SX IO
//
//  Created by Simon Taylor on 8/10/13.
//  Copyright (c) 2013 Simon Taylor. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class SMDoubleSlider;
@class SXIOCameraWindowController;

@interface CASContrastStretchSliderView : NSView
@property (nonatomic,weak) IBOutlet NSButton* checkbox;
@property (nonatomic,weak) IBOutlet SMDoubleSlider* slider;
@property (nonatomic,unsafe_unretained) SXIOCameraWindowController* controller; // weak to NSWindowController not supported on < 10.8
@end


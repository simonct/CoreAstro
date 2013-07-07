//
//  MKOContentView.m
//  scrollview-test
//
//  Created by Simon Taylor on 10/6/12.
//  Copyright (c) 2012 Simon Taylor. All rights reserved.
//

#import "CASZoomableView.h"
#import "CASCenteringClipView.h"

@implementation CASZoomableView

- (void)awakeFromNib
{
    [super awakeFromNib];
    [CASCenteringClipView replaceClipViewInScrollView:self.enclosingScrollView];
}

- (CGRect) unitFrame
{
    return CGRectZero;
}

- (NSView*) containerView
{
    return self.enclosingScrollView.superview;
}

- (void)viewDidMoveToSuperview
{
    if (self.superview){
        self.enclosingScrollView.contentView.backgroundColor = [NSColor lightGrayColor];
    }
}

- (void)setFrame:(NSRect)frameRect
{
    [super setFrame:NSIntegralRect(frameRect)];
}

// from https://developer.apple.com/library/mac/#qa/qa2004/qa1346.html
static const NSSize unitSize = {1.0, 1.0};

// Returns the scale of the receiver's coordinate system, relative to the window's base coordinate system.
- (CGFloat)zoom
{
    return [self convertSize:unitSize toView:nil].width;
}

// Sets the scale in absolute terms.
- (void)setZoom:(CGFloat)newZoom
{
    if (newZoom != self.zoom){
        
        [self resetScaling]; // First, match our scaling to the window's coordinate system
        [self scaleUnitSquareToSize:CGSizeMake(newZoom, newZoom)]; // Then, set the scale.
        
        CGRect frame = self.unitFrame;
        if (CGRectIsEmpty(frame)){
            [self setNeedsDisplay:YES]; // Finally, mark the view as needing to be redrawn
        }
        else {
            frame.size.width *= newZoom;
            frame.size.height *= newZoom;
            self.frame = frame;
        }
    }
}

// Makes the scaling of the receiver equal to the window's base coordinate system.
- (void)resetScaling;
{
    [self scaleUnitSquareToSize:[self convertSize:unitSize fromView:nil]];
}

#define ZOOM_IN_FACTOR  1.414214
#define ZOOM_OUT_FACTOR 1/ZOOM_IN_FACTOR

- (IBAction)zoomIn:(id)sender
{
    self.zoom = self.zoom * ZOOM_IN_FACTOR;

    // todo; keep centred
}

- (IBAction)zoomOut:(id)sender
{
    self.zoom = self.zoom / ZOOM_OUT_FACTOR;
    
    // todo; keep centred
}

- (IBAction)zoomImageToFit:(id)sender
{
    const CGRect unitFrame = self.unitFrame;
    if (unitFrame.size.width == 0 || unitFrame.size.height == 0){
        return;
    }
    
    const CGRect containerFrame = self.containerView.frame;
    
    const CGFloat unitAspect = unitFrame.size.width/unitFrame.size.height;
    const CGFloat containerAspect = containerFrame.size.width/containerFrame.size.height;
    
    if (unitAspect > containerAspect){
        self.zoom = containerFrame.size.width/unitFrame.size.width;
    }
    else {
        self.zoom = containerFrame.size.height/unitFrame.size.height;
    }
}

- (IBAction)zoomImageToActualSize:(id)sender
{
    self.zoom = 1;
}

- (void)magnifyWithEvent:(NSEvent *)event
{
    self.zoom += event.magnification;
}

- (void)smartMagnifyWithEvent:(NSEvent *)event
{
    [self zoomImageToFit:nil];
}

@end

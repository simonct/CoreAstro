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

//- (BOOL)translatesAutoresizingMaskIntoConstraints
//{
//    return NO;
//}

- (CGRect) unitFrame
{
    return CGRectZero;
}

- (void)viewDidMoveToSuperview
{
    if (self.superview){
        self.enclosingScrollView.contentView.backgroundColor = [NSColor darkGrayColor];
    }
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


- (IBAction)zoomIn:(id)sender
{
    self.zoom = self.zoom * 2;

    // todo; keep centred
}

- (IBAction)zoomOut:(id)sender
{
    self.zoom = self.zoom / 2;
    
    // todo; keep centred
}

- (IBAction)zoomImageToFit:(id)sender
{
    NSLog(@"zoomImageToFit: not implemented");
}

- (IBAction)zoomImageToActualSize:(id)sender
{
    NSLog(@"zoomImageToActualSize: not implemented");
}

- (void)resetContents
{
//    [(CASCenteringClipView*)self.enclosingScrollView.contentView resetClipView];
//    [self scaleUnitSquareToSize:NSMakeSize(1, 1)];
}

@end

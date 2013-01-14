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

- (void)viewDidMoveToSuperview
{
    if (self.superview){
        self.enclosingScrollView.contentView.backgroundColor = [NSColor darkGrayColor];
    }
}

- (IBAction)zoomIn:(id)sender
{
    [self scaleUnitSquareToSize:NSMakeSize(2, 2)];
        
    CGRect frame = self.frame;
    frame.size.width *= 2;
    frame.size.height *= 2;
    self.frame = frame;

    // todo; keep centred
}

- (IBAction)zoomOut:(id)sender
{
    [self scaleUnitSquareToSize:NSMakeSize(0.5, 0.5)];

    CGRect frame = self.frame;
    frame.size.width /= 2;
    frame.size.height /= 2;
    self.frame = frame;
    
    // CGRectInset...
    
    // todo; keep centred
}

- (void)resetContents
{
    [(CASCenteringClipView*)self.enclosingScrollView.contentView resetClipView];
    [self scaleUnitSquareToSize:NSMakeSize(1, 1)];
}

@end

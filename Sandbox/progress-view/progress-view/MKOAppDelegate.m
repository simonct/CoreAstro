//
//  MKOAppDelegate.m
//  progress-view
//
//  Created by Simon Taylor on 11/21/12.
//  Copyright (c) 2012 Simon Taylor. All rights reserved.
//

#import "MKOAppDelegate.h"

@interface CASProgressView : NSView
@property (nonatomic,assign) CGFloat progress;
@end

@implementation CASProgressView

- (void)drawRect:(NSRect)dirtyRect
{
    NSRect bounds = CGRectInset(self.bounds, 5, 5);
    
    NSBezierPath* outline = [NSBezierPath bezierPathWithOvalInRect:bounds];
    outline.lineWidth = 5;
    [[NSColor whiteColor] set];
    [outline stroke];
    
    NSBezierPath* arc = [NSBezierPath bezierPath];
    arc.lineWidth = 5;
    [arc moveToPoint:CGPointMake(CGRectGetMidX(bounds), CGRectGetMidY(bounds))];
    [arc appendBezierPathWithArcWithCenter:CGPointMake(CGRectGetMidX(bounds), CGRectGetMidY(bounds))
                                    radius:CGRectGetWidth(bounds)/2
                                startAngle:90
                                  endAngle:90 - (360*self.progress)
                                 clockwise:YES];
    [arc moveToPoint:CGPointMake(CGRectGetMidX(bounds), CGRectGetMidY(bounds))];
    [[NSColor whiteColor] set];
    [arc fill];
}

- (void)setProgress:(CGFloat)progress
{
    if (_progress != progress){
        _progress = progress;
        [self setNeedsDisplay:YES];
    }
}

@end

@interface MKOAppDelegate ()
@property (nonatomic,assign) CGFloat progress;
@end

@implementation MKOAppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    self.progressView.progress = 0;
}

- (void)setProgress:(CGFloat)progress
{
    self.progressView.progress = progress;
}

- (CGFloat)progress
{
    return self.progressView.progress;
}

@end

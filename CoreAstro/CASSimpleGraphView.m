//
//  CASSimpleGraphView.m
//  CoreAstro
//
//  Created by Simon Taylor on 12/18/12.
//  Copyright (c) 2012 Mako Technology Ltd. All rights reserved.
//

#import "CASSimpleGraphView.h"

@implementation CASSimpleGraphView

- (id)initWithFrame:(NSRect)frameRect
{
    self = [super initWithFrame:frameRect];
    if (self) {
        self.max = 1.0;
    }
    return self;
}

- (void)awakeFromNib
{
    self.max = 1.0;
}

- (void)drawSamples:(NSData*)samples
{
    float* pixels = (float*)[self.samples bytes];
    const NSInteger count = [self.samples length]/sizeof(float);
    if (count > 0 && _max != 0){
        
        const CGFloat pixelsPerSample = self.bounds.size.width / count;
        
        NSBezierPath* path = [NSBezierPath bezierPath];
        
        for (NSInteger i = 0; i < count; ++i){
            const NSPoint p = NSMakePoint(pixelsPerSample * i, (self.bounds.size.height*pixels[i]/_max));
            if (i == 0){
                [path moveToPoint:p];
            }
            else {
                [path lineToPoint:p];
            }
        }
        
        [[NSColor orangeColor] set];
        [path setLineWidth:1.5];
        [path stroke];
    }
}

- (void)drawRect:(NSRect)dirtyRect
{
    [[NSColor clearColor] set];
    NSRectFill(self.bounds);
 
    [self drawSamples:self.samples];

    if (self.showLimits && _max != 0){
        
        NSBezierPath* limits = [NSBezierPath bezierPath];
        [limits moveToPoint:NSMakePoint(0, _max)];
        [limits lineToPoint:NSMakePoint(self.bounds.size.width, _max)];
        [limits moveToPoint:NSMakePoint(0, self.bounds.size.height)];
        [limits lineToPoint:NSMakePoint(self.bounds.size.width, self.bounds.size.height)];
        [limits setLineWidth:1];
        CGFloat pattern[] = {2,2};
        [limits setLineDash:pattern count:2 phase:0];
        [limits stroke];
    }
}

- (void)setSamples:(NSData *)samples
{
    if (samples != _samples){
        _samples = samples;
        [self setNeedsDisplay:YES];
    }
}

- (void)setMax:(CGFloat)max
{
    if (max != _max){
        _max = max;
        [self setNeedsDisplay:YES];
    }
}

@end

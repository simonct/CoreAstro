//
//  CASProgressHUDView.m
//  CoreAstro
//
//  Created by Simon Taylor on 12/18/12.
//  Copyright (c) 2012 Mako Technology Ltd. All rights reserved.
//

#import "CASProgressHUDView.h"

@interface CASCircularProgressIndicatorView : NSView
@property (nonatomic,assign) CGFloat progress;
@end

@implementation CASCircularProgressIndicatorView

- (void)drawRect:(NSRect)dirtyRect
{
    @try {
        NSRect bounds = CGRectInset(self.bounds, 5, 5);
        
        NSBezierPath* outline = [NSBezierPath bezierPathWithOvalInRect:bounds];
        outline.lineWidth = 2.5;
        [[NSColor whiteColor] set];
        [outline stroke];
        
        NSBezierPath* arc = [NSBezierPath bezierPath];
        arc.lineWidth = 2.5;
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
    @catch (NSException *exception) {
        NSLog(@"%@: %@",NSStringFromSelector(_cmd),exception);
    }
}

- (void)setProgress:(CGFloat)progress
{
    if (_progress != progress){
        _progress = MAX(0,MIN(progress,1));
        [self setNeedsDisplay:YES];
    }
}

@end

@interface CASProgressHUDView ()
@property (nonatomic,weak) CASCircularProgressIndicatorView* progressView;
@end

@implementation CASProgressHUDView

- (id)initWithFrame:(NSRect)frameRect
{
    self = [super initWithFrame:frameRect];
    if (self){
        
        NSTextField* label = [[NSTextField alloc] initWithFrame:CGRectZero]; // strong local as property is weak
        label.autoresizingMask = NSViewWidthSizable|NSViewHeightSizable;
        label.backgroundColor = [NSColor clearColor];
        label.bordered = NO;
        label.textColor = [NSColor whiteColor];
        label.font = [NSFont boldSystemFontOfSize:18];
        label.alignment = NSCenterTextAlignment;
        label.editable = NO;
        [self addSubview:label];
        self.label = label;
        
        CASCircularProgressIndicatorView* progressView = [[CASCircularProgressIndicatorView alloc] initWithFrame:CGRectZero];
        progressView.autoresizingMask = NSViewMaxXMargin;
        [self addSubview:progressView];
        self.progressView = progressView;
    }
    return self;
}

- (void)setFrame:(NSRect)frameRect
{
    [super setFrame:frameRect];
    
    CGRect bounds = CGRectInset(self.bounds, 3, 3);
    
    const CGFloat height = 40;
    
    self.label.frame = CGRectMake(10 + height, CGRectGetMidY(self.bounds)-height/2-8, bounds.size.width - height, height);
    self.progressView.frame = CGRectMake(10, CGRectGetMidY(self.bounds)-height/2, height, height);
}

- (CGFloat)progress
{
    return self.progressView.progress;
}

- (void)setProgress:(CGFloat)progress
{
    self.progressView.progress = progress;
}

@end

//
//  CASShadowView.m
//  CoreAstro
//
//  Created by Simon Taylor on 10/25/12.
//  Copyright (c) 2012 Mako Technology Ltd. All rights reserved.
//

#import "CASShadowView.h"
#import <QuartzCore/QuartzCore.h>

@implementation CASShadowView

- (id)initWithFrame:(NSRect)frameRect
{
    self = [super initWithFrame:frameRect];
    if (self) {
        CAGradientLayer* layer = [CAGradientLayer layer];
        layer.colors = [NSArray arrayWithObjects:(__bridge id)CGColorCreateGenericGray(0,0),CGColorCreateGenericGray(0,0.5),nil];
        if (CGRectGetWidth(frameRect) > CGRectGetHeight(frameRect)){
            layer.startPoint = CGPointMake(0.5, 0);
            layer.endPoint = CGPointMake(0.5, 1);
        }
        else {
            layer.startPoint = CGPointMake(0, 0.5);
            layer.endPoint = CGPointMake(1, 0.5);
        }
        layer.startPoint = CGPointMake(0, 0.5);
        layer.endPoint = CGPointMake(1, 0.5);
        self.layer = layer;
        self.wantsLayer = YES;
    }
    return self;
}

- (BOOL)translatesAutoresizingMaskIntoConstraints
{
    return NO;
}

+ (void)attachToView:(NSView*)view // todo; edge param
{
    NSParameterAssert(view);
    CASShadowView* shadow = [[CASShadowView alloc] initWithFrame:CGRectMake(0, 0, 7, CGRectGetHeight(view.frame))];
    shadow.frame = CGRectMake(0, 0, 10, view.frame.size.height);
    [view.superview addSubview:shadow];
    [view.superview addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"[shadow(==7)]-0-[view]" options:NSLayoutFormatAlignAllTop metrics:nil views:NSDictionaryOfVariableBindings(shadow,view)]];
    [view.superview addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:[shadow(==view)]" options:NSLayoutFormatAlignAllTop metrics:nil views:NSDictionaryOfVariableBindings(shadow,view)]];
}

@end

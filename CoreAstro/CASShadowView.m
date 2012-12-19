//
//  CASShadowView.m
//  CoreAstro
//
//  Created by Simon Taylor on 10/25/12.
//  Copyright (c) 2012 Mako Technology Ltd. All rights reserved.
//

#import "CASShadowView.h"
#import <QuartzCore/QuartzCore.h>

@implementation CASShadowView {
    NSRectEdge _edge;
}

- (id)initWithFrame:(NSRect)frameRect edge:(NSRectEdge)edge
{
    self = [super initWithFrame:frameRect];
    if (self) {
        _edge = edge;
        CAGradientLayer* layer = [CAGradientLayer layer];
        if (_edge == NSMinXEdge){
            layer.colors = [NSArray arrayWithObjects:CFBridgingRelease(CGColorCreateGenericGray(0,0)),CFBridgingRelease(CGColorCreateGenericGray(0,0.5)),nil];
        }
        else {
            layer.colors = [NSArray arrayWithObjects:CFBridgingRelease(CGColorCreateGenericGray(0,0.5)),CFBridgingRelease(CGColorCreateGenericGray(0,0)),nil];
        }
        if (CGRectGetWidth(frameRect) > CGRectGetHeight(frameRect)){
            layer.startPoint = CGPointMake(0.5, 0);
            layer.endPoint = CGPointMake(0.5, 1);
        }
        else {
            layer.startPoint = CGPointMake(0, 0.5);
            layer.endPoint = CGPointMake(1, 0.5);
        }
        self.layer = layer;
        self.wantsLayer = YES;
    }
    return self;
}

- (BOOL)translatesAutoresizingMaskIntoConstraints
{
    return NO;
}

+ (void)attachToView:(NSView*)view edge:(NSRectEdge)edge
{
    NSParameterAssert(view);
    
    CASShadowView* shadow = [[CASShadowView alloc] initWithFrame:CGRectMake(0, 0, 7, CGRectGetHeight(view.frame)) edge:edge];
    
    if (edge == NSMinXEdge){
        
        shadow.frame = CGRectMake(0, 0, 10, view.frame.size.height);
        [view.superview addSubview:shadow];
        [view.superview addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"[shadow(==7)]-0-[view]" options:NSLayoutFormatAlignAllTop metrics:nil views:NSDictionaryOfVariableBindings(shadow,view)]];
        [view.superview addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:[shadow(==view)]" options:NSLayoutFormatAlignAllTop metrics:nil views:NSDictionaryOfVariableBindings(shadow,view)]];
    }
    else if (edge == NSMaxXEdge){
        
        shadow.frame = CGRectMake(CGRectGetMaxX(view.frame), 0, 10, view.frame.size.height);
        [view.superview addSubview:shadow];
        [view.superview addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"[view]-0-[shadow(==7)]" options:NSLayoutFormatAlignAllTop metrics:nil views:NSDictionaryOfVariableBindings(shadow,view)]];
        [view.superview addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:[shadow(==view)]" options:NSLayoutFormatAlignAllTop metrics:nil views:NSDictionaryOfVariableBindings(shadow,view)]];
    }
}

@end

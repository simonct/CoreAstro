//
//  CASImageView.m
//  CoreAstro
//
//  Created by Simon Taylor on 9/22/12.
//  Copyright (c) 2012 Mako Technology Ltd. All rights reserved.
//

#import "CASImageView.h"

const CGPoint kCASImageViewInvalidStarLocation = {-1,-1};

@interface IKImageView (Private)
- (CGRect)selectionRect; // great, a private method to get the selection...
@end

@interface CASImageView ()
@property (nonatomic,assign) BOOL firstShowEditPanel;
@property (nonatomic,retain) CALayer* starLayer;
@end

@implementation CASImageView

- (id)init
{
    self = [super init];
    if (self) {
        self.starLocation = kCASImageViewInvalidStarLocation;
    }
    return self;
}

- (BOOL)hasEffectsMode
{
    return NO;
}

//- (BOOL)acceptsFirstResponder
//{
//    return NO;
//}

//- (void)mouseUp:(NSEvent *)theEvent
//{
//    if (theEvent.clickCount == 2){
//        [IKImageEditPanel sharedImageEditPanel].dataSource = (id<IKImageEditPanelDataSource>)self;
//        if (!self.firstShowEditPanel){
//            self.firstShowEditPanel = YES;
//            const NSRect frame = [IKImageEditPanel sharedImageEditPanel].frame;
//            const NSRect windowFrame = self.window.frame;
//            [[IKImageEditPanel sharedImageEditPanel] setFrameOrigin:NSMakePoint(NSMinX(windowFrame) + NSWidth(windowFrame)/2 - NSWidth(frame)/2, NSMinY(windowFrame) + NSHeight(windowFrame)/2 - NSHeight(frame)/2)];
//        }
//        [[IKImageEditPanel sharedImageEditPanel] makeKeyAndOrderFront:nil];
//        [[IKImageEditPanel sharedImageEditPanel] setHidesOnDeactivate:YES];
//    }
//}

- (CGRect)selectionRect
{
    return [super selectionRect];
}

- (void)setStarLocation:(CGPoint)starLocation
{
    _starLocation = starLocation;
    
    if (CGPointEqualToPoint(_starLocation, kCASImageViewInvalidStarLocation)){
        self.starLayer = nil;
    }
    else {
        self.starLayer = [self circularRegionLayerWithPosition:self.starLocation radius:15];
    }
}

- (void)setImage:(CGImageRef)image imageProperties:(NSDictionary *)metaData
{
    [super setImage:image imageProperties:metaData];
    
    self.starLocation = kCASImageViewInvalidStarLocation;
}

- (void)setStarLayer:(CALayer *)starLayer
{
    if (starLayer != _starLayer){
        if (_starLayer){
            [_starLayer removeFromSuperlayer];
        }
        _starLayer = starLayer;
        if (_starLayer){
            [self.imageOverlayLayer addSublayer:_starLayer];
        }
    }
}

- (CALayer*)imageOverlayLayer
{
    CALayer* layer = [self overlayForType:IKOverlayTypeImage];
    if (!layer){
        layer = [CALayer layer];
        layer.backgroundColor = CGColorCreateGenericRGB(1,1,1,0);
        layer.opacity = 0.75;
        [self setOverlay:layer forType:IKOverlayTypeImage];
    }
    return layer;
}

- (CALayer*)circularRegionLayerWithPosition:(CGPoint)position radius:(CGFloat)radius
{
    CALayer* layer = [CALayer layer];
    
    layer.borderColor = CGColorCreateGenericRGB(1,1,0,1);
    layer.borderWidth = 2.5;
    layer.cornerRadius = radius;
    layer.bounds = CGRectMake(0, 0, 2*radius, 2*radius);
    layer.position = position;
    layer.masksToBounds = NO;
    
    return layer;
}

@end

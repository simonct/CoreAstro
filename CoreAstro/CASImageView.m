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
@property (nonatomic,retain) CALayer* lockLayer;
@property (nonatomic,retain) CALayer* searchLayer;
@property (nonatomic,retain) CAShapeLayer* reticleLayer;
@end

@implementation CASImageView

//@synthesize reticleLayer = _reticleLayer;

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

- (void)setImage:(CGImageRef)image imageProperties:(NSDictionary *)metaData
{
    self.searchLayer = nil;
    self.reticleLayer = nil;

    [super setImage:image imageProperties:metaData];
    
    self.starLocation = kCASImageViewInvalidStarLocation;
    
    if (self.showReticle){
        self.reticleLayer = [self createReticleLayer];
    }
}

- (void)setStarLocation:(CGPoint)starLocation
{
    _starLocation = starLocation;
    
    if (CGPointEqualToPoint(_starLocation, kCASImageViewInvalidStarLocation)){
        self.starLayer = nil;
    }
    else {
        self.starLayer = [self circularRegionLayerWithPosition:self.starLocation radius:15 colour:CGColorCreateGenericRGB(1,1,0,1)];
    }
}

- (void)setLockLocation:(CGPoint)lockLocation
{
    _lockLocation = lockLocation;
    
    if (CGPointEqualToPoint(_starLocation, kCASImageViewInvalidStarLocation)){
        self.lockLayer = nil;
    }
    else {
        self.lockLayer = [self circularRegionLayerWithPosition:self.lockLocation radius:15 colour:CGColorCreateGenericRGB(1,0,0,1)];
    }
}

- (void)setSearchRadius:(CGFloat)searchRadius
{
    self.searchLayer = [self circularRegionLayerWithPosition:self.starLocation radius:searchRadius colour:CGColorCreateGenericRGB(0,0,1,1)];
}

- (void)setShowReticle:(BOOL)showReticle
{
    _showReticle = showReticle;
    
    if (_showReticle){
        self.reticleLayer = [self createReticleLayer];
    }
    else {
        self.reticleLayer = nil;
    }
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

- (void)setLockLayer:(CALayer *)lockLayer
{
    if (lockLayer != _lockLayer){
        if (_lockLayer){
            [_lockLayer removeFromSuperlayer];
        }
        _lockLayer = lockLayer;
        if (_lockLayer){
            [self.imageOverlayLayer addSublayer:_lockLayer];
        }
    }
}

- (void)setSearchLayer:(CALayer *)searchLayer
{
    if (searchLayer != _searchLayer){
        if (_searchLayer){
            [_searchLayer removeFromSuperlayer];
        }
        _searchLayer = searchLayer;
        if (_searchLayer){
            [self.imageOverlayLayer addSublayer:_searchLayer];
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

- (CALayer*)circularRegionLayerWithPosition:(CGPoint)position radius:(CGFloat)radius colour:(CGColorRef)colour
{
    CALayer* layer = [CALayer layer];
    
    layer.borderColor = colour;
    layer.borderWidth = 2.5;
    layer.cornerRadius = radius;
    layer.bounds = CGRectMake(0, 0, 2*radius, 2*radius);
    layer.position = position;
    layer.masksToBounds = NO;
    
    return layer;
}

- (CAShapeLayer*)createReticleLayer
{
    CAShapeLayer* reticleLayer = [CAShapeLayer layer];
    
    CGMutablePathRef path = CGPathCreateMutable();
    
    const CGFloat width = 0.5;
    CGPathAddRect(path, nil, CGRectMake(0, CGImageGetHeight(self.image)/2.0, CGImageGetWidth(self.image), width));
    CGPathAddRect(path, nil, CGRectMake(CGImageGetWidth(self.image)/2.0, 0, width, CGImageGetHeight(self.image)));
    
    reticleLayer.path = path;
    reticleLayer.strokeColor = CGColorCreateGenericRGB(1,0,0,1);
    reticleLayer.borderWidth = width;
    
    return reticleLayer;
}

- (void)setReticleLayer:(CAShapeLayer *)reticleLayer
{
    if (_reticleLayer != reticleLayer){
        if (_reticleLayer){
            [_reticleLayer removeFromSuperlayer];
        }
        _reticleLayer = reticleLayer;
        if (_reticleLayer){
            [self.imageOverlayLayer addSublayer:_reticleLayer];
        }
    }
}

@end

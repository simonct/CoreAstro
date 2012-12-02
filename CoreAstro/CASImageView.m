//
//  CASImageView.m
//  CoreAstro
//
//  Created by Simon Taylor on 9/22/12.
//  Copyright (c) 2012 Mako Technology Ltd. All rights reserved.
//

#import "CASImageView.h"

const CGPoint kCASImageViewInvalidStarLocation = {-1,-1};

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

@interface IKImageView (Private)
- (CGRect)selectionRect; // great, a private method to get the selection...
@end

@interface CASImageView ()
@property (nonatomic,assign) BOOL firstShowEditPanel;
@property (nonatomic,strong) CALayer* starLayer;
@property (nonatomic,strong) CALayer* lockLayer;
@property (nonatomic,strong) CALayer* searchLayer;
@property (nonatomic,strong) CAShapeLayer* reticleLayer;
@property (nonatomic,strong) CASProgressView* progressView;
@property (nonatomic,strong) NSTrackingArea* trackingArea;
@property (nonatomic,assign) CGFloat rotationAngle, zoomFactor;
@end

@implementation CASImageView {
    BOOL _zoomToFit:1;
    BOOL _zoomToActual:1;
}

- (void)awakeFromNib
{
    self.zoomFactor = 1;
    self.starLocation = kCASImageViewInvalidStarLocation;
}

- (BOOL)hasEffectsMode
{
    return NO;
}

- (void)disableAnimations:(void(^)(void))block {
    const BOOL disableActions = [CATransaction disableActions];
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    if (block){
        block();
    }
    [CATransaction commit];
    [CATransaction setDisableActions:disableActions];
}

- (void)setFrame:(NSRect)frameRect
{
    if (self.trackingArea){
        [self removeTrackingArea:self.trackingArea];
        self.trackingArea = nil;
    }
    
    [super setFrame:frameRect];
    
    self.trackingArea = [[NSTrackingArea alloc] initWithRect:frameRect options:NSTrackingActiveInActiveApp|NSTrackingMouseEnteredAndExited|NSTrackingMouseMoved owner:self userInfo:nil];
    [self addTrackingArea:self.trackingArea];
}

- (void)mouseMoved:(NSEvent *)theEvent
{
    NSPoint p = [self convertPoint:[theEvent locationInWindow] fromView:nil];
    p = [self convertViewPointToImagePoint:p];
   // NSLog(@"mouseMoved: %@",NSStringFromPoint(p));

    if (self.image){
        // check point in rect
        if (NSPointInRect(p, CGRectMake(0, 0, CGImageGetWidth(self.image), CGImageGetHeight(self.image)))){
            // convert to image co-ords
            // get pixel values
        }
    }
}

- (CGRect)selectionRect
{
    return [super selectionRect];
}

- (void)setImage:(CGImageRef)image imageProperties:(NSDictionary *)metaData
{
    self.searchLayer = nil;
    self.reticleLayer = nil;

    [self disableAnimations:^{
        
        // flashes when updated, hide and then show again ? draw the new image into the old image ?...
        [super setImage:image imageProperties:metaData];
        
        if (image){
            
            if (_zoomToFit){
                [self zoomImageToFit:nil];
            }
            else if (_zoomToActual){
                [self zoomImageToActualSize:nil];
            }
            else {
                [self setZoomFactor:self.zoomFactor];
            }
            
            if (self.rotationAngle){
                const CGSize size = CGSizeMake(CGImageGetWidth(image), CGImageGetHeight(image));
                const NSPoint centre = NSMakePoint(size.width/2,size.height/2);
                [self setRotationAngle:self.rotationAngle centerPoint:centre];
            }
        }
    }];
    
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

#define ZOOM_IN_FACTOR  1.414214
#define ZOOM_OUT_FACTOR 0.7071068

- (IBAction)zoomIn:(id)sender
{
    _zoomToFit = _zoomToActual = NO;
    self.zoomFactor = self.zoomFactor * ZOOM_IN_FACTOR;
    self.zoomFactor = self.zoomFactor;
}

- (IBAction)zoomOut:(id)sender
{
    _zoomToFit = _zoomToActual = NO;
    self.zoomFactor = self.zoomFactor * ZOOM_OUT_FACTOR;
    self.zoomFactor = self.zoomFactor;
}

- (IBAction)zoomImageToFit: (id)sender
{
    _zoomToFit = YES;
    _zoomToActual = NO;
    [super zoomImageToFit:sender];
}

- (IBAction)zoomImageToActualSize: (id)sender
{
    _zoomToFit = NO;
    _zoomToActual = YES;
    [super zoomImageToActualSize:sender];
}

- (void)flipImageHorizontal:sender
{
    [self flipImageHorizontal:sender];
}

- (void)flipImageVertical:sender
{
    [self flipImageVertical:sender];
}

- (void)rotateImageLeft:sender
{
    [self rotateImageLeft:sender];
    self.rotationAngle += M_PI/2;
}

- (void)rotateImageRight:sender
{
    [self rotateImageRight:sender];
    self.rotationAngle -= M_PI/2;
}

@end

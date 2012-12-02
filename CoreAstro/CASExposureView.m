//
//  CASExposureView.m
//  CoreAstro
//
//  Created by Simon Taylor on 02/12/12.
//  Copyright (c) 2012 Mako Technology Ltd. All rights reserved.
//

#import "CASExposureView.h"
#import "CASCCDImage.h"
#import "CASCCDExposure.h"
#import "CASHistogramView.h"
#import <CoreAstro/CoreAstro.h>

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

@interface CASExposureView ()
@property (nonatomic,assign) BOOL firstShowEditPanel;
@property (nonatomic,strong) CALayer* starLayer;
@property (nonatomic,strong) CALayer* lockLayer;
@property (nonatomic,strong) CALayer* searchLayer;
@property (nonatomic,strong) CAShapeLayer* reticleLayer;
@property (nonatomic,strong) CASProgressView* progressView;
@property (nonatomic,assign) CGFloat rotationAngle, zoomFactor;
@property (nonatomic,strong) CASHistogramView* histogramView;
@end

@implementation CASExposureView

- (void)awakeFromNib
{
    [super awakeFromNib];
    self.starLocation = kCASImageViewInvalidStarLocation;
    self.histogramView = [[CASHistogramView alloc] initWithFrame:NSMakeRect(10, 10, 400, 200)];
    [self addSubview:self.histogramView];
    self.histogramView.hidden = YES;
}

- (void)mouseMoved:(NSEvent *)theEvent
{
    NSPoint p = [self convertPoint:[theEvent locationInWindow] fromView:nil];
    p = [self convertViewPointToImagePoint:p];
    NSLog(@"mouseMoved: %@",NSStringFromPoint(p));

    if (self.image){
        // check point in rect
        if (NSPointInRect(p, CGRectMake(0, 0, CGImageGetWidth(self.image), CGImageGetHeight(self.image)))){
            // convert to image co-ords
            // get pixel values
        }
    }
}

- (void)updateHistogram
{
    if (self.showHistogram){
        if (!_exposure){
            self.histogramView.histogram = nil;
        }
        else {
            self.histogramView.histogram = [self.imageProcessor histogram:_exposure];
        }
    }
}

- (void)setShowHistogram:(BOOL)showHistogram
{
    if (_showHistogram != showHistogram){
        _showHistogram = showHistogram;
        self.histogramView.hidden = !_showHistogram;
        if (_showHistogram){
            [self updateHistogram];
        }
    }
}

- (void)setExposure:(CASCCDExposure *)exposure
{
    void (^clearImage)() = ^() {
        [self setImage:nil imageProperties:nil];
        [self.histogramView removeFromSuperview];
    };
    
    // don't check for setting to the same exposure as we use this to force a refresh if external settings have changed
    _exposure = exposure;
    
    [self updateHistogram];
    
    if (!exposure){
        clearImage();
    }
    else {
        
        CASCCDImage* image = [exposure createImage];
        if (!image){
            clearImage();
        }
        else {
            
            CGImageRef CGImage = nil;
            if (/*self.debayerMode == kCASImageDebayerNone*/1){
                CGImage = image.CGImage;
            }
            else {
                //                    CGImage = [self.imageDebayer debayer:image adjustRed:self.colourAdjustments.redAdjust green:self.colourAdjustments.greenAdjust blue:self.colourAdjustments.blueAdjust all:self.colourAdjustments.allAdjust]; // note; tmp, debayering after processing which is wrong - will all be replaced with a coherent processing chain in the future
            }
            
            const CASExposeParams params = exposure.params;
            const CGRect subframe = CGRectMake(params.origin.x, params.origin.y, params.size.width, params.size.height);
            
            if (CGImage){
                
                const CGRect frame = CGRectMake(0, 0, params.size.width, params.size.height);
                if (!self.scaleSubframe && !CGRectEqualToRect(subframe, frame)){
                    
                    CGContextRef bitmap = [CASCCDImage createBitmapContextWithSize:CASSizeMake(params.frame.width, params.frame.height) bitsPerPixel:params.bps];
                    if (!bitmap){
                        CGImage = nil;
                    }
                    else {
                        CGContextSetRGBFillColor(bitmap,0.35,0.35,0.35,1);
                        CGContextFillRect(bitmap,CGRectMake(0, 0, params.frame.width, params.frame.height));
                        CGContextDrawImage(bitmap,CGRectMake(subframe.origin.x, params.frame.height - (subframe.origin.y + subframe.size.height), subframe.size.width, subframe.size.height),CGImage);
                        CGImage = CGBitmapContextCreateImage(bitmap);
                    }
                }
                
                if (CGImage){
                    
                    CGSize currentSize = CGSizeZero;
                    CGImageRef currentImage = self.image;
                    if (currentImage){
                        currentSize = CGSizeMake(CGImageGetWidth(currentImage), CGImageGetHeight(currentImage));
                    }
                    
                    const BOOL hasCurrentImage = (self.image != nil);
                    
                    // flashes when updated, hide and then show again ? draw the new image into the old image ?...
                    [self setImage:CGImage imageProperties:nil];
                    
                    // zoom to fit on the first image
                    if (!hasCurrentImage){
                        [self zoomImageToFit:nil];
                    }
                    
                    // ensure the histogram view remains at the front.
                    [self.histogramView removeFromSuperview];
                    [self addSubview:self.histogramView];
                }
            }
        }
    }
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

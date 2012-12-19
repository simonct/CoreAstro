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
#import "CASImageProcessor.h"
#import "CASExposureInfoView.h"
#import "CASProgressHUDView.h"
#import "CASStarInfoHUDView.h"
#import "CASHistogramHUDView.h"

#import <CoreAstro/CoreAstro.h>

const CGPoint kCASImageViewInvalidStarLocation = {-1,-1};

#pragma mark - Layer classes

@interface CASTaggedLayer : CALayer
@property (nonatomic,assign) NSInteger tag;
@end

@implementation CASTaggedLayer
@end

@interface CASSelectionLayer : CASTaggedLayer
- (void)dragHandle:(CASTaggedLayer*)dragHandle movedToPosition:(CGPoint)p;
@end

@implementation CASSelectionLayer

- (void)updateDragHandlePositions
{
    const CGSize size = self.bounds.size;
    
    [[[self sublayers] objectAtIndex:0] setPosition:CGPointMake(0,0)];
    [[[self sublayers] objectAtIndex:1] setPosition:CGPointMake(size.width,0)];
    [[[self sublayers] objectAtIndex:2] setPosition:CGPointMake(size.width,size.height)];
    [[[self sublayers] objectAtIndex:3] setPosition:CGPointMake(0,size.height)];
}

- (void)dragHandle:(CASTaggedLayer*)dragHandle movedToPosition:(CGPoint)p
{
    // get the current selection frame in image co-ords
    CGRect frame = self.frame;
    
    // get the original drag handle position in image co-ords
    const CGPoint originalPosition = [self convertPoint:dragHandle.position toLayer:self.superlayer];
    
    // calculate the new position
    CGPoint newPosition = p;
    
    switch (dragHandle.tag) {
            
        case 0:{
            // bottom left
            newPosition.x = MIN(newPosition.x,CGRectGetMaxX(frame));
            newPosition.y = MIN(newPosition.y,CGRectGetMaxY(frame));
            frame.origin = newPosition;
            frame.size = CGSizeMake(frame.size.width + originalPosition.x - newPosition.x,
                                    frame.size.height + originalPosition.y - newPosition.y);
        }
            break;
            
        case 1:{
            // bottom right
            newPosition.x = MAX(newPosition.x,CGRectGetMinX(frame));
            newPosition.y = MIN(newPosition.y,CGRectGetMaxY(frame));
            frame.origin.y = newPosition.y;
            frame.size = CGSizeMake(frame.size.width + newPosition.x - originalPosition.x,
                                    frame.size.height + originalPosition.y - newPosition.y);
        }
            break;
            
        case 2:{
            // top right
            newPosition.x = MAX(newPosition.x,CGRectGetMinX(frame));
            newPosition.y = MAX(newPosition.y,CGRectGetMinY(frame));
            frame.size = CGSizeMake(frame.size.width + newPosition.x - originalPosition.x,
                                    frame.size.height + newPosition.y - originalPosition.y);
        }
            break;
            
        case 3:{
            // top left
            newPosition.x = MIN(newPosition.x,CGRectGetMaxX(frame));
            newPosition.y = MAX(newPosition.y,CGRectGetMinY(frame));
            frame.origin.x = newPosition.x;
            frame.size = CGSizeMake(frame.size.width + originalPosition.x - newPosition.x,
                                    frame.size.height + newPosition.y - originalPosition.y);
        }
            break;
    }
    
    // apply the new frame and position
    dragHandle.position = [self.superlayer convertPoint:newPosition toLayer:self];
    
    self.frame = frame;
}

- (void)setFrame:(CGRect)frame
{
    [super setFrame:frame];
    
    [self updateDragHandlePositions];
}

@end

#pragma mark - Exposure view

@interface CASExposureView ()
@property (nonatomic,assign) BOOL firstShowEditPanel;
@property (nonatomic,strong) CALayer* starLayer;
@property (nonatomic,strong) CALayer* lockLayer;
@property (nonatomic,strong) CALayer* searchLayer;
@property (nonatomic,strong) CASSelectionLayer* selectionLayer;
@property (nonatomic,strong) CAShapeLayer* reticleLayer;
@property (nonatomic,assign) CGFloat rotationAngle, zoomFactor;
@property (nonatomic,strong) CASHistogramHUDView* histogramView;
@property (nonatomic,strong) CASProgressHUDView* progressView;
@property (nonatomic,strong) CASStarInfoHUDView* starInfoView;
@property (nonatomic,strong) CASExposureInfoView* exposureInfoView;
@property (nonatomic,strong) NSArray* huds;
@end

@implementation CASExposureView {
    BOOL _draggingSelection:1;
    BOOL _displayedFirstImage:1;
    CASTaggedLayer* _dragHandleLayer;
}

- (void)awakeFromNib
{
    [super awakeFromNib];
    
    self.starLocation = kCASImageViewInvalidStarLocation;
    
    self.exposureInfoView = [CASExposureInfoView loadFromNib];
    self.exposureInfoView.hidden = YES;
    self.exposureInfoView.imageProcessor = self.imageProcessor;
    [self addSubview:self.exposureInfoView];
    
    self.histogramView = [CASHistogramHUDView loadFromNib];
    self.histogramView.hidden = YES;
    self.histogramView.imageProcessor = self.imageProcessor;
    [self addSubview:self.histogramView];

    self.starInfoView = [CASStarInfoHUDView loadFromNib];
    self.starInfoView.hidden = YES;
    [self addSubview:self.starInfoView];

    self.progressView = [[CASProgressHUDView alloc] initWithFrame:NSMakeRect(10, self.bounds.size.height - 60, 200, 40)];
    self.progressView.hidden = YES;
    [self addSubview:self.progressView];
    
    self.huds = @[self.exposureInfoView,self.histogramView,self.starInfoView,self.progressView];
}

- (void)layoutHuds
{
    const CGFloat kTopMargin = 10;
    const CGFloat kLeftMargin = 10;
    const CGFloat kVerticalSpace = 10;
    const CGFloat kHUDWidth = 160;
    
    CGFloat top = kTopMargin;
    for (NSView* hud in self.huds){
        if (!hud.isHidden){
            hud.frame = NSMakeRect(self.bounds.size.width - kHUDWidth - kLeftMargin,
                                   self.bounds.size.height - hud.frame.size.height - top,
                                   kHUDWidth,
                                   hud.frame.size.height);
            top += kVerticalSpace + hud.frame.size.height;
        }
    }
}

- (void)setFrame:(NSRect)aRect
{
    [super setFrame:aRect];
    
    [self layoutHuds];
}

- (void)setShowProgress:(BOOL)showProgress
{
    if (showProgress != _showProgress){
        _showProgress = showProgress;
        self.progressView.hidden = !_showProgress;
        [self layoutHuds];
    }
}

- (CGFloat)progress
{
    return self.progressView.progress;
}

- (void)setProgress:(CGFloat)progress
{
    self.progressView.progress = progress;
    const NSInteger remainder = self.progressInterval - (progress*self.progressInterval);
    NSString* value = [NSString stringWithFormat:@"%ld secs",remainder]; // todo; nicer formatting e.g. 1m 12s remaining
    if (![self.progressView.label.stringValue isEqualToString:value]){
        self.progressView.label.stringValue = value;
    }
}

- (void)mouseDown:(NSEvent *)theEvent
{
    NSPoint p = [self convertPoint:[theEvent locationInWindow] fromView:nil];
    CALayer* layer = [self.layer hitTest:p];
    if (layer.superlayer == self.selectionLayer){
        _dragHandleLayer = (CASTaggedLayer*)layer;
    }
    _draggingSelection = (layer == self.selectionLayer);
    [super mouseDown:theEvent];
}

- (void)mouseUp:(NSEvent *)theEvent
{
    _dragHandleLayer = nil;
    _draggingSelection = NO;
    [super mouseUp:theEvent];
}

- (void)mouseDragged:(NSEvent *)theEvent
{
    if (_draggingSelection || _dragHandleLayer){
        
        NSPoint p = [self convertViewPointToImagePoint:[self convertPoint:[theEvent locationInWindow] fromView:nil]]; // use layer transforms instead ?
        
        [self disableAnimations:^{
            
            if (_dragHandleLayer){
                [self.selectionLayer dragHandle:_dragHandleLayer movedToPosition:p];
            }
            else {
                self.selectionLayer.position = p;
            }
                        
            const CGRect frame = CASCGRectConstrainWithinRect(self.selectionLayer.frame,CGRectMake(0, 0, CGImageGetWidth(self.image), CGImageGetHeight(self.image)));
            if (!CGRectEqualToRect(frame, self.selectionLayer.frame)){
                self.selectionRect = frame;
            }
            else {
                if ([self.exposureViewDelegate respondsToSelector:@selector(selectionRectChanged:)]){
                    [self.exposureViewDelegate selectionRectChanged:self];
                }
            }

            [self updateStatistics];
            [self updateStarProfile];
        }];
    }
    [super mouseDragged:theEvent];
}

- (void)mouseMoved:(NSEvent *)theEvent
{
    NSPoint p = [self convertPoint:[theEvent locationInWindow] fromView:nil];
    p = [self convertViewPointToImagePoint:p];
//    NSLog(@"mouseMoved: %@",NSStringFromPoint(p));

    if (self.image){
        // check point in rect
        if (NSPointInRect(p, CGRectMake(0, 0, CGImageGetWidth(self.image), CGImageGetHeight(self.image)))){
            // convert to image co-ords
            // get pixel values
        }
    }
}

- (void)selectAll:(id)sender
{
    if (self.image){
        self.currentToolMode = IKToolModeSelect;
        self.selectionRect = CGRectMake(0, 0, CGImageGetWidth(self.image),CGImageGetHeight(self.image));
    }
}

- (void)updateHistogram
{
    if (self.showHistogram){
        if (!_currentExposure){
            self.histogramView.exposure = nil;
        }
        else {
            self.histogramView.exposure = _currentExposure;
        }
    }
}

- (void)updateStatistics
{
    const CGRect frame = self.selectionRect;
    self.exposureInfoView.subframe = CASRectMake(CASPointMake(frame.origin.x, frame.origin.y), CASSizeMake(frame.size.width, frame.size.height));
    [self layoutHuds];
}

- (void)_updateStarProfileImpl
{
    void (^setStarInfoHidden)(CASCCDExposure*,NSPoint*) = ^(CASCCDExposure* exposure,NSPoint* p){
        self.starInfoView.hidden = (exposure == nil);
        if (!self.starInfoView.isHidden){
            [self.starInfoView setExposure:exposure starPosition:*p];
        }
        else {
            self.starInfoView.showSpinner = NO;
        }
        [self layoutHuds];
    };
    
    if (!self.showStarProfile){
        setStarInfoHidden(nil,nil);
        return;
    }
    
    __weak CASCCDExposure* currentExposure = self.currentExposure;
    if (!currentExposure){
        setStarInfoHidden(nil,nil);
        return;
    }
    
    CGRect selectionRect;
    CASCCDExposure* workingExposure;
    if (!self.showSelection){
        workingExposure = currentExposure;
    }
    else {
        selectionRect = self.selectionRect;
        selectionRect.origin.y = currentExposure.actualSize.height - selectionRect.origin.y - selectionRect.size.height;
        workingExposure = [currentExposure subframeWithRect:CASRectFromCGRect(selectionRect)];
    }
    
    self.starInfoView.showSpinner = YES;
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        
        NSArray* stars = [self.guideAlgorithm locateStars:workingExposure];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            
            self.starInfoView.showSpinner = NO;

            if (currentExposure && self.currentExposure == currentExposure){
                
                if ([stars count]){
                    NSPoint p = [[stars lastObject] pointValue];
                    if (workingExposure != currentExposure){
                        p.x += selectionRect.origin.x;
                        p.y += selectionRect.origin.y;
                    }
                    self.starLocation = NSMakePoint(p.x, currentExposure.actualSize.height - p.y);
                    setStarInfoHidden(currentExposure,&p);
                }
                else {
                    self.starLocation = kCASImageViewInvalidStarLocation;
                    setStarInfoHidden(nil,nil);
                }
            }
        });
    });
}

- (void)updateStarProfile
{
    self.starInfoView.showSpinner = NO;
    [self.starInfoView setExposure:nil starPosition:NSZeroPoint];
    
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(_updateStarProfileImpl) object:nil];
    [self performSelector:@selector(_updateStarProfileImpl) withObject:nil afterDelay:0.1 inModes:@[NSRunLoopCommonModes]];
}

- (void)displayExposure
{
    void (^clearImage)() = ^() {
        [self setImage:nil imageProperties:nil];
        self.histogramView.hidden = YES;
    };
    
    [self updateHistogram];
    
    if (!_currentExposure){
        clearImage();
    }
    else {
        
        CASCCDImage* image = [_currentExposure newImage];
        if (!image){
            clearImage();
        }
        else {
            
            CGImageRef CGImage = image.CGImage;
            
            const CASExposeParams params = _currentExposure.params;
            const CGRect subframe = CGRectMake(params.origin.x, params.origin.y, params.size.width, params.size.height);
            
            if (CGImage){
                
                const CGRect frame = CGRectMake(0, 0, params.frame.width, params.frame.height);
                if (!self.scaleSubframe && !CGRectEqualToRect(subframe, frame)){
                    
                    CGContextRef bitmap = [CASCCDImage newBitmapContextWithSize:CASSizeMake(params.frame.width, params.frame.height) bitsPerPixel:params.bps];
                    if (!bitmap){
                        CGImage = nil;
                    }
                    else {
                        CGContextSetRGBFillColor(bitmap,0.35,0.35,0.35,1);
                        CGContextFillRect(bitmap,CGRectMake(0, 0, params.frame.width, params.frame.height));
                        CGContextDrawImage(bitmap,CGRectMake(subframe.origin.x, params.frame.height - (subframe.origin.y + subframe.size.height), subframe.size.width, subframe.size.height),CGImage);
                        CGImage = CGBitmapContextCreateImage(bitmap);
                        CGContextRelease(bitmap);
                    }
                }
                
                if (CGImage){
                                        
                    // set the image
                    [self setImage:CGImage imageProperties:nil];
                }
            }
        }
    }
}

#pragma mark - Properties

- (void)setShowStarProfile:(BOOL)showStarProfile
{
    if (showStarProfile != _showStarProfile){
        _showStarProfile = showStarProfile;
        if (_showStarProfile){
            [self updateStarProfile];
        }
        self.starInfoView.hidden = !showStarProfile;
        [self layoutHuds];
    }
}

- (void)setShowImageStats:(BOOL)showImageStats
{
    if (showImageStats != _showImageStats){
        _showImageStats = showImageStats;
        self.exposureInfoView.hidden = !showImageStats;
        [self layoutHuds];
    }
}

- (CGRect)selectionRect
{
    return self.showSelection ? self.selectionLayer.frame : CGRectZero;
}

- (void)setSelectionRect:(CGRect)rect
{
    self.selectionLayer.frame = rect;
    
    if ([self.exposureViewDelegate respondsToSelector:@selector(selectionRectChanged:)]){
        [self.exposureViewDelegate selectionRectChanged:self];
    }
    
    [self updateStatistics];
    [self updateStarProfile];
}

- (void)setImageProcessor:(CASImageProcessor *)imageProcessor
{
    if (_imageProcessor != imageProcessor){
        _imageProcessor = imageProcessor;
        self.exposureInfoView.imageProcessor = _imageProcessor;
        self.histogramView.imageProcessor = _imageProcessor;
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
        [self layoutHuds];
    }
}

- (void)setScaleSubframe:(BOOL)scaleSubframe
{
    if (_scaleSubframe != scaleSubframe){
        _scaleSubframe = scaleSubframe;
        [self displayExposure];
    }
}

- (void)setCurrentExposure:(CASCCDExposure *)exposure
{
    // don't check for setting to the same exposure as we use this to force a refresh if external settings have changed
    _currentExposure = exposure;
    
    if (_currentExposure && self.showSelection){
        self.selectionRect = CASCGRectConstrainWithinRect(self.selectionRect,CGRectMake(0, 0, _currentExposure.params.frame.width, _currentExposure.params.frame.height));
    }
    
    [self displayExposure];

    self.exposureInfoView.exposure = _currentExposure;

    [self updateStarProfile];
    
    [self layoutHuds];
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

    // zoom to fit on the first image
    if (!_displayedFirstImage){
        _displayedFirstImage = YES;
        [self zoomImageToFit:nil];
    }
    
    // ensure the huds remains at the front.
    for (NSView* hud in self.huds){
        [self addSubview:hud positioned:NSWindowAbove relativeTo:nil];
    }
}

- (void)setStarLocation:(CGPoint)starLocation
{
    _starLocation = starLocation;
    
    if (CGPointEqualToPoint(_starLocation, kCASImageViewInvalidStarLocation)){
        self.starLayer = nil;
    }
    else {
        self.starLayer = [self circularRegionLayerWithPosition:self.starLocation radius:15 colour:(__bridge CGColorRef)(CFBridgingRelease(CGColorCreateGenericRGB(1,1,0,1)))];
    }
    
    [self layoutHuds];
}

- (void)setLockLocation:(CGPoint)lockLocation
{
    _lockLocation = lockLocation;
    
    if (CGPointEqualToPoint(_starLocation, kCASImageViewInvalidStarLocation)){
        self.lockLayer = nil;
    }
    else {
        self.lockLayer = [self circularRegionLayerWithPosition:self.lockLocation radius:15 colour:(__bridge CGColorRef)(CFBridgingRelease(CGColorCreateGenericRGB(1,0,0,1)))];
    }
}

- (void)setSearchRadius:(CGFloat)searchRadius
{
    self.searchLayer = [self circularRegionLayerWithPosition:self.starLocation radius:searchRadius colour:(__bridge CGColorRef)(CFBridgingRelease(CGColorCreateGenericRGB(0,0,1,1)))];
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

- (void)setShowSelection:(BOOL)showSelection
{
    _showSelection = showSelection;
    
    if (_showSelection){
        if (!self.selectionLayer){
            self.selectionLayer = [self selectionLayerWithPosition:CGPointMake(CGImageGetWidth(self.image)/2, CGImageGetHeight(self.image)/2) width:250 height:250 colour:(__bridge CGColorRef)(CFBridgingRelease(CGColorCreateGenericRGB(1,1,0,1)))];
        }
        [self.imageOverlayLayer addSublayer:self.selectionLayer];
        self.selectionRect = self.selectionLayer.frame;
    }
    else {
        [self.selectionLayer removeFromSuperlayer];
    }
    
    [self updateStatistics];
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

- (void)setSelectionLayer:(CASSelectionLayer *)selectionLayer
{
    if (_selectionLayer != selectionLayer){
        if (_selectionLayer){
            [_selectionLayer removeFromSuperlayer];
        }
        _selectionLayer = selectionLayer;
        if (_selectionLayer){
            [self.imageOverlayLayer addSublayer:_selectionLayer];
        }
    }
}

- (void)setCurrentToolMode:(NSString *)currentToolMode
{
    if ([currentToolMode isEqualToString:IKToolModeSelect]){
        self.showSelection = YES;
    }
    else {
        self.showSelection = NO;
        [super setCurrentToolMode:currentToolMode];
    }
}

#pragma mark - Layer factories

- (CALayer*)imageOverlayLayer
{
    CALayer* layer = [self overlayForType:IKOverlayTypeImage];
    if (!layer){
        layer = [CALayer layer];
        layer.backgroundColor = (__bridge CGColorRef)(CFBridgingRelease(CGColorCreateGenericRGB(1,1,1,0)));
        layer.opacity = 0.75;
        [self setOverlay:layer forType:IKOverlayTypeImage];
    }
    return layer;
}

- (CALayer*)circularRegionLayerWithPosition:(CGPoint)position radius:(CGFloat)radius colour:(CGColorRef)colour
{
    CALayer* layer = [CASTaggedLayer layer];
    
    layer.borderColor = colour;
    layer.borderWidth = 2.5;
    layer.cornerRadius = radius;
    layer.bounds = CGRectMake(0, 0, 2*radius, 2*radius);
    layer.position = position;
    layer.masksToBounds = NO;
    
    return layer;
}

- (CALayer*)rectangularLayerWithPosition:(CGPoint)position width:(CGFloat)width height:(CGFloat)height colour:(CGColorRef)colour
{
    CALayer* layer = [CASTaggedLayer layer];
    
    layer.borderColor = colour;
    layer.borderWidth = 2.5;
    layer.bounds = CGRectMake(0, 0, width, height);
    layer.position = position;
    layer.masksToBounds = NO;
    
    return layer;
}

- (CASSelectionLayer*)selectionLayerWithPosition:(CGPoint)position width:(CGFloat)width height:(CGFloat)height colour:(CGColorRef)colour
{
    CASSelectionLayer* layer = [CASSelectionLayer layer];
    
    layer.borderColor = colour;
    layer.borderWidth = 2.5;
    layer.bounds = CGRectMake(0, 0, width, height);
    layer.position = position;
    layer.masksToBounds = NO;
    
    const CGFloat radius = width/20;
    [layer addSublayer:[self circularRegionLayerWithPosition:CGPointMake(0,0) radius:radius colour:colour]];
    [layer addSublayer:[self circularRegionLayerWithPosition:CGPointMake(width,0) radius:radius colour:colour]];
    [layer addSublayer:[self circularRegionLayerWithPosition:CGPointMake(width,height) radius:radius colour:colour]];
    [layer addSublayer:[self circularRegionLayerWithPosition:CGPointMake(0,height) radius:radius colour:colour]];
    
    NSInteger tag = 0;
    for (CASTaggedLayer* l in [layer sublayers]){
        l.tag = tag++;
        l.backgroundColor = colour;
    }
    
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
    reticleLayer.strokeColor = (__bridge CGColorRef)(CFBridgingRelease(CGColorCreateGenericRGB(1,0,0,1)));
    reticleLayer.borderWidth = width;
    
    CGPathRelease(path);
    
    return reticleLayer;
}

@end

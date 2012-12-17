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
#import "CASImageProcessor.h"
#import "CASExposureInfoView.h"
#import <CoreAstro/CoreAstro.h>

const CGPoint kCASImageViewInvalidStarLocation = {-1,-1};

@interface CASProgressView : NSView
@property (nonatomic,assign) CGFloat progress;
@end

@implementation CASProgressView

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

@interface CASProgressContainerView : NSView
@property (nonatomic,weak) NSTextField* label;
@property (nonatomic,weak) CASProgressView* progress;
@end

@implementation CASProgressContainerView

- (id)initWithFrame:(NSRect)frameRect
{
    self = [super initWithFrame:frameRect];
    if (self){
        
        self.wantsLayer = YES;
        self.layer.cornerRadius = 10;
        self.layer.borderWidth = 1.5;
        self.layer.borderColor = CGColorCreateGenericGray(1, 0.8);
        self.layer.backgroundColor = CGColorCreateGenericGray(0, 0.25);
        
        NSTextField* label = [[NSTextField alloc] initWithFrame:CGRectZero]; // strong local as property is weak
        label.autoresizingMask = NSViewWidthSizable|NSViewHeightSizable;
        label.backgroundColor = [NSColor clearColor];
        label.bordered = NO;
        label.textColor = [NSColor whiteColor];
        label.font = [NSFont boldSystemFontOfSize:18];
        label.alignment = NSLeftTextAlignment;
        label.editable = NO;
        [self addSubview:label];
        self.label = label;
        
        CASProgressView* progress = [[CASProgressView alloc] initWithFrame:CGRectZero];
        progress.autoresizingMask = NSViewMaxXMargin;
        [self addSubview:progress];
        self.progress = progress;
        
        self.progress.progress = 0.25;
    }
    return self;
}

- (void)setFrame:(NSRect)frameRect
{
    [super setFrame:frameRect];
    
    CGRect bounds = CGRectInset(self.bounds, 3, 3);
    
    const CGFloat height = 40;
    
    self.label.frame = CGRectMake(10 + height, CGRectGetMidY(self.bounds)-height/2-8, bounds.size.width - height, height);
    self.progress.frame = CGRectMake(10, CGRectGetMidY(self.bounds)-height/2, height, height);
}

@end

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

@interface CASExposureView ()
@property (nonatomic,assign) BOOL firstShowEditPanel;
@property (nonatomic,strong) CALayer* starLayer;
@property (nonatomic,strong) CALayer* lockLayer;
@property (nonatomic,strong) CALayer* searchLayer;
@property (nonatomic,strong) CASSelectionLayer* selectionLayer;
@property (nonatomic,strong) CAShapeLayer* reticleLayer;
@property (nonatomic,assign) CGFloat rotationAngle, zoomFactor;
@property (nonatomic,strong) CASHistogramView* histogramView;
@property (nonatomic,strong) CASProgressContainerView* progressView;
@property (nonatomic,strong) CASExposureInfoView* exposureInfoView;
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
    
    self.histogramView = [[CASHistogramView alloc] initWithFrame:NSMakeRect(10, 10, 400, 200)];
    [self addSubview:self.histogramView];
    self.histogramView.hidden = YES;
    
    self.progressView = [[CASProgressContainerView alloc] initWithFrame:NSMakeRect(10, self.bounds.size.height - 60, 200, 40)];
    [self addSubview:self.progressView];
    self.progressView.hidden = YES;
    
    self.exposureInfoView = [CASExposureInfoView loadExposureInfoView];
    self.exposureInfoView.alphaValue = 0;
    self.exposureInfoView.imageProcessor = self.imageProcessor;
    [self addSubview:self.exposureInfoView];
}

- (void)setFrame:(NSRect)aRect
{
    [super setFrame:aRect];
    
    self.progressView.frame = NSMakeRect(10, self.bounds.size.height - 60, 200, 50);
    self.exposureInfoView.frame = NSMakeRect(self.bounds.size.width - self.exposureInfoView.frame.size.width - 10,
                                             self.bounds.size.height - self.exposureInfoView.frame.size.height - 10,
                                             self.exposureInfoView.frame.size.width,
                                             self.exposureInfoView.frame.size.height);
}

- (void)setShowProgress:(BOOL)showProgress
{
    if (showProgress != _showProgress){
        _showProgress = showProgress;
        if (!_showProgress){
            [self.progressView removeFromSuperview];
        }
        else {
            [self addSubview:self.progressView positioned:NSWindowAbove relativeTo:nil];
        }
        self.progressView.hidden = !_showProgress;
    }
}

- (CGFloat)progress
{
    return self.progressView.progress.progress;
}

- (void)setProgress:(CGFloat)progress
{
    self.progressView.progress.progress = progress;
    const NSInteger remainder = self.progressInterval - (progress*self.progressInterval);
    self.progressView.label.stringValue = [NSString stringWithFormat:@"%lds remaining",remainder]; // todo; nicer formatting e.g. 1m 12s remaining
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
                        
            // CGRectConstrainWithinRect()
            const CGRect image = CGRectMake(0, 0, CGImageGetWidth(self.image), CGImageGetHeight(self.image));
            CGRect frame = self.selectionLayer.frame;
            frame.origin.x = MAX(0,frame.origin.x);
            frame.origin.y = MAX(0,frame.origin.y);
            frame.size.width = MIN(frame.size.width,image.size.width);
            frame.size.height = MIN(frame.size.height,image.size.height);
            if (CGRectGetMaxX(frame) > CGRectGetMaxX(image)){
                frame.origin.x = CGRectGetMaxX(image) - frame.size.width;
            }
            if (CGRectGetMaxY(frame) > CGRectGetMaxY(image)){
                frame.origin.y = CGRectGetMaxY(image) - frame.size.height;
            }

            if (!CGRectEqualToRect(frame, self.selectionLayer.frame)){
                self.selectionRect = frame;
            }
            else {
                if ([self.exposureViewDelegate respondsToSelector:@selector(selectionRectChanged:)]){
                    [self.exposureViewDelegate selectionRectChanged:self];
                }
            }

            [self updateStatistics];
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
            self.histogramView.histogram = nil;
        }
        else {
            self.histogramView.histogram = [self.imageProcessor histogram:_currentExposure];
        }
    }
}

- (void)updateStatistics
{
    const CGRect frame = self.selectionRect;
    self.exposureInfoView.subframe = CASRectMake(CASPointMake(frame.origin.x, frame.origin.y), CASSizeMake(frame.size.width, frame.size.height));
}

- (void)displayExposure
{
    void (^clearImage)() = ^() {
        [self setImage:nil imageProperties:nil];
        [self.histogramView removeFromSuperview];
    };
    
    [self updateHistogram];
    
    if (!_currentExposure){
        clearImage();
    }
    else {
        
        CASCCDImage* image = [_currentExposure createImage];
        if (!image){
            clearImage();
        }
        else {
            
            CGImageRef CGImage = image.CGImage;
            
            const CASExposeParams params = _currentExposure.params;
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
                                        
                    // set the image
                    [self setImage:CGImage imageProperties:nil];
                    
                    // zoom to fit on the first image
                    if (!_displayedFirstImage){
                        _displayedFirstImage = YES;
                        [self zoomImageToFit:nil];
                    }
                    
                    // ensure the histogram view remains at the front.
                    [self addSubview:self.histogramView positioned:NSWindowAbove relativeTo:nil];
                    [self addSubview:self.progressView positioned:NSWindowAbove relativeTo:nil];
                    [self addSubview:self.exposureInfoView positioned:NSWindowAbove relativeTo:nil];
                }
            }
        }
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
}

- (void)setImageProcessor:(CASImageProcessor *)imageProcessor
{
    if (_imageProcessor != imageProcessor){
        _imageProcessor = imageProcessor;
        self.exposureInfoView.imageProcessor = self.imageProcessor;
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
    
    [self displayExposure];

    self.exposureInfoView.exposure = _currentExposure;
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

- (void)setShowSelection:(BOOL)showSelection
{
    _showSelection = showSelection;
    
    if (_showSelection){
        if (!self.selectionLayer){
            self.selectionLayer = [self selectionLayerWithPosition:CGPointMake(CGImageGetWidth(self.image)/2, CGImageGetHeight(self.image)/2) width:250 height:250 colour:CGColorCreateGenericRGB(1,1,0,1)];
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
    reticleLayer.strokeColor = CGColorCreateGenericRGB(1,0,0,1);
    reticleLayer.borderWidth = width;
    
    return reticleLayer;
}

@end

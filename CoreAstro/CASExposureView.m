//
//  CASExposureView.m
//  CoreAstro
//
//  Created by Simon Taylor on 02/12/12.
//  Copyright (c) 2012 Mako Technology Ltd. All rights reserved.
//

#import "CASExposureView.h"
#import "CASExposureInfoView.h"
#import "CASProgressHUDView.h"
#import "CASStarInfoHUDView.h"
#import "CASHistogramHUDView.h"
#import "CASPlateSolutionHUDView.h"
#import "CASLabelHUDView.h"
#import "CASPlateSolvedObject+Drawing.h"

#import <CoreAstro/CoreAstro.h>
#import <QuartzCore/QuartzCore.h>

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
    
    [(CALayer*)[[self sublayers] objectAtIndex:0] setPosition:CGPointMake(0,0)];
    [(CALayer*)[[self sublayers] objectAtIndex:1] setPosition:CGPointMake(size.width,0)];
    [(CALayer*)[[self sublayers] objectAtIndex:2] setPosition:CGPointMake(size.width,size.height)];
    [(CALayer*)[[self sublayers] objectAtIndex:3] setPosition:CGPointMake(0,size.height)];
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
@property (nonatomic,assign) CGFloat reticleLayerAngle;
@property (nonatomic,assign) CGFloat rotationAngle, zoomFactor;
@property (nonatomic,strong) CASHistogramHUDView* histogramView;
@property (nonatomic,strong) CASProgressHUDView* progressView;
@property (nonatomic,strong) CASLabelHUDView* solvingView;
@property (nonatomic,strong) CASStarInfoHUDView* starInfoView;
@property (nonatomic,strong) CASExposureInfoView* exposureInfoView;
@property (nonatomic,strong) CASPlateSolutionHUDView* plateSolutionView;
@property (nonatomic,strong) NSArray* huds;
@end

@implementation CASExposureView {
    BOOL _showSelection:1;
    BOOL _draggingSelection:1;
    BOOL _displayedFirstImage:1;
    BOOL _autoContrastStretch;
    NSSize _draggingSelectionOffset;
    CASTaggedLayer* _dragHandleLayer;
    CALayer* _imageOverlayLayer;
    CALayer* _annotationsLayer;
}

#pragma mark - Object Lifecycle

- (void)awakeFromNib
{
    [super awakeFromNib];
    
    self.starLocation = kCASImageViewInvalidStarLocation;
    
    self.exposureInfoView = [CASExposureInfoView loadFromNib];
    self.exposureInfoView.imageProcessor = self.imageProcessor;
    
    self.histogramView = [CASHistogramHUDView loadFromNib];
    self.histogramView.imageProcessor = self.imageProcessor;

    self.starInfoView = [CASStarInfoHUDView loadFromNib];

    self.progressView = [[CASProgressHUDView alloc] initWithFrame:NSZeroRect];
    self.progressView.translatesAutoresizingMaskIntoConstraints = YES;
    self.progressView.frame = NSMakeRect(10, self.bounds.size.height - 60, 200, 50);
    
    self.solvingView = [[CASLabelHUDView alloc] initWithFrame:NSZeroRect];
    self.solvingView.translatesAutoresizingMaskIntoConstraints = YES;
    self.solvingView.frame = NSMakeRect(10, self.bounds.size.height - 60, 200, 50);
    self.solvingView.label = NSLocalizedString(@"Solving...", @"Solving...");
    
    self.plateSolutionView = [CASPlateSolutionHUDView loadFromNib];
    
    self.huds = @[self.solvingView,self.progressView,self.exposureInfoView,self.histogramView,self.starInfoView,self.plateSolutionView];
    
    for (NSView* hud in self.huds){
        hud.hidden = YES;
        hud.autoresizingMask = NSViewMinXMargin|NSViewMinYMargin;
        // hud.translatesAutoresizingMaskIntoConstraints = NO; // no, need to add constraints
        [self.hudContainerView addSubview:hud];
    }
}

#pragma mark - Responder

- (BOOL)acceptsFirstResponder
{
    return YES;
}

- (void)mouseDown:(NSEvent *)theEvent
{
    const BOOL doubleClick = (theEvent.clickCount == 2);
    
    // double-click in scale subframe mode returns to normal display mode
    if (self.scaleSubframe && doubleClick){
        self.scaleSubframe = NO;
    }
    else {
        
        // convert point to view co-ords (this is indepdendent of flipping as that's done using a coreimage filter)
        NSPoint p = [self convertPoint:[theEvent locationInWindow] fromView:nil];
        
        // find the layer at this point
        CALayer* layer = [[self imageOverlayLayer] hitTest:p];
        
        // detect clicks in selection drag handles
        if (layer.superlayer == self.selectionLayer){
            _dragHandleLayer = (CASTaggedLayer*)layer;
        }
        
        // detect clicks in selection
        const BOOL clickInSelection = (layer == self.selectionLayer);
        if (!clickInSelection){
            _draggingSelection = NO;
        }
        else{
            
            // double-click toggles subframe mode
            if (doubleClick){
                self.scaleSubframe = YES;
            }
            else {
                
                // set selection dragging on and correct for the mouse offset
                _draggingSelection = YES;
                if (_draggingSelection){
                    p = [self convertViewPointToImagePoint:p];
                    _draggingSelectionOffset = NSMakeSize(self.selectionLayer.position.x - p.x, self.selectionLayer.position.y - p.y);
                }
            }
        }
    }
    
    [super mouseDown:theEvent];
}

- (void)mouseUp:(NSEvent *)theEvent
{
    _dragHandleLayer = nil;
    _draggingSelection = NO;
    _draggingSelectionOffset = CGSizeZero;
    [super mouseUp:theEvent];
}

- (void)mouseDragged:(NSEvent *)theEvent
{
    if (_draggingSelection || _dragHandleLayer){
        
        [CATransaction begin];
        [CATransaction setDisableActions:YES];
        
        @try {
            
            NSPoint p = [self convertViewPointToImagePoint:[self convertPoint:[theEvent locationInWindow] fromView:nil]]; // use layer transforms instead ?
            
            p.x += _draggingSelectionOffset.width;
            p.y += _draggingSelectionOffset.height;
            
            if (_dragHandleLayer){
                [self.selectionLayer dragHandle:_dragHandleLayer movedToPosition:p];
            }
            else {
                self.selectionLayer.position = p;
            }
            
            CGRect frame = CASCGRectConstrainWithinRect(self.selectionLayer.frame,CGRectMake(0, 0, CGImageGetWidth(self.CGImage), CGImageGetHeight(self.CGImage)));
            
            if ([self.exposureViewDelegate respondsToSelector:@selector(validateSelectionRect:exposureView:)]){
                frame = [self inverseTransformRect:[self.exposureViewDelegate validateSelectionRect:[self transformRect:frame] exposureView:self]];
            }
            
            if (!CGRectEqualToRect(frame, self.selectionLayer.frame)){
                self.selectionRect = frame; // invokes -selectionRectChanged: on delegate
            }
            else {
                [self informSelectionChanged];
            }
        }
        @catch (NSException *exception) {
            NSLog(@"*** %@: %@",NSStringFromSelector(_cmd),exception);
        }
        
        [CATransaction commit];
        
        [self updateStatistics];
        [self updateStarProfile];
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
        if (NSPointInRect(p, CGRectMake(0, 0, CGImageGetWidth(self.CGImage), CGImageGetHeight(self.CGImage)))){
            // convert to image co-ords
            // get pixel values
        }
    }
}

- (void)flagsChanged:(NSEvent *)theEvent
{
    if (theEvent.modifierFlags & NSAlternateKeyMask) {
        self.showStarProfileMode = kCASStarProfileModeCentre;
    }
    else {
        self.showStarProfileMode = kCASStarProfileModeAuto;
    }
}

- (void)selectAll:(id)sender
{
    if (self.image){
        self.showSelection = YES;
        self.selectionRect = CGRectMake(0, 0, CGImageGetWidth(self.CGImage),CGImageGetHeight(self.CGImage));
    }
}

#pragma mark - Drawing

- (void)setFrame:(NSRect)aRect
{
    [super setFrame:aRect];
    
    [self layoutHuds];
}

- (CGPoint)convertViewPointToImagePoint:(CGPoint)point
{
    // assuming there's a 1-to-1 mapping between the view and image co-ords
    return point;
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
    if (self.currentExposure){
        const CGRect frame = self.selectionRect;
        CASRect subframe = CASRectMake(CASPointMake(frame.origin.x, frame.origin.y), CASSizeMake(frame.size.width, frame.size.height));
        subframe.origin.y = self.currentExposure.params.frame.height - subframe.origin.y - subframe.size.height;
        self.exposureInfoView.subframe = subframe;
        [self layoutHuds];
    }
}

- (void)_updateStarProfileImpl
{
    void (^setStarInfoExposure)(CASCCDExposure*,const NSPoint*) = ^(CASCCDExposure* exposure,const NSPoint* p){
        self.starInfoView.hidden = (exposure == nil);
        if (!self.starInfoView.isHidden){
            if (p){
                [self.starInfoView setExposure:exposure starPosition:*p];
            }
        }
        else {
            self.starInfoView.showSpinner = NO;
        }
        [self layoutHuds];
    };
    
    if (!self.showStarProfile){
        setStarInfoExposure(nil,nil);
        return;
    }
    
    __weak CASCCDExposure* currentExposure = self.currentExposure;
    if (!currentExposure){
        setStarInfoExposure(nil,nil);
        return;
    }
    
    const size_t imageHeight = CGImageGetHeight(self.CGImage);

    CGRect selectionRect = CGRectZero;
    CASCCDExposure* workingExposure;
    if (!self.showSelection){
        workingExposure = currentExposure;
    }
    else {
        if (currentExposure.isSubframe){ // todo; subframes of subframes
            workingExposure = currentExposure;
        }
        else {
            selectionRect = self.selectionRect;
            selectionRect.origin.y = imageHeight - (selectionRect.origin.y + selectionRect.size.height);
            workingExposure = [currentExposure subframeWithRect:CASRectFromCGRect(selectionRect)];
        }
    }
    
    // todo; deal with the situation where we have a historical image subframe with and without a selection
    
    self.starInfoView.showSpinner = YES;
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        
        NSArray* stars = nil;
        if (self.showStarProfileMode == kCASStarProfileModeAuto){
            stars = [self.guideAlgorithm locateStars:workingExposure];
        }
        else {
            stars = [NSArray arrayWithObject:[NSValue valueWithPoint:NSMakePoint(workingExposure.params.size.width/2, workingExposure.params.size.height/2)]];
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            
            self.starInfoView.showSpinner = NO;

            if (currentExposure && self.currentExposure == currentExposure){
                
                if ([stars count]){
                    
                    // get the result from the guide algorithm in the sub-exposure's co-ordinate system
                    NSPoint starPoint = [[stars lastObject] pointValue];
                    
                    // calculate the display position of the star location indicator accounting for selections, binning, etc
                    NSPoint displayPoint = starPoint;

                    if (self.scaleSubframe){
                        
                        // selection is being displayed full screen so don't have to correct x,y
                        const CGFloat selectionBinnedHeight = currentExposure.params.size.height/currentExposure.params.bin.height;
                        self.starLocation = NSMakePoint(displayPoint.x,selectionBinnedHeight - displayPoint.y);
                    }
                    else {
                        
                        // convert from selection-relative co-ord to whole image co-ord
                        // (p and selectionRect have 0,0 at the top left of the image)
                        if (workingExposure != currentExposure){
                            
                            displayPoint.x = self.selectionRect.origin.x + displayPoint.x*currentExposure.params.bin.width;
                            
                            displayPoint.y = imageHeight - (self.selectionRect.origin.y + self.selectionRect.size.height) + displayPoint.y*currentExposure.params.bin.height; // binning...
                        }
                        else {
                            
                            // could just use a full frame selection rect instead and then have a single calculation...
                            displayPoint.x = workingExposure.params.origin.x + displayPoint.x*currentExposure.params.bin.width;
                            displayPoint.y = workingExposure.params.origin.y + displayPoint.y*currentExposure.params.bin.height;
                        }
                        
                        // set the display star location (0,0 in image co-ords is in the bottom left)
                        

                        self.starLocation = NSMakePoint(displayPoint.x/**currentExposure.params.bin.width*/,
                                                        imageHeight - displayPoint.y/**currentExposure.params.bin.height*/);
                        

                    }

                    // map star point from working exposure to current exposure - binning ?
                    starPoint.x += workingExposure.params.origin.x/currentExposure.params.bin.width;
                    starPoint.y += workingExposure.params.origin.y/currentExposure.params.bin.height;

                    setStarInfoExposure(currentExposure,&starPoint);
                }
                else {
                    self.starLocation = kCASImageViewInvalidStarLocation;
                    setStarInfoExposure(currentExposure,&kCASImageViewInvalidStarLocation);
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

- (void)displayExposureWithReset:(BOOL)resetDisplay
{
    void (^clearImage)() = ^() {
        [self setImage:nil];
    };
    
    [self updateHistogram];
    
    self.displayingScaledSubframe = NO;

    if (!_currentExposure){
        clearImage();
    }
    else {
        
        CASCCDImage* image = [_currentExposure newImage];
        if (!image){
            clearImage();
        }
        else {
            
            // todo; this is madly inefficient :)
            
            CGImageRef CGImage2 = NULL; // this is just to silence analyser warnings as it doesn't see the reassignment to CGImage below
            CGImageRef CGImage = image.CGImage; // the dimensions of this are divided by the binning factor todo; image.CIImage
            if (CGImage){
                
                // grab a local copy as we're going to use this a bit
                const CASExposeParams params = _currentExposure.params;
                
                // draw subframes as an inset within a full frame sized gray background unless the scaleSubframe flag is set
                if (!self.scaleSubframe){
                    
                    // todo; this is using the unbinned co-ords but should probably be using binned
                    CGContextRef bitmap = [image newContextOfSize:CASSizeMake(params.frame.width, params.frame.height)];
                    if (!bitmap){
                        CGImage = nil;
                    }
                    else {
                        
                        // always make the image the full frame size
                        const CGRect frame = CGRectMake(0, 0, params.frame.width, params.frame.height);
                        const CGRect subframe = CGRectMake(params.origin.x, params.origin.y, params.size.width, params.size.height);
                        if (CGRectEqualToRect(subframe, frame)){
                            CGContextDrawImage(bitmap,CGRectMake(0, 0, params.frame.width, params.frame.height),CGImage);
                        }
                        else{
                            self.displayingScaledSubframe = YES;
                            CGContextSetRGBFillColor(bitmap,0.35,0.35,0.35,1);
                            CGContextFillRect(bitmap,CGRectMake(0, 0, params.frame.width, params.frame.height));
                            CGContextDrawImage(bitmap,CGRectMake(subframe.origin.x, params.frame.height - (subframe.origin.y + subframe.size.height), subframe.size.width, subframe.size.height),CGImage);
                        }
                        CGImage2 = CGImage = CGBitmapContextCreateImage(bitmap);
                        CGContextRelease(bitmap);
                    }
                }
            }
            
            // set the image
            if (CGImage){
                [self setImage:CGImage resetDisplay:resetDisplay];
            }
            else {
                clearImage();
            }
            
            CGImageRelease(CGImage2);
        }
    }
}

- (CGAffineTransform)currentTransform
{
    CGAffineTransform transform = CGAffineTransformIdentity;
    if (self.flipHorizontal){
        transform = CGAffineTransformConcat(transform,CGAffineTransformMakeScale(-1, 1));
        transform = CGAffineTransformConcat(transform,CGAffineTransformMakeTranslation(self.layer.bounds.size.width, 0));
    }
    if (!self.flipVertical){
        transform = CGAffineTransformConcat(transform,CGAffineTransformMakeScale(1, -1));
        transform = CGAffineTransformConcat(transform,CGAffineTransformMakeTranslation(0, self.layer.bounds.size.height));
    }
    return transform;
}

- (CGRect)transformRect:(CGRect)rect
{
    return CGRectApplyAffineTransform(rect,[self currentTransform]);
}

- (CGRect)inverseTransformRect:(CGRect)rect
{
    return CGRectApplyAffineTransform(rect,CGAffineTransformInvert([self currentTransform]));
}

#pragma mark - Properties

- (CGFloat)progress
{
    return self.progressView.progress;
}

- (void)setProgress:(CGFloat)progress
{
    const NSInteger remainder = self.progressInterval - (progress*self.progressInterval);
    NSString* value = [NSString stringWithFormat:@"%ld secs",remainder]; // todo; nicer formatting e.g. 1m 12s remaining
    [self.progressView setProgress:progress label:value];
}

- (CGRect)selectionRect
{
    CGRect frame = CGRectZero;
    if (_showSelection){
        frame = [self transformRect:self.selectionLayer.frame];
    }
    return frame;
}

- (void)informSelectionChanged
{
    if ([self.exposureViewDelegate respondsToSelector:@selector(selectionRectChanged:)]){
        [self.exposureViewDelegate selectionRectChanged:self];
    }
}

- (void)setSelectionRect:(CGRect)selectionRect
{
    // call through to delegate to validate the subframe
    if ([self.exposureViewDelegate respondsToSelector:@selector(validateSelectionRect:exposureView:)]){
        selectionRect = [self inverseTransformRect:[self.exposureViewDelegate validateSelectionRect:[self transformRect:selectionRect] exposureView:self]];
    }

    self.selectionLayer.frame = selectionRect;
    
    [self informSelectionChanged];
    
    [self updateStatistics];
    [self updateStarProfile];
}

- (void)setFlipHorizontal:(BOOL)flipHorizontal
{
    [super setFlipHorizontal:flipHorizontal];
    
    // todo; move self.selectionLayer.frame if toggled
    
    [self informSelectionChanged];
}

- (void)setFlipVertical:(BOOL)flipVertical
{
    [super setFlipVertical:flipVertical];
    
    // todo; move self.selectionLayer.frame if toggled
    
    [self informSelectionChanged];
}

- (void)setImageProcessor:(CASImageProcessor *)imageProcessor
{
    if (_imageProcessor != imageProcessor){
        _imageProcessor = imageProcessor;
        self.exposureInfoView.imageProcessor = _imageProcessor;
        self.histogramView.imageProcessor = _imageProcessor;
    }
}

#pragma mark - HUDs

// todo; move hud layout into an image view controller
- (NSView*)hudContainerView
{
    return self.containerView;
}

- (void)layoutHuds
{
    const CGFloat kTopMargin = 10;
    const CGFloat kLeftMargin = 10;
    const CGFloat kVerticalSpace = 10;
    const CGFloat kHUDWidth = 160;
    
    const BOOL viewHidden = self.isHiddenOrHasHiddenAncestor; // this is only really needed because at the moment HUDs are not subviews of the image view but of a superview so that they aren't zoomed, etc with the image
    
    CGFloat top = kTopMargin;
    for (CASHUDView* hud in self.huds){
        if (hud.visible && !viewHidden){
            hud.hidden = NO;
            hud.frame = NSMakeRect(self.hudContainerView.bounds.size.width - kHUDWidth - kLeftMargin,
                                   self.hudContainerView.bounds.size.height - hud.frame.size.height - top,
                                   kHUDWidth,
                                   hud.frame.size.height);
            top += kVerticalSpace + hud.frame.size.height;
        }
        else {
            hud.hidden = YES;
        }
    }
}

- (void)setShowSolving:(BOOL)showSolving
{
    if (showSolving != _showSolving){
        _showSolving = showSolving;
        self.solvingView.visible = _showSolving;
        [self layoutHuds];
    }
}

- (void)setShowProgress:(BOOL)showProgress
{
    if (showProgress != _showProgress){
        _showProgress = showProgress;
        self.progressView.visible = _showProgress;
        [self layoutHuds];
    }
}

- (void)setShowStarProfile:(BOOL)showStarProfile
{
    if (showStarProfile != _showStarProfile){
        _showStarProfile = showStarProfile;
        if (_showStarProfile){
            [self updateStarProfile];
        }
        self.starInfoView.visible = showStarProfile;
        [self layoutHuds];
    }
}

- (void)setShowImageStats:(BOOL)showImageStats
{
    if (showImageStats != _showImageStats){
        _showImageStats = showImageStats;
        self.exposureInfoView.visible = showImageStats;
        [self layoutHuds];
    }
}

- (void)setShowHistogram:(BOOL)showHistogram
{
    if (_showHistogram != showHistogram){
        _showHistogram = showHistogram;
        self.histogramView.visible = _showHistogram;
        if (_showHistogram){
            [self updateHistogram];
        }
        [self layoutHuds];
    }
}

#pragma mark - Display Controls

- (void)setScaleSubframe:(BOOL)scaleSubframe
{
    if (_scaleSubframe != scaleSubframe){
        _scaleSubframe = scaleSubframe;
        self.selectionLayer.hidden = _scaleSubframe; // hide the selection in scale mode
        [self displayExposureWithReset:YES];
        [self zoomImageToFit:nil]; // todo; return to zoom level before entering scale subframe mode
    }
}

- (void)setShowReticle:(BOOL)showReticle
{
    _showReticle = showReticle;
    
    if (_showReticle){
        self.reticleLayer = [self createReticleLayer2];
    }
    else {
        self.reticleLayer = nil;
    }
}

- (BOOL)showSelection
{
    return _showSelection && !self.displayingScaledSubframe;
}

- (void)setShowSelection:(BOOL)showSelection
{
    _showSelection = showSelection;
    
    if (_showSelection){
        if (!self.selectionLayer){
            self.selectionLayer = [self selectionLayerWithPosition:CGPointMake(CGImageGetWidth(self.CGImage)/2, CGImageGetHeight(self.CGImage)/2) width:250 height:250 colour:(__bridge CGColorRef)(CFBridgingRelease(CGColorCreateGenericRGB(1,1,0,1)))];
        }
        [self.imageOverlayLayer addSublayer:self.selectionLayer];
        self.selectionRect = self.selectionLayer.frame;
    }
    else {
        [self.selectionLayer removeFromSuperlayer];
    }
    
    [self updateStatistics];
}

- (BOOL)autoContrastStretch
{
    return _autoContrastStretch;
}

- (void)setAutoContrastStretch:(BOOL)autoContrastStretch
{
    if (autoContrastStretch != _autoContrastStretch){
        _autoContrastStretch = autoContrastStretch;
        if (_autoContrastStretch && self.currentExposure){
            [self configureContrastStretch];
        }
    }
}

#pragma mark - Display Objects

- (void)setImage:(CGImageRef)image
{
    [self setImage:image resetDisplay:YES];
}

- (void)setImage:(CGImageRef)image resetDisplay:(BOOL)resetDisplay
{
    self.searchLayer = nil;
    self.reticleLayer = nil;
    
    [super setCGImage:image resetDisplay:resetDisplay];
    
    self.starLocation = kCASImageViewInvalidStarLocation;
    
    if (self.showReticle){
        self.reticleLayer = [self createReticleLayer2];
    }
    
    // zoom to fit on the first image
    if (!_displayedFirstImage){
        _displayedFirstImage = YES;
        [self zoomImageToFit:nil];
    }
    
    // ensure the huds remains at the front.
    for (NSView* hud in self.huds){
        [self.hudContainerView addSubview:hud positioned:NSWindowAbove relativeTo:nil];
    }
    
    [self addSolutionAnnotations];
}

- (void)setCurrentExposure:(CASCCDExposure *)exposure
{
    [self setCurrentExposure:exposure resetDisplay:YES];
}

- (BOOL)shouldResetDisplayForExposure:(CASCCDExposure*)exposure
{
    // don't reset the display if the new exposure is the same size as the current exposure
    BOOL resetDisplay = YES;
    CASCCDExposure* currentExposure = self.currentExposure;
    if (currentExposure && exposure){
        CASExposeParams params = exposure.params;
        CASExposeParams currentParams = currentExposure.params;
        if (params.frame.width == currentParams.frame.width && params.frame.height == currentParams.frame.height){
            resetDisplay = NO;
        }
    }
    return resetDisplay;
}

- (void)setCurrentExposure:(CASCCDExposure *)exposure resetDisplay:(BOOL)resetDisplay
{
    // todo; we *do* need to check we're not setting the same one again
    
    // don't check for setting to the same exposure as we use this to force a refresh if external settings have changed
    _currentExposure = exposure;
    
    // set the current image taking into account scaleSubframe mode, etc
    [self displayExposureWithReset:resetDisplay];
    
    // clip any selection rect
    if (_currentExposure && self.showSelection){
        if (!self.image){
            self.showSelection = NO;
        }
        else if (!self.scaleSubframe) {
            self.selectionRect = CASCGRectConstrainWithinRect(self.selectionRect,CGRectMake(0, 0, CGImageGetWidth(self.CGImage), CGImageGetHeight(self.CGImage)));
        }
    }

    self.exposureInfoView.exposure = _currentExposure;

    [self updateStarProfile];
    
    [self layoutHuds];
    
    if (self.autoContrastStretch){
        [self configureContrastStretch];
    }
}

- (void)removeSolutionAnnotations
{
    for (CALayer* layer in [[self.annotationsLayer sublayers] copy]){
        [layer removeFromSuperlayer];
    }
}

- (void)addSolutionAnnotations:(CASPlateSolveSolution*)solution withColour:(CGColorRef)colour
{
    if (!solution){
        return;
    }
    
    // todo; choose font based on image size
    const NSUInteger width = self.currentExposure.params.frame.width;
    NSFont* font = [NSFont boldSystemFontOfSize:32 * (width/1932)]; // <<< todo; magic number ??
    
    // draw detected objects
    for (CASPlateSolvedObject* object in solution.objects){
        [object createLayerInLayer:self.annotationsLayer withFont:font andColour:colour scaling:self.currentExposure.params.bin.width];
    }
    
    // draw centre angle
    if (solution.centreAngle){
        
        CALayer* angleLayer = [CALayer layer];
        
        angleLayer.borderColor = colour;
        angleLayer.borderWidth = 2.5;
        const double width = hypot(CGRectGetWidth(self.annotationsLayer.bounds),CGRectGetHeight(self.annotationsLayer.bounds));
        angleLayer.bounds = CGRectMake(0,0,width,angleLayer.borderWidth);
        angleLayer.position = CGPointMake(CGRectGetMidX(self.annotationsLayer.bounds), CGRectGetMidY(self.annotationsLayer.bounds));
        
        [angleLayer setAffineTransform:CGAffineTransformMakeRotation(-[solution.centreAngle floatValue]*M_PI/180.0)];
        
        [self.annotationsLayer addSublayer:angleLayer];
    }
    
    CGColorRelease(colour);
}

- (void)addSolutionAnnotations
{
    [self removeSolutionAnnotations];
    if (_plateSolveSolution){
        [self addSolutionAnnotations:_plateSolveSolution withColour:CGColorCreateGenericRGB(1, 1, 0, 0.75)];
    }
    if (_lockedPlateSolveSolution){
        [self addSolutionAnnotations:_lockedPlateSolveSolution withColour:CGColorCreateGenericRGB(1, 0, 0, 0.75)];
    }
}

- (void)setPlateSolveSolution:(CASPlateSolveSolution *)plateSolveSolution
{
    if (_plateSolveSolution != plateSolveSolution){
        
        _plateSolveSolution = plateSolveSolution;
        
        [self addSolutionAnnotations];
        
        self.plateSolutionView.solution = _plateSolveSolution;
        self.plateSolutionView.visible = (_plateSolveSolution != nil);
        [self layoutHuds];
    }
}

- (void)setLockedPlateSolveSolution:(CASPlateSolveSolution *)lockedPlateSolveSolution
{
    if (lockedPlateSolveSolution != _lockedPlateSolveSolution){
                
        _lockedPlateSolveSolution = lockedPlateSolveSolution;
        
        [self addSolutionAnnotations];
    }
}

#pragma mark - Guiding Display

- (void)setStarLocation:(CGPoint)starLocation
{
    _starLocation = starLocation;
    
    if (CGPointEqualToPoint(_starLocation, kCASImageViewInvalidStarLocation)){
        self.starLayer = nil;
    }
    else {
        // animate the star position ? - makes it easier to spot in large images
        self.starLayer = [self createStarPositionLayerWithPosition:self.starLocation];
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

#pragma mark - Layers

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

- (void)setReticleLayerAngle:(CGFloat)reticleLayerAngle
{
    _reticleLayerAngle = reticleLayerAngle;
    
    if (self.reticleLayer && self.image){
        
        const CGFloat imageWidth = CGImageGetWidth(self.CGImage);
        const CGFloat imageHeight = CGImageGetHeight(self.CGImage);
        
        CATransform3D transform = CATransform3DIdentity;
        transform = CATransform3DConcat(transform, CATransform3DMakeTranslation(-imageWidth/2, -imageHeight/2, 0));
        transform = CATransform3DConcat(transform, CATransform3DMakeRotation(_reticleLayerAngle*M_PI/180.0,0,0,1));
        transform = CATransform3DConcat(transform, CATransform3DMakeTranslation(imageWidth/2, imageHeight/2, 0));
        self.reticleLayer.transform = transform;
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

#pragma mark - Layer factories

- (CALayer*)imageOverlayLayer
{
    if (!_imageOverlayLayer){
        _imageOverlayLayer = [CALayer layer];
        _imageOverlayLayer.backgroundColor = (__bridge CGColorRef)(CFBridgingRelease(CGColorCreateGenericRGB(1,1,1,0)));
        _imageOverlayLayer.opacity = 0.75;
        [self.layer addSublayer:_imageOverlayLayer];
    }
    return _imageOverlayLayer;
}

- (CALayer*)annotationsLayer
{
    if (!_annotationsLayer){
        _annotationsLayer = [CALayer layer];
        _annotationsLayer.bounds = CGRectMake(0, 0, self.image.extent.size.width, self.image.extent.size.height);
        _annotationsLayer.position = CGPointMake(self.image.extent.size.width/2, self.image.extent.size.height/2);
        [self.imageOverlayLayer addSublayer:_annotationsLayer];
    }
    return _annotationsLayer;
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
    CGPathAddRect(path, nil, CGRectMake(0, CGImageGetHeight(self.CGImage)/2.0, CGImageGetWidth(self.CGImage), width));
    CGPathAddRect(path, nil, CGRectMake(CGImageGetWidth(self.CGImage)/2.0, 0, width, CGImageGetHeight(self.CGImage)));
    
    reticleLayer.path = path;
    reticleLayer.strokeColor = (__bridge CGColorRef)(CFBridgingRelease(CGColorCreateGenericRGB(1,0,0,1)));
    reticleLayer.borderWidth = width;
    
    CGPathRelease(path);
    
    return reticleLayer;
}

- (CAShapeLayer*)createReticleLayer2
{
    CAShapeLayer* reticleLayer = [CAShapeLayer layer];
    
    CGMutablePathRef path = CGPathCreateMutable();
    
    const CGFloat imageWidth = CGImageGetWidth(self.CGImage);
    const CGFloat imageHeight = CGImageGetHeight(self.CGImage);
    
    const CGFloat reticleWidth = 0.5;
//    const CGFloat reticleLength = MAX(imageWidth,imageHeight);
    
    CGFloat hoffset = 5.5;
    CGFloat voffset = 5.5;
    const float offsetArcsecs = 10;
    
    if (self.currentExposure){
        id aperture = [[NSUserDefaults standardUserDefaults] objectForKey:@"CASDefaultScopeAperture"];
        id fnumber = [[NSUserDefaults standardUserDefaults] objectForKey:@"CASDefaultScopeFNumber"];
        if ([aperture respondsToSelector:@selector(floatValue)] && [fnumber respondsToSelector:@selector(floatValue)]){
            const float fl = [fnumber floatValue] * [aperture floatValue];
            if (fl > 0){
                NSDictionary* meta = [self.currentExposure meta];
                const float pixelWidth = [[meta valueForKeyPath:@"device.params.pixelWidth"] floatValue];
                const float pixelHeight = [[meta valueForKeyPath:@"device.params.pixelHeight"] floatValue];
                if (pixelWidth > 0 && pixelHeight > 0){
                    const float arcsecsPerPixelH = (pixelWidth/fl) * 206.3 * self.currentExposure.params.bin.width;
                    hoffset = offsetArcsecs / arcsecsPerPixelH;
                    const float arcsecsPerPixelV = (pixelHeight/fl) * 206.3 * self.currentExposure.params.bin.height;
                    voffset = offsetArcsecs / arcsecsPerPixelV;
                }
            }
        }
    }

    // horizontal lines
    CGPathAddRect(path, nil, CGRectMake(imageWidth/2-imageWidth/2, imageHeight/2.0 - voffset, imageWidth, reticleWidth));
    CGPathAddRect(path, nil, CGRectMake(imageWidth/2-imageWidth/2, imageHeight/2.0 + voffset, imageWidth, reticleWidth));

    // vertical lines
    CGPathAddRect(path, nil, CGRectMake(imageWidth/2.0 - hoffset, imageHeight/2-imageHeight/2, reticleWidth, imageHeight));
    CGPathAddRect(path, nil, CGRectMake(imageWidth/2.0 + hoffset, imageHeight/2-imageHeight/2, reticleWidth, imageHeight));
    
    // centre spot
    CGPathAddRect(path, nil, CGRectMake(imageWidth/2.0 - 0.5, imageHeight/2 - 0.5, 1, 1));

//    CGPathAddEllipseInRect(path, nil, CGRectMake(imageWidth/2-imageHeight/2, 0, imageHeight, imageHeight));
//    CGPathAddEllipseInRect(path, nil, CGRectMake(0, imageHeight/2-imageWidth/2, imageWidth, imageWidth));

    reticleLayer.path = path;
    reticleLayer.fillColor = (__bridge CGColorRef)(CFBridgingRelease(CGColorCreateGenericRGB(0,0,0,0)));
    reticleLayer.strokeColor = (__bridge CGColorRef)(CFBridgingRelease(CGColorCreateGenericRGB(1,0,0,1)));
    reticleLayer.borderWidth = reticleWidth;
    
    CGPathRelease(path);
    
    // grab handles ?
    
    return reticleLayer;
}

- (CALayer*)createStarPositionLayerWithPosition:(CGPoint)position
{
    const CGFloat radius = 15;
    CGColorRef colour = CGColorCreateGenericRGB(1,1,0,1);
    
    CALayer* circle = [self circularRegionLayerWithPosition:position radius:radius colour:colour];
    
    [circle addSublayer:[self rectangularLayerWithPosition:CGPointMake(radius,2*radius) width:2.5 height:radius colour:colour]];
    [circle addSublayer:[self rectangularLayerWithPosition:CGPointMake(radius,0) width:2.5 height:radius colour:colour]];

    [circle addSublayer:[self rectangularLayerWithPosition:CGPointMake(0,radius) width:radius height:2.5 colour:colour]];
    [circle addSublayer:[self rectangularLayerWithPosition:CGPointMake(2*radius,radius) width:radius height:2.5 colour:colour]];

    CFBridgingRelease(colour);
    
    return circle;
}

#pragma mark - Contrast Stretch

- (void)configureContrastStretch
{
    CASImageProcessor* proc = [CASImageProcessor imageProcessorWithIdentifier:nil];
    
    const CASContrastStretchBounds bounds = [proc linearContrastStretchBoundsForExposure:self.currentExposure lowerLimit:0.005 upperLimit:0.995 maxPixelValue:1.0];
    
    self.stretchMin = bounds.lower;
    self.stretchMax = bounds.upper;
    self.contrastStretch = YES;
}

#pragma mark - Menu commands

- (NSMenu*)menuForEvent:(nonnull NSEvent *)event
{
    NSMenu* menu;
    NSURL* url = self.currentExposure.io.url;
    if (url.isFileURL){
        menu = [[NSMenu alloc] init];
        NSMenuItem* item = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Reveal in Finder", @"Reveal in Finder menu command") action:@selector(revealInFinder:) keyEquivalent:@""];
        item.target = self;
        [menu addItem:item];
    }
    return menu;
}

- (void)revealInFinder:sender
{
    NSURL* url = self.currentExposure.io.url;
    if (url.isFileURL){
        [[NSWorkspace sharedWorkspace] activateFileViewerSelectingURLs:@[url]];
    }
}

@end

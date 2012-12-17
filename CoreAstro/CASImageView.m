//
//  CASImageView.m
//  CoreAstro
//
//  Created by Simon Taylor on 9/22/12.
//  Copyright (c) 2012 Mako Technology Ltd. All rights reserved.
//

#import "CASImageView.h"

//@interface IKImageView (Private)
//- (CGRect)selectionRect; // great, a private method to get the selection...
//@end

@interface CASImageView ()
@property (nonatomic,assign) CGFloat rotationAngle, zoomFactor;
@property (nonatomic,strong) NSTrackingArea* trackingArea;
@end

@implementation CASImageView {
    BOOL _zoomToFit:1;
    BOOL _zoomToActual:1;
    CGFloat _zoomFactor;
}

- (void)awakeFromNib
{
    self.zoomFactor = 1;
}

- (void)updateTrackingAreas {
    
    if (self.trackingArea){
        [self removeTrackingArea:self.trackingArea];
        self.trackingArea = nil;
    }
    
    self.trackingArea = [[NSTrackingArea alloc] initWithRect:self.frame options:NSTrackingActiveInActiveApp|NSTrackingMouseEnteredAndExited|NSTrackingMouseMoved owner:self userInfo:nil];
    [self addTrackingArea:self.trackingArea];
}

- (CGRect)selectionRect
{
    return CGRectZero;
//    return [super selectionRect];
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

- (void)setImage:(CGImageRef)image imageProperties:(NSDictionary *)metaData
{
    [self disableAnimations:^{
        
        [super setImage:image imageProperties:metaData];
        
        if (image){
            
            if (_zoomToFit){
                [self zoomImageToFit:nil];
            }
            else if (_zoomToActual){
                [self zoomImageToActualSize:nil];
            }
            else {
                [self setZoomFactor:_zoomFactor];
            }
            
            if (self.rotationAngle){
                const CGSize size = CGSizeMake(CGImageGetWidth(image), CGImageGetHeight(image));
                const NSPoint centre = NSMakePoint(size.width/2,size.height/2);
                [self setRotationAngle:self.rotationAngle centerPoint:centre];
            }
        }
    }];
}

#define ZOOM_IN_FACTOR  1.414214
#define ZOOM_OUT_FACTOR 0.7071068

- (void)setZoomFactor:(CGFloat)zoomFactor
{
    _zoomFactor = zoomFactor;
    [super setZoomFactor:zoomFactor];
}

- (IBAction)zoomIn:(id)sender
{
    _zoomToFit = _zoomToActual = NO;
    self.zoomFactor = self.zoomFactor * ZOOM_IN_FACTOR;
}

- (IBAction)zoomOut:(id)sender
{
    _zoomToFit = _zoomToActual = NO;
    self.zoomFactor = self.zoomFactor * ZOOM_OUT_FACTOR;
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

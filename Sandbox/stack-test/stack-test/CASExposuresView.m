//
//  CASExposuresView.m
//  stack-test
//
//  Created by Simon Taylor on 21/11/2012.
//  Copyright (c) 2012 Simon Taylor. All rights reserved.
//

#import "CASExposuresView.h"
#import "CASCCDExposure.h"

@interface CASExposuresOverlayView : NSView
@property (nonatomic,weak) NSTextField* label;
@end

@implementation CASExposuresOverlayView

- (id)initWithFrame:(NSRect)frameRect
{
    self = [super initWithFrame:frameRect];
    if (self){
        
        self.wantsLayer = YES;
        self.layer.cornerRadius = 10;
        self.layer.borderWidth = 1.5;
        self.layer.borderColor = CGColorCreateGenericGray(1, 0.9);
        self.layer.backgroundColor = CGColorCreateGenericGray(0, 0.25);
        
        NSTextField* label = [[NSTextField alloc] initWithFrame:CGRectZero];
        label.autoresizingMask = NSViewWidthSizable|NSViewHeightSizable;
        label.backgroundColor = [NSColor clearColor];
        label.bordered = NO;
        label.textColor = [NSColor whiteColor];
        label.font = [NSFont boldSystemFontOfSize:32];
        label.alignment = NSCenterTextAlignment;
        label.editable = NO;
        [self addSubview:label];
        self.label = label;
    }
    return self;
}

- (void)setFrame:(NSRect)frameRect
{
    [super setFrame:frameRect];
    
    self.label.frame = CGRectInset(self.bounds, 3, 3);
}

@end

@interface CASExposuresView ()
@property (nonatomic,weak) CASExposuresOverlayView* overlayView;
@end

@implementation CASExposuresView

- (id)initWithFrame:(NSRect)frameRect
{
    self = [super initWithFrame:frameRect];
    if (self) {
        _currentExposureIndex = NSNotFound;
    }
    return self;
}

- (void)awakeFromNib
{
    _currentExposureIndex = NSNotFound;
}

- (BOOL)acceptsFirstResponder
{
    return YES;
}

- (void)setFrame:(NSRect)frameRect
{
    [super setFrame:frameRect];
    
    if (!self.overlayView){
        CASExposuresOverlayView* overlayView = [[CASExposuresOverlayView alloc] initWithFrame:NSZeroRect];
        [self addSubview:overlayView];
        self.overlayView = overlayView;
    }
    self.overlayView.frame = CGRectMake(10, CGRectGetMaxY(self.bounds) - 50 - 10, 200, 50);
}

- (CASCCDExposure*)currentExposure
{
    return [_exposures objectAtIndex:_currentExposureIndex];
}

- (void)setCurrentExposure:(CASCCDExposure *)currentExposure
{
    [self setImage:[currentExposure createImage].CGImage imageProperties:nil];
    [self addSubview:self.overlayView positioned:NSWindowAbove relativeTo:nil];
    self.overlayView.label.stringValue = [NSString stringWithFormat:@"%ld of %ld",_currentExposureIndex+1,[_exposures count]];
}

- (void)setExposures:(NSArray *)exposures
{
    _exposures = exposures;
    _currentExposureIndex= NSNotFound;
    self.currentExposureIndex = 0;
}

- (void)setCurrentExposureIndex:(NSInteger)currentExposureIndex
{
    if (![_exposures count]){
        [self setImage:nil imageProperties:nil];
        self.overlayView.label.stringValue = @"";
    }
    else {
        if (currentExposureIndex < 0){
            currentExposureIndex = 0;
        }
        else if (currentExposureIndex > [_exposures count] - 1){
            currentExposureIndex = [_exposures count] - 1;
        }
        if (currentExposureIndex != _currentExposureIndex){
            _currentExposureIndex = currentExposureIndex;
            self.currentExposure = [_exposures objectAtIndex:_currentExposureIndex];
        }
    }
}

- (NSString*)statusText
{
    return self.overlayView.label.stringValue;
}

- (void)setStatusText:(NSString *)statusText
{
    self.overlayView.label.stringValue = statusText;
}

- (IBAction)nextExposure:(id)sender
{
    self.currentExposureIndex++;
}

- (IBAction)previousExposure:(id)sender
{
    self.currentExposureIndex--;
}

- (void)moveRight:(id)sender
{
    [self nextExposure:sender];
}

- (void)moveLeft:(id)sender
{
    [self previousExposure:sender];
}

@end

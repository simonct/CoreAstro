//
//  CASHUDView.m
//  CoreAstro
//
//  Created by Simon Taylor on 12/18/12.
//  Copyright (c) 2012 Mako Technology Ltd. All rights reserved.
//

#import "CASHUDView.h"

@interface CASHUDView ()
@property (nonatomic,strong) NSProgressIndicator* spinner;
@end

@implementation CASHUDView

// title
// close button

- (id)initWithFrame:(NSRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        [self _commonSetup];
    }
    return self;
}

- (void)awakeFromNib
{
    [self _commonSetup];
}

- (void)_commonSetup
{
    self.wantsLayer = YES;
    self.layer.backgroundColor = (__bridge CGColorRef)(CFBridgingRelease(CGColorCreateGenericRGB(0,0,0,0.5)));
    self.layer.cornerRadius = 10;
    self.layer.borderWidth = 2.5;
    self.layer.borderColor = (__bridge CGColorRef)(CFBridgingRelease(CGColorCreateGenericRGB(1,1,1,0.8)));
    
    if (!self.spinner){
        self.spinner = [[NSProgressIndicator alloc] initWithFrame:CGRectZero];
        self.spinner.wantsLayer = YES;
        self.spinner.layer.backgroundColor = (__bridge CGColorRef)(CFBridgingRelease(CGColorCreateGenericRGB(1,1,1,0.5)));
        self.spinner.layer.cornerRadius = 5;
        self.spinner.usesThreadedAnimation = YES;
        self.spinner.style = NSProgressIndicatorSpinningStyle;
        self.spinner.hidden = YES;
        [self.spinner sizeToFit];
        [self addSubview:self.spinner];
    }
}

- (void)setFrame:(NSRect)frameRect
{
    [super setFrame:frameRect];
    
    CGRect frame = self.spinner.frame;
    frame.origin = CGPointMake(CGRectGetMidX(self.bounds) - CGRectGetWidth(self.spinner.frame)/2, CGRectGetMidY(self.bounds) - CGRectGetHeight(self.spinner.frame)/2);
    self.spinner.frame = frame;
}

- (void)setShowSpinner:(BOOL)showSpinner
{
    if (_showSpinner != showSpinner){
        _showSpinner = showSpinner;
        if (_showSpinner){
            self.spinner.hidden = NO;
            [self.spinner startAnimation:nil];
        }
        else {
            self.spinner.hidden = YES;
            [self.spinner stopAnimation:nil];
        }
    }
}

+ (id)loadFromNib
{
    NSArray* objects = nil;
    NSNib* nib = [[NSNib alloc] initWithNibNamed:NSStringFromClass([self class]) bundle:[NSBundle bundleForClass:[self class]]];
    [nib instantiateNibWithOwner:nil topLevelObjects:&objects];
    for (id obj in objects){
        if ([obj isKindOfClass:[self class]]){
            return obj;
        }
    }
    return nil;
}

@end

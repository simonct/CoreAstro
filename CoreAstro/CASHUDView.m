//
//  CASHUDView.m
//  CoreAstro
//
//  Created by Simon Taylor on 12/18/12.
//  Copyright (c) 2012 Mako Technology Ltd. All rights reserved.
//

#import "CASHUDView.h"

@implementation CASHUDView

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
    self.layer.backgroundColor = CGColorCreateGenericRGB(0,0,0,0.5);
    self.layer.cornerRadius = 10;
    self.layer.borderWidth = 2.5;
    self.layer.borderColor = CGColorCreateGenericRGB(1,1,1,0.8);
}

@end

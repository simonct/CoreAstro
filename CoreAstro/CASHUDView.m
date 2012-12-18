//
//  CASHUDView.m
//  CoreAstro
//
//  Created by Simon Taylor on 12/18/12.
//  Copyright (c) 2012 Mako Technology Ltd. All rights reserved.
//

#import "CASHUDView.h"

@implementation CASHUDView

// spinner
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
    self.layer.backgroundColor = CGColorCreateGenericRGB(0,0,0,0.5);
    self.layer.cornerRadius = 10;
    self.layer.borderWidth = 2.5;
    self.layer.borderColor = CGColorCreateGenericRGB(1,1,1,0.8);
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

//
//  CASProgressHUDView.m
//  CoreAstro
//
//  Created by Simon Taylor on 03/06/2017.
//  Copyright (c) 2017 Simon Taylor. All rights reserved.
//

#import "CASLabelHUDView.h"

@interface CASLabelHUDView ()
@property (nonatomic,weak) NSTextField* labelField;
@end

@implementation CASLabelHUDView

- (id)initWithFrame:(NSRect)frameRect
{
    self = [super initWithFrame:frameRect];
    if (self){
        
        // todo; same as progress hud label
        NSTextField* label = [[NSTextField alloc] initWithFrame:CGRectZero]; // strong local as property is weak
        label.autoresizingMask = NSViewWidthSizable|NSViewHeightSizable;
        label.backgroundColor = [NSColor clearColor];
        label.bordered = NO;
        label.textColor = [NSColor whiteColor];
        label.font = [NSFont boldSystemFontOfSize:18];
        label.alignment = NSLeftTextAlignment;
        label.editable = NO;
        [self addSubview:label];
        self.labelField = label;
        
        self.translatesAutoresizingMaskIntoConstraints = NO;
    }
    return self;
}

- (void)setFrame:(NSRect)frameRect
{
    [super setFrame:frameRect];
    
    CGRect bounds = CGRectInset(self.bounds, 3, 3);
    
    const CGFloat height = 40;
    
    self.labelField.frame = CGRectMake(10, CGRectGetMidY(self.bounds)-height/2-8, bounds.size.width - 10, height);
}

- (void)setLabel:(NSString *)label
{
    self.labelField.stringValue = [label copy] ?: @"";
}

@end

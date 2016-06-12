//
//  CASSimpleGraphView.h
//  CoreAstro
//
//  Created by Simon Taylor on 12/18/12.
//  Copyright (c) 2012 Mako Technology Ltd. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface CASSimpleGraphView : NSView
@property (nonatomic,assign) CGFloat max;
@property (nonatomic,strong) NSArray<NSData*>* samples; // keep history, show older ones with diminishing alpha
@property (nonatomic,strong) NSArray<NSColor*>* colours;
@property (nonatomic,assign) BOOL showLimits;
@end


//
//  CASHUDView.h
//  CoreAstro
//
//  Created by Simon Taylor on 12/18/12.
//  Copyright (c) 2012 Mako Technology Ltd. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface CASHUDView : NSView
@property (nonatomic,assign) BOOL visible;
@property (nonatomic,assign) BOOL showSpinner;
+ (id)loadFromNib;
@end

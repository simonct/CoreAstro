//
//  CASShadowView.h
//  CoreAstro
//
//  Created by Simon Taylor on 10/25/12.
//  Copyright (c) 2012 Mako Technology Ltd. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface CASShadowView : NSView
+ (void)attachToView:(NSView*)view edge:(NSRectEdge)edge;
@end

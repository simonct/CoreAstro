//
//  CASSkyMapView.h
//  skymap
//
//  Created by Simon Taylor on 24/09/2017.
//  Copyright © 2017 com.sctcode. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface CASSkyMapView : NSView

@property (class,nonatomic,assign,readonly) double limitMag;
@property (nonatomic,assign) double timeOffset;

@property (nonatomic,assign) BOOL showsRaDec;
@property (nonatomic,assign) BOOL showsAltAz;
@property (nonatomic,assign) BOOL showsScope;

- (void)setScopeRA:(double)ra dec:(double)dec;
- (void)addStarAtRA:(double)ra dec:(double)dec mag:(double)mag; // colour
@end

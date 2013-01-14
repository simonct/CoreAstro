//
//  MKOContentView.h
//  scrollview-test
//
//  Created by Simon Taylor on 10/6/12.
//  Copyright (c) 2012 Simon Taylor. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface CASZoomableView : NSView
- (IBAction)zoomIn:(id)sender;
- (IBAction)zoomOut:(id)sender;
- (void)resetContents;
@end

//
//  MKOContentView.h
//  scrollview-test
//
//  Created by Simon Taylor on 10/6/12.
//  Copyright (c) 2012 Simon Taylor. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface CASZoomableView : NSView
@property (nonatomic,assign) CGFloat zoom;
@property (nonatomic,readonly) CGRect unitFrame;
- (IBAction)zoomIn:(id)sender;
- (IBAction)zoomOut:(id)sender;
- (IBAction)zoomImageToFit:(id)sender;
- (IBAction)zoomImageToActualSize:(id)sender;
- (void)resetContents;
@end

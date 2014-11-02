//
//  CASImageView.h
//  scrollview-test
//
//  Created by Simon Taylor on 10/28/12.
//  Copyright (c) 2012 Simon Taylor. All rights reserved.
//

#import "CASZoomableView.h"

@interface CASImageView : CASZoomableView
@property (nonatomic,strong,readonly) CIImage* image;
@property (nonatomic,assign) CGImageRef CGImage;
@property (nonatomic,strong) NSURL* url;
- (void)setCGImage:(CGImageRef)CGImage resetDisplay:(BOOL)resetDisplay;
@end

typedef struct CASVector {
    CGFloat x, y;
} CASVector;

@interface CASImageView (CASImageAdjustment)
@property (nonatomic) BOOL invert;
@property (nonatomic) BOOL medianFilter;
@property (nonatomic) BOOL contrastStretch;
@property (nonatomic) float stretchMin, stretchMax, stretchGamma; // contrast stretch 0->1
@property (nonatomic) BOOL debayer;
@property (nonatomic) CASVector debayerOffset;
@property (nonatomic) BOOL showClippedPixels;
@property (nonatomic) CGRect extent;
@property (nonatomic) BOOL flipVertical, flipHorizontal;
@property (readonly) CIImage* filteredCIImage;
@end

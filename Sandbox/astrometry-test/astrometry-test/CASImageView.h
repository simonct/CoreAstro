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
@property (nonatomic,strong) NSURL* url;
@end

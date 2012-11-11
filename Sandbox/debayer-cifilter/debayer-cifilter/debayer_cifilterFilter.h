//
//  debayer_cifilterFilter.h
//  debayer-cifilter
//
//  Created by Simon Taylor on 11/11/12.
//  Copyright (c) 2012 Simon Taylor. All rights reserved.
//

#import <QuartzCore/QuartzCore.h>

@interface debayer_cifilterFilter : CIFilter {
    CIImage      *inputImage;
    CIVector     *inputOffset;
}

@end

//
//  ContrastStretchFilter.h
//  ContrastStretch
//
//  Created by Simon Taylor on 8/6/13.
//  Copyright (c) 2013 Simon Taylor. All rights reserved.
//

#import <QuartzCore/QuartzCore.h>

@interface CASContrastStretchFilter : CIFilter {
    CIImage      *inputImage;
    NSNumber     *inputMin;
    NSNumber     *inputMax;
}

@end

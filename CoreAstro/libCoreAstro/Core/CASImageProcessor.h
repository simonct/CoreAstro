//
//  CASImageProcessor.h
//  CoreAstro
//
//  Copyright (c) 2012, Simon Taylor
// 
//  Permission is hereby granted, free of charge, to any person obtaining a copy 
//  of this software and associated documentation files (the "Software"), to deal 
//  in the Software without restriction, including without limitation the rights 
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell 
//  copies of the Software, and to permit persons to whom the Software is furnished 
//  to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in 
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR 
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, 
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL 
//  THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER 
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
//  FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
//  IN THE SOFTWARE.
//

#import "CASCCDExposure.h"

// todo; make this a factory for image processor modules that can describe their actions for an exposure's history

@protocol CASImageProcessor <NSObject>
@optional

- (CASCCDExposure*)equalise:(CASCCDExposure*)exposure;
- (CASCCDExposure*)unsharpMask:(CASCCDExposure*)exposure;
- (CASCCDExposure*)medianFilter:(CASCCDExposure*)exposure;
- (CASCCDExposure*)invert:(CASCCDExposure*)exposure;
- (CASCCDExposure*)normalise:(CASCCDExposure*)exposure;

- (CASCCDExposure*)subtract:(CASCCDExposure*)darkOrBias from:(CASCCDExposure*)exposure;
- (void)divideFlat:(CASCCDExposure*)flat into:(CASCCDExposure*)exposure;

- (CASCCDExposure*)medianSum:(NSArray*)exposures;
- (CASCCDExposure*)averageSum:(NSArray*)exposures;

- (CASCCDExposure*)removeBayerMatrix:(CASCCDExposure*)exposure;

- (CASCCDExposure*)luminance:(CASCCDExposure*)exposure;

- (NSArray*)histogram:(CASCCDExposure*)exposure;

- (CGFloat)medianPixelValue:(CASCCDExposure*)exposure;
- (CGFloat)averagePixelValue:(CASCCDExposure*)exposure;
- (CGFloat)minimumPixelValue:(CASCCDExposure*)exposure;
- (CGFloat)maximumPixelValue:(CASCCDExposure*)exposure;
- (CGFloat)standardDeviationPixelValue:(CASCCDExposure*)exposure;

typedef struct {
    NSUInteger lower, upper;
    float maxPixelValue;
} CASContrastStretchBounds;
- (CASContrastStretchBounds)linearContrastStretchBoundsForExposure:(CASCCDExposure*)exposure
                                                        lowerLimit:(float)lowerLimit
                                                        upperLimit:(float)upperLimit
                                                     maxPixelValue:(float)maxPixelValue;

- (CASCCDExposure*)rescaleExposure:(CASCCDExposure*)exposure linearContrastStretchBounds:(CASContrastStretchBounds)bounds;

@end

@interface CASImageProcessor : NSObject<CASImageProcessor>

+ (id<CASImageProcessor>)imageProcessorWithIdentifier:(NSString*)ident;

@end

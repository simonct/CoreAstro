//
//  CASHalfFluxDiameter.h
//  CoreAstro
//
//  Copyright (c) 2012, Wagner Truppel
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


#import "CASFocusMetric.h"

// Used as a fraction of min(scaled width, scaled height).
#define DEFAULT_SCALED_RADIUS_TOLERANCE_FACTOR     0.0001

// Used in absolute terms.
#define DEFAULT_SCALED_BRIGHTNESS_TOLERANCE        0.00001

extern NSString* const keyScaledRadiusToleranceFactor;
extern NSString* const keyBrightnessTolerance;

@interface CASHalfFluxDiameter: CASFocusMetric

@property (readonly, nonatomic) CGPoint brightnessCentroid;

// These are used to stop the binary search. If
// not set by the client code, suitable default
// values are used.

// Default value is DEFAULT_SCALED_RADIUS_TOLERANCE_FACTOR.
@property (nonatomic) double scaledRadiusToleranceFactor;

// Default value is DEFAULT_SCALED_BRIGHTNESS_TOLERANCE.
@property (nonatomic) double scaledBrightnessTolerance;

// Computes a faster but less accurate estimate of the HFD,
// using a spiral approach.
- (double) hfdForExposureArray: (uint16_t*) values
                      ofLength: (NSUInteger) len
                       numRows: (NSUInteger) numRows
                       numCols: (NSUInteger) numCols
                        pixelW: (double) pixelW
                        pixelH: (double) pixelH
            brightnessCentroid: (CGPoint*) brightnessCentroidPtr;

@end

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


// Related to the test exposure method declared at the end of this file.
extern NSString* const keyDecayRate;
extern NSString* const keyAngularFactor;
extern NSString* const keyDistributionCenter;
// These are already declared in the superclasses.
// extern NSString* const keyNumRows;
// extern NSString* const keyNumCols;
// extern NSString* const keyNumPixels;
// extern NSString* const keyPixelW;
// extern NSString* const keyPixelH;
extern NSString* const keyExposureValues;
extern NSString* const keyExactBrightnessCentroid;
extern NSString* const keyExactTotalBrightness;
extern NSString* const keyExactHFD;


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
- (double) roughHfdForExposureArray: (float*) values
                           ofLength: (NSUInteger) len
                            numRows: (NSUInteger) numRows
                            numCols: (NSUInteger) numCols
                             pixelW: (double) pixelW
                             pixelH: (double) pixelH
                 brightnessCentroid: (CGPoint*) brightnessCentroidPtr;


// Returns a dictionary containing a test exposure discretized from the
// continuous Gaussian profile given by
//
// b(r,theta) = b0 exp(-ar^2) [ 1 + s cos(theta) ] / (1 + |s|)
//
// with b0 > 0, a > 0, and |s| <= 1, and centered at a given point.
// Note that s != 0 gives a distribution that is not circularly symmetric,
// but biased towards a point on the horizontal axis. b0 is chosen to
// equal the largest unsigned short value.
//
// The exact coordinates of the centroid in the continuous case are
// xbar = (s/2) sqrt(pi/a) + center.x and ybar = center.y.
//
// The total brightness in the continuous case is (b0/a) pi/(1 + |s|).
//
// The total brightness, in the continuous case, inside a circle of
// radius R centered at the given *center* (not the centroid!) is the total
// brightness above times the factor [1 - e^(-aR^2)].
//
// The exact HFD in the continuous case, for s = 0, is 2 sqrt[ln(2)/a].
//
// I have yet to compute the exact HFD in the continuous case for arbitrary
// values of s. The brightness distribution expressed in coordinates relative
// to the centroid is extremely complicated. I'm not sure it's even possible
// to obtain an analytical result for arbitrary values of s.
//
// The key/value pairs are:
//
// keyDecayRate: an NSNumber-boxed double representing a
// keyAngularFactor: an NSNumber-boxed double representing s
// keyDistributionCenter: an NSValue-boxed CGPoint representing
//   the center of the distribution (the point with the maximum brightness),
//   in the image coordinate system
// keyNumRows: an NSNumber-boxed NSUInteger representing numRows
// keyNumCols: an NSNumber-boxed NSUInteger representing numCols
// keyNumPixels: an NSNumber-boxed NSUInteger representing numPixels
//    (numPixels = numRows x numCols)
// keyPixelW: an NSNumber-boxed double representing pixelW
// keyPixelH: an NSNumber-boxed double representing pixelH
// keyExposureValues: an array of NSNumber-boxed unsigned short values
//    ordered appropriately
// keyExactBrightnessCentroid: an NSValue-boxed CGPoint representing
//   the exact centroid in the continuous case, measured in the image
//   coordinate system
// keyExactTotalBrightness: an NSNumber-boxed double representing
//   the exact total brightness in the continuous case
// keyExactHFD: an NSNumber-boxed double representing
//   the exact HFD in the continuous case
//
- (NSDictionary*) gaussianExposureWithDecayRate: (double) a
                                  angularFactor: (double) s
                                     centeredAt: (CGPoint) centerPt
                                        numRows: (NSUInteger) numRows
                                        numCols: (NSUInteger) numCols
                                         pixelW: (double) pixelW
                                         pixelH: (double) pixelH;

@end

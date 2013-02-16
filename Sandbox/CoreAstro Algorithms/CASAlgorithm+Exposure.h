//
//  CASAlgorithm+Exposure.h
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


#import "CASAlgorithm.h"
#import "CASCCDExposure.h"
#import "assert.h"


extern NSString* const keyExposure;

extern NSString* const keyNumRows;
extern NSString* const keyNumCols;
extern NSString* const keyNumPixels;

extern NSString* const keyThresholdingMode;
extern NSString* const keyThreshold;

extern NSString* const keyBinIndex;
extern NSString* const keyBinWidth;
extern NSString* const keyBinStart;
extern NSString* const keyBinEnd;
extern NSString* const keyBinCount;


// Specifies which value to use when thresholding the exposure array.
typedef enum
{
    kThresholdingModeNoThresholding = 0,
    kThresholdingModeUseMininum,
    kThresholdingModeUseAverage,
    kThresholdingModeUseCustomValue,

} ThresholdingMode;


// These map the lower-left corner pixel of an exposure to the integer coordinates
// (kx=0, ky=0), with kx growing to the right and ky growing upwards. These are
// not coordinates of any particular point, but coordinates of a pixel, and
// are measured with respect to the image coordinate system. Note that they're
// never negative.

NS_INLINE NSUInteger cas_alg_kx(NSUInteger numRows, NSUInteger numCols, NSUInteger p)
{
    assert(numCols != 0);
    return (p % numCols);
}

NS_INLINE NSUInteger cas_alg_ky(NSUInteger numRows, NSUInteger numCols, NSUInteger p)
{
    assert(numRows != 0 && numCols != 0);
    return ((numRows - 1) - (p / numCols));
}

NS_INLINE NSUInteger cas_alg_p(NSUInteger numRows, NSUInteger numCols, NSUInteger kx, NSUInteger ky)
{
    assert(numRows != 0 && ky < numRows);
    return (numCols * (numRows - 1 - ky) + kx);
}


// An utility function to threshold an array of exposure values.
// Any array values smaller than the threshold are reset to 0.
// No other values are changed.
//
// Note: the thresholding is done in place.
// Note: expects unsigned 16-bit values.
void cas_alg_thresh(uint16_t* values, NSUInteger len, uint16_t threshold);


// An utility function to compute a histogram from an array of exposure values.
//
// Returns an array of bin dictionaries, each containing the bin index, the start
// value of the bin, the end value of the bin, the bin width (end - start + 1),
// and the count of values in the closed interval [start, end].
//
// Note: binWidth must not be zero, or nil is returned.
// Note: expects unsigned 16-bit values.
NSArray* cas_alg_hist(uint16_t* values, NSUInteger len, uint16_t binWidth);


// An utility function to find the minimum, maximum, and average values
// of an array of exposure values. The nz variables represent values
// computed by ignoring the zero values in the array. The function needs
// at least one and at most three passes through the array to compute
// all returned values but it won't do the second or third passes if the
// caller isn't interested in the returned values that require those passes.
//
// Note: expects unsigned 16-bit values.
void cas_alg_stats(uint16_t* values, NSUInteger len,
                   uint16_t* min, NSUInteger* countOfMin,
                   uint16_t* max, NSUInteger* countOfMax,
                   double* avg, NSUInteger* countOfLessThanAvg,
                   NSUInteger* countOfAvg, NSUInteger* countOfMoreThanAvg,
                   uint16_t* nzMin, NSUInteger* countOfNzMin,
                   double* nzAvg, NSUInteger* countOfLessThanNzAvg,
                   NSUInteger* countOfNzAvg, NSUInteger* countOfMoreThanNzAvg,
                   NSUInteger* countOfNonZeroValues);


@interface CASAlgorithm (Exposure)
@end

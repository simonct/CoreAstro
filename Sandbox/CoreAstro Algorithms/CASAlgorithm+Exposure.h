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

extern NSString* const keyPixelW;
extern NSString* const keyPixelH;

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

NS_INLINE NSUInteger cas_alg_kx(const NSUInteger numRows, const NSUInteger numCols,
                                const NSUInteger p)
{
    assert(numCols != 0);
    return (p % numCols);
}

NS_INLINE NSUInteger cas_alg_ky(const NSUInteger numRows, const NSUInteger numCols,
                                const NSUInteger p)
{
    assert(numRows != 0 && numCols != 0);
    return ((numRows - 1) - (p / numCols));
}

NS_INLINE NSUInteger cas_alg_p(const NSUInteger numRows, const NSUInteger numCols,
                               const NSUInteger kx, const NSUInteger ky)
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
void cas_alg_thresh(uint16_t* const values, const NSUInteger len, const uint16_t threshold);


// An utility function to compute a histogram from an array of exposure values.
//
// Returns an array of bin dictionaries, each containing the bin index, the start
// value of the bin, the end value of the bin, the bin width (end - start + 1),
// and the count of values in the closed interval [start, end].
//
// Note: binWidth must not be zero, or nil is returned.
// Note: expects unsigned 16-bit values.
NSArray* cas_alg_hist(const uint16_t* const values, const NSUInteger len, const uint16_t binWidth);


// An utility function to find the minimum, maximum, and average values
// of an array of exposure values, as well as the total exposure. The nz
// variables represent values computed by ignoring the zero values in the
// array. The function needs at least one and at most three passes through
// the array to compute all returned values but it won't do the second or
// third passes if the caller isn't interested in the returned values that
// require those passes. Pass nil as the pointer argument to a value that
// you're not interested in.
//
// Note: expects unsigned 16-bit values.
void cas_alg_stats(const uint16_t* const values,              // the array of exposure values
                   const NSUInteger len,                      // the length of the array
                   double* const totalExposure,               // the sum of all exposure values
                   uint16_t* const min,                       // the minimum exposure value
                   NSUInteger* const countOfMin,              // how many entries have the min value
                   uint16_t* const max,                       // the maximum exposure value
                   NSUInteger* const countOfMax,              // how many entries have the max value
                   double* const avg,                         // the average exposure value
                   NSUInteger* const countOfLessThanAvg,      // how many entries have values below the average
                   NSUInteger* const countOfAvg,              // how many entries have values equal to the average
                   NSUInteger* const countOfMoreThanAvg,      // how many entries have values above the average
                   uint16_t* const nzMin,                     // same as min, ignoring zero-valued entries
                   NSUInteger* const countOfNzMin,            // same as countOfMin, ignoring zero-valued entries
                   double* const nzAvg,                       // same as avg, ignoring zero-valued entries
                   NSUInteger* const countOfLessThanNzAvg,    // same as countOfLessThanAvg, ignoring zero-valued entries
                   NSUInteger* const countOfNzAvg,            // same as countOfAvg, ignoring zero-valued entries
                   NSUInteger* const countOfMoreThanNzAvg,    // same as countOfMoreThanAvg, ignoring zero-valued entries
                   NSUInteger* const countOfNonZeroValues);   // how many entries have zero exposure values


// An utility function to find the exposure centroid,
// in the image coordinate system.
//
// Note: expects unsigned 16-bit values.
void cas_alg_exp_centroid(const uint16_t* const values,       // the array of exposure values
                          const NSUInteger len,               // the length of the array
                          const NSUInteger numRows,           // the number of rows in the exposure
                          const NSUInteger numCols,           // the number of columns in the exposure
                          const double pixelW,                // the pixel width, common to all pixels
                          const double pixelH,                // the pixel height, common to all pixels
                          double* const totalExposure,        // the sum of all exposure values
                          CGPoint* const exposureCentroid);   // the exposure centroid, in the image coord system


@interface CASAlgorithm (Exposure)
@end

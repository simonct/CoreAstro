//
//  CASAlgorithm+Exposure.m
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


#import "CASAlgorithm+Exposure.h"


NSString* const keyExposure = @"exposure";

NSString* const keyNumRows = @"num rows";
NSString* const keyNumCols = @"num cols";
NSString* const keyNumPixels = @"num pixels";

NSString* const keyThresholdingMode = @"thresholding mode";
NSString* const keyThreshold = @"threshold";

NSString* const keyBinIndex = @"bin index";
NSString* const keyBinWidth = @"bin width";
NSString* const keyBinStart = @"bin start";
NSString* const keyBinEnd   = @"bin end";
NSString* const keyBinCount = @"bin count";


// An utility function to threshold an array of exposure values.
// Any array values smaller than the threshold are reset to 0.
// No other values are changed.
//
// Note: the thresholding is done in place.
// Note: expects unsigned 16-bit values.
void cas_alg_thresh(uint16_t* const values, const NSUInteger len, const uint16_t threshold)
{
    for (NSUInteger i = 0; i < len; ++i)
    {
        if (values[i] < threshold)
        {
            values[i] = 0;
        }
    }
}


// An utility function to compute a histogram from an array of exposure values.
//
// Returns an array of bin dictionaries, each containing the bin index, the start
// value of the bin, the end value of the bin, the bin width (end - start + 1),
// and the count of values in the closed interval [start, end].
//
// Note: binWidth must not be zero, or nil is returned.
// Note: expects unsigned 16-bit values.
NSArray* cas_alg_hist(const uint16_t* const values, const NSUInteger len, const uint16_t binWidth)
{
    if (binWidth == 0) return nil;

    NSUInteger numBins = (USHRT_MAX + 1) / binWidth;
    if (numBins * binWidth < USHRT_MAX + 1)
    {
        // binWidth doesn't divide the range evenly, so
        // we need an extra bin at the end.
        numBins += 1;
    }

    NSMutableDictionary* binsMutD = [[NSMutableDictionary alloc] init];
    for (NSUInteger k = 0; k < numBins; ++k)
    {
        NSNumber* binIdx = [NSNumber numberWithUnsignedInteger: k];
        NSNumber* bwidth = [NSNumber numberWithUnsignedInteger: binWidth];
        NSNumber*  start = [NSNumber numberWithUnsignedInteger: (k * binWidth)];
        NSNumber*    end = [NSNumber numberWithUnsignedInteger: ((k+1) * binWidth - 1)];
        NSNumber*  count = [NSNumber numberWithUnsignedInteger: 0];

        NSMutableDictionary* bin = [[NSDictionary dictionaryWithObjectsAndKeys:
                                     binIdx, keyBinIndex, bwidth, keyBinWidth,
                                     start, keyBinStart, end, keyBinEnd,
                                     count, keyBinCount, nil] mutableCopy];

        [binsMutD setObject: bin forKey: binIdx];
    }

    for (NSUInteger i = 0; i < len; ++i)
    {
        // If a value falls in the bin with index k, then the value
        // is in the closed interval [k*bw, (k+1)*bw - 1]. To get k,
        // note that k*bw ≤ value ≤ (k+1)*bw - 1 implies
        // k ≤ value/bw ≤ (k+1) - 1/bw < k+1.
        // Thus, with integer arithmetic, k equals value/bw.
        NSUInteger k = values[i] / binWidth;

        NSNumber* binIdx = [NSNumber numberWithUnsignedInteger: k];
        NSMutableDictionary* bin = [binsMutD objectForKey: binIdx];

        NSUInteger count = [[bin objectForKey: keyBinCount] unsignedIntegerValue] + 1;
        [bin setObject: [NSNumber numberWithUnsignedInteger: count] forKey: keyBinCount];
    }

    NSArray* sortedBinIndices = [[binsMutD allKeys] sortedArrayUsingSelector: @selector(compare:)];
    NSMutableArray* histMutA = [[NSMutableArray alloc] initWithCapacity: [sortedBinIndices count]];

    for (NSNumber* binIdx in sortedBinIndices)
    {
        [histMutA addObject: [binsMutD objectForKey: binIdx]];
    }

    return [NSArray arrayWithArray: histMutA];
}


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
                   NSUInteger* const countOfNonZeroValues)    // how many entries have zero exposure values
{
    double totalExposureVal = 0.0;

    uint16_t minVal = USHRT_MAX;
    NSUInteger countOfMinVal = 0;

    uint16_t maxVal = 0;
    NSUInteger countOfMaxVal = 0;

    uint16_t nzMinVal = USHRT_MAX;
    NSUInteger countOfNzMinVal = 0;

    double avgVal = 0.0;
    NSUInteger countOfLessThanAvgVal = 0;
    NSUInteger countOfAvgVal = 0;
    NSUInteger countOfMoreThanAvgVal = 0;

    double nzAvgVal = 0.0;
    NSUInteger countOfLessThanNzAvgVal = 0;
    NSUInteger countOfNzAvgVal = 0;
    NSUInteger countOfMoreThanNzAvgVal = 0;

    NSUInteger countOfNonZeroVals = 0;

    for (NSUInteger i = 0; i < len; ++i)
    {
        uint16_t value = values[i];

        if (value < minVal) { minVal = value; }
        if (value > maxVal) { maxVal = value; }

        if (value != 0)
        {
            countOfNonZeroVals += 1;

            if (value < nzMinVal) { nzMinVal = value; }
        }

        avgVal += (1.0 * value) / len;
        totalExposureVal += value;
    }

    // No need to do another pass if the caller isn't interested
    // in what this pass computes.
    if (countOfMin || countOfMax || countOfNzMin ||
        countOfLessThanAvg || countOfAvg || countOfMoreThanAvg || nzAvg ||
        countOfLessThanNzAvg || countOfNzAvg || countOfMoreThanNzAvg)
    {
        for (NSUInteger i = 0; i < len; ++i)
        {
            uint16_t value = values[i];

            if (value == minVal) { countOfMinVal += 1; }
            if (value == maxVal) { countOfMaxVal += 1; }
            if (value == nzMinVal) { countOfNzMinVal += 1; }

            if (value < avgVal) { countOfLessThanAvgVal += 1; }
            if (value == avgVal) { countOfAvgVal += 1; }
            if (value > avgVal) { countOfMoreThanAvgVal += 1; }

            if (countOfNonZeroVals > 0 && value != 0)
            {
                nzAvgVal += (1.0 * value) / countOfNonZeroVals;
            }
        }
    }

    // No need to do another pass if the caller isn't interested
    // in what this pass computes.
    if (countOfLessThanNzAvg || countOfNzAvg || countOfMoreThanNzAvg)
    {
        for (NSUInteger i = 0; i < len; ++i)
        {
            uint16_t value = values[i];

            if (value < nzAvgVal) { countOfLessThanNzAvgVal += 1; }
            if (value == nzAvgVal) { countOfNzAvgVal += 1; }
            if (value > nzAvgVal) { countOfMoreThanNzAvgVal += 1; }
        }
    }

    if (totalExposure) { *totalExposure = totalExposureVal; }
    if (min) { *min = minVal; }
    if (countOfMin) { *countOfMin = countOfMinVal; }
    if (max) { *max = maxVal; }
    if (countOfMax) { *countOfMax = countOfMaxVal; }
    if (nzMin) { *nzMin = nzMinVal; }
    if (countOfNzMin) { *countOfNzMin = countOfNzMinVal; }
    if (avg) { *avg = avgVal; }
    if (countOfLessThanAvg) { *countOfLessThanAvg = countOfLessThanAvgVal; }
    if (countOfAvg) { *countOfAvg = countOfAvgVal; }
    if (countOfMoreThanAvg) { *countOfMoreThanAvg = countOfMoreThanAvgVal; }
    if (nzAvg) { *nzAvg = nzAvgVal; }
    if (countOfLessThanNzAvg) { *countOfLessThanNzAvg = countOfLessThanNzAvgVal; }
    if (countOfNzAvg) { *countOfNzAvg = countOfNzAvgVal; }
    if (countOfMoreThanNzAvg) { *countOfMoreThanNzAvg = countOfMoreThanNzAvgVal; }
    if (countOfNonZeroValues) { *countOfNonZeroValues = countOfNonZeroVals; }
}


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
                          CGPoint* const exposureCentroid)    // the exposure centroid, in the image coord system
{
    double bSum = 0.0;
    double bkxSum = 0.0;
    double bkySum = 0.0;

    for (NSUInteger p = 0; p < len; ++p)
    {
        uint16_t value = values[p];
        bSum += value;

        NSUInteger kx = cas_alg_kx(numRows, numCols, p);
        bkxSum += (kx * value);

        NSUInteger ky = cas_alg_ky(numRows, numCols, p);
        bkySum += (ky * value);
    }

    if (totalExposure) { *totalExposure = bSum; }
    
    if (exposureCentroid)
    {
        CGFloat xbar = (CGFloat) ((bkxSum / bSum) + 0.5) * pixelW;
        CGFloat ybar = (CGFloat) ((bkySum / bSum) + 0.5) * pixelH;

        *exposureCentroid = CGPointMake(xbar, ybar);
    }
}


@implementation CASAlgorithm (Exposure)
@end

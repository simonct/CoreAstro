//
//  CASRegionGrowerSegmenter.m
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


// XXX WLT TODO: merge regions that are contained within one another.


// A segmentation algorithm that finds connected regions by growing them
// from starting points, much like the bucket tool in paint programs.

// Currently supports only 16-bit images.

// The basic idea is as follows:
//
// 1. find the brightest available pixel and use it as the starting point
// to grow a connected region, ie, a set of adjacent pixels that all have
// brightness values equal to or larger than some threshold. Mark these
// pixels as unavailable.
//
// 2. go back to step 1. until there are no more available bright pixels
// to consider.
//
// 3. once all regions have been identified, compute their frame rectangles
// and brightest pixels. (this step may be accomplished while in step 1.)


#import "CASRegionGrowerSegmenter.h"
#import "CASCCDExposure.h"


@interface CASSegmenter ()

@property (readwrite, nonatomic) uint16_t threshold;
@property (readwrite, nonatomic) NSUInteger numCandidatePixels;

@end


@implementation CASRegionGrowerSegmenter

// Returns an array of CASRegion objects.
- (NSArray*) segmentExposureWithThresholdingMode: (ThresholdingMode) thresholdingMode;
{
    uint16_t* values = (uint16_t*) [self.exposure.pixels bytes];
    if (!values)
    {
        NSLog(@"%s :: Failed to load exposure array.", __FUNCTION__);
        return nil;
    }

    uint16_t threshold = 0;

    switch (thresholdingMode)
    {
        case kThresholdingModeNoThresholding:
        {
            threshold = 0;
        }
            break;

        case kThresholdingModeUseMininum:
        {
            uint16_t min;
            cas_alg_stats(values, self.numPixels,
                          NULL, // totalExposure
                          &min, // min
                          NULL, // countOfMin
                          NULL, // max
                          NULL, // countOfMax
                          NULL, // avg
                          NULL, // countOfLessThanAvg
                          NULL, // countOfAvg
                          NULL, // countOfMoreThanAvg
                          NULL, // nzMin
                          NULL, // countOfNzMin
                          NULL, // nzAvg
                          NULL, // countOfLessThanNzAvg
                          NULL, // countOfNzAvg
                          NULL, // countOfMoreThanNzAvg
                          NULL); // countOfNonZeroValues

            threshold = min;
        }
            break;

        default:
        case kThresholdingModeUseAverage:
        {
            double avg;
            cas_alg_stats(values, self.numPixels,
                          NULL, // totalExposure
                          NULL, // min
                          NULL, // countOfMin
                          NULL, // max
                          NULL, // countOfMax
                          &avg, // avg
                          NULL, // countOfLessThanAvg
                          NULL, // countOfAvg
                          NULL, // countOfMoreThanAvg
                          NULL, // nzMin
                          NULL, // countOfNzMin
                          NULL, // nzAvg
                          NULL, // countOfLessThanNzAvg
                          NULL, // countOfNzAvg
                          NULL, // countOfMoreThanNzAvg
                          NULL); // countOfNonZeroValues

            threshold = (uint16_t) floor(avg);
        }
            break;

        case kThresholdingModeUseCustomValue:
        {
            NSLog(@"%s :: case kThresholdingModeUseCustomValue should never "
                  "been reached through this method!", __FUNCTION__);

            return nil;
        }
            break;
    }

    return [self segmentExposureWithThreshold: threshold];
}


// Returns an array of CASRegion objects.
- (NSArray*) segmentExposureWithThreshold: (uint16_t) threshold;
{
    uint16_t* values = (uint16_t*) [self.exposure.pixels bytes];
    if (!values)
    {
        NSLog(@"%s :: Failed to load exposure array.", __FUNCTION__);
        return nil;
    }

    NSUInteger numRows = self.numRows;
    NSUInteger numCols = self.numCols;
    NSUInteger numPixels = self.numPixels;
    // NSLog(@"numPixels: %lu", numPixels);

    // We do this because we may have gotten a custom threshold,
    // in which case we didn't get a chance to store it before now.
    self.threshold = threshold;
    // NSLog(@"threshold: %hu", threshold);

    // Array to hold the regions we'll be creating.
    NSMutableArray* regionsA = [[NSMutableArray alloc] init];

    // A set to hold the exposure indices of pixels with
    // brightness values equal to or larger than the threshold.
    // We create this set because only these pixels are valid
    // candidates for being added to a region and there's no
    // point in iterating through the remaining pixels when we
    // know already that they're invalid. All of the pixels in
    // this set will eventually be assigned to a region, thus
    // becoming invalid candidates for subsequent regions. As
    // we add candidate pixels to a region, we remove them from
    // this set to further minimize the search space.
    NSMutableSet* candidates = [[NSMutableSet alloc] init];

    for (NSUInteger p = 0; p < numPixels; ++p)
    {
        if (self.thresholdingMode == kThresholdingModeNoThresholding || values[p] >= threshold)
        {
            [candidates addObject: [NSNumber numberWithUnsignedInteger: p]];
        }
    }

    self.numCandidatePixels = [candidates count];

    // Running region ID.
    NSUInteger curRegionID = 0;

    while ([candidates count] > 0 && [regionsA count] < self.maxNumRegions)
    {
        // NSLog(@" ");
        // NSLog(@"curRegionID: %lu", curRegionID);
        // NSLog(@"[candidates count]: %lu (%.2f%% of numPixels)", [candidates count], ((100.0 * [candidates count]) / numPixels));

        // An array to hold the pixels for the current region. This array
        // holds the pixels' indices in the exposure array, as NSNumbers.
        NSMutableArray* regionPixels = [[NSMutableArray alloc] init];

        // A stack to maintain a list of pixels to process, ie, pixels
        // that will become part of the current region. Pixels are
        // removed from this stack when they're processed.
        NSMutableArray* pixelsToProcess = [[NSMutableArray alloc] init];

        // Find the brightest pixel among the current candidates.

        uint16_t max = 0;
        NSUInteger idxOfMax = 0;

        for (NSNumber* pObj in candidates)
        {
            NSUInteger p = [pObj unsignedIntegerValue];
            uint16_t value = values[p];

            if (value > max)
            {
                max = value;
                idxOfMax = p;
            }
        }

        // (x,y) coordinates of the brightest pixel.
        NSUInteger xbp = cas_alg_kx(numRows, numCols, idxOfMax);
        NSUInteger ybp = cas_alg_ky(numRows, numCols, idxOfMax);

        // A frame for the current region. It will be updated
        // as we grow the region.
        CASRect frame = CASRectMake2(xbp, ybp, 1, 1);

        // Add the brightest pixel to the stack of pixels to process.
        NSNumber* bpObj = [NSNumber numberWithUnsignedInteger: idxOfMax];
        [pixelsToProcess addObject: bpObj];

        // While we have pixels to process, process them.
        while ([pixelsToProcess count] > 0)
        {
            // Get the last pixel from the stack of pixels to process.
            NSNumber* pObj = [pixelsToProcess lastObject];
            NSUInteger p = [pObj unsignedIntegerValue];

            // Add it to the set of pixels for the current region.
            [regionPixels addObject: pObj];

            // (x,y) coordinates of the pixel we're processing.
            NSUInteger x = cas_alg_kx(numRows, numCols, p);
            NSUInteger y = cas_alg_ky(numRows, numCols, p);

            // Update the region frame. If the pixel being processed lies
            // outside of the current frame, extend the frame to contain it.

            NSInteger blx = frame.origin.x;
            NSInteger bly = frame.origin.y;
            NSInteger brx = blx + frame.size.width - 1;
            NSInteger tly = bly + frame.size.height - 1;

            if (x < blx) { blx = x; }
            if (x > brx) { brx = x; }

            if (y < bly) { bly = y; }
            if (y > tly) { tly = y; }

            frame.origin.x = blx;
            frame.origin.y = bly;
            frame.size.width = brx - blx + 1;
            frame.size.height = tly - bly + 1;

            // Ok, we're done processing the current pixel, so
            // remove it from the set of pixels to process and
            // from the set of candidate pixels.
            [pixelsToProcess removeLastObject];
            [candidates removeObject: pObj];

            // Now add its neighbours to the set of pixels to process.
            // However, only consider pixels which are in the set of candidates.

            // Next pixel's (x,y) coordinates.
            NSInteger nx, ny;

            // Next pixel's index in the exposure array, and an NSNumber
            // to represent it as an object.
            NSUInteger np;
            NSNumber* npObj;

            if (x > 0)
            {
                // the pixel to the left of the current pixel
                nx = (x-1);
                ny = y;

                np = cas_alg_p(numRows, numCols, nx, ny);
                npObj = [NSNumber numberWithUnsignedInteger: np];

                if ([candidates containsObject: npObj])
                {
                    [pixelsToProcess addObject: npObj];
                }
            }

            if (x > 0 && y > 0)
            {
                // the pixel to the left of and below the current pixel
                nx = (x-1);
                ny = (y-1);

                np = cas_alg_p(numRows, numCols, nx, ny);
                npObj = [NSNumber numberWithUnsignedInteger: np];

                if ([candidates containsObject: npObj])
                {
                    [pixelsToProcess addObject: npObj];
                }
            }

            if (y > 0)
            {
                // the pixel below the current pixel
                nx = x;
                ny = (y-1);

                np = cas_alg_p(numRows, numCols, nx, ny);
                npObj = [NSNumber numberWithUnsignedInteger: np];

                if ([candidates containsObject: npObj])
                {
                    [pixelsToProcess addObject: npObj];
                }
            }

            if (x < self.numCols - 1 && y > 0)
            {
                // the pixel below and to the right of the current pixel
                nx = (x+1);
                ny = (y-1);

                np = cas_alg_p(numRows, numCols, nx, ny);
                npObj = [NSNumber numberWithUnsignedInteger: np];

                if ([candidates containsObject: npObj])
                {
                    [pixelsToProcess addObject: npObj];
                }
            }

            if (x < self.numCols - 1)
            {
                // the pixel to the right of the current pixel
                nx = (x+1);
                ny = y;

                np = cas_alg_p(numRows, numCols, nx, ny);
                npObj = [NSNumber numberWithUnsignedInteger: np];

                if ([candidates containsObject: npObj])
                {
                    [pixelsToProcess addObject: npObj];
                }
            }

            if (x < self.numCols - 1 && y < self.numRows - 1)
            {
                // the pixel to the right of and above the current pixel
                nx = (x+1);
                ny = (y+1);

                np = cas_alg_p(numRows, numCols, nx, ny);
                npObj = [NSNumber numberWithUnsignedInteger: np];

                if ([candidates containsObject: npObj])
                {
                    [pixelsToProcess addObject: npObj];
                }
            }

            if (y < self.numRows - 1)
            {
                // the pixel above the current pixel
                nx = x;
                ny = (y+1);

                np = cas_alg_p(numRows, numCols, nx, ny);
                npObj = [NSNumber numberWithUnsignedInteger: np];

                if ([candidates containsObject: npObj])
                {
                    [pixelsToProcess addObject: npObj];
                }
            }

            if (x > 0 && y < self.numRows - 1)
            {
                // the pixel above and to the left of the current pixel
                nx = (x-1);
                ny = (y+1);

                np = cas_alg_p(numRows, numCols, nx, ny);
                npObj = [NSNumber numberWithUnsignedInteger: np];

                if ([candidates containsObject: npObj])
                {
                    [pixelsToProcess addObject: npObj];
                }
            }
        }

        // By the time we get here, the region can't grow any further,
        // so create an object to represent it and add it to our array
        // of regions.

        // Ignore regions with not enough pixels.
        if ([regionPixels count] >= self.minNumPixelsInRegion)
        {
            CASRegion* region = [[CASRegion alloc] init];
            region.regionID = curRegionID;
            region.brightestPixelIndex = idxOfMax;
            region.brightestPixelCoords = CASPointMake(xbp, ybp);
            region.frame = frame;
            region.pixels = [NSSet setWithArray: regionPixels];

            // Add the region to the regions array.
            [regionsA addObject: region];

            // NSLog(@"region: %@", region);

            // Finally, increment curRegionID and look for the next region.
            curRegionID += 1;
        }
    }

    return [NSArray arrayWithArray: regionsA];
}

@end

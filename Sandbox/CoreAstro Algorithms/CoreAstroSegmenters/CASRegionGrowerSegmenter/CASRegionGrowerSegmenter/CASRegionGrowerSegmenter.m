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


// A segmentation algorithm that finds connected regions by growing them
// from starting points, much like the bucket tool in paint programs.

// Currently supports only 16-bit images.

// The basic idea is as follows:
//
// 1. subtract from every pixel some given threshold brightness
// (values below the threshold are reset to zero, of course).
//
// 2. find the brightest available pixel and use it as the starting point
// to grow a connected region, ie, a set of adjacent pixels that all have
// non-zero brightness values. Mark these pixels as unavailable.
//
// 3. go back to step 2. until there are no more available bright pixels
// to consider.
//
// 4. once all regions have been identified, compute their frame rectangles
// and brightest pixels. (this step may be accomplished while in step 2.)


#import "CASRegionGrowerSegmenter.h"
#import "CASCCDExposure.h"


@interface CASSegmenter ()
@property (readwrite, nonatomic) uint16_t threshold;
@end


@interface CASRegion ()

@property (readwrite, nonatomic) NSInteger regionID;
@property (readwrite, nonatomic) CASRegionPixel brightestPixel;
@property (readwrite, nonatomic) CASRect frame;
@property (readwrite, nonatomic, strong) NSSet* pixels;

@end


@interface CASRegionGrowerSegmenter (private)

- (void) checkNeighboursOfPixelAtX: (NSInteger) x
                              andY: (NSInteger) y
                            values: (uint16_t*) values
                            pixels: (CASRegionPixel*) pixels
                       curRegionID: (NSUInteger) curRegionID
                             frame: (CASRect*) curFrame
                          pixelSet: (NSMutableSet*) set;

- (void) checkPixelAtX: (NSInteger) x
                  andY: (NSInteger) y
                values: (uint16_t*) values
                pixels: (CASRegionPixel*) pixels
           curRegionID: (NSUInteger) curRegionID
                 frame: (CASRect*) curFrame
              pixelSet: (NSMutableSet*) set;

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
    self.threshold = threshold;

    NSUInteger numRows = self.numRows;
    NSUInteger numCols = self.numCols;
    NSUInteger numPixels = self.numPixels;

    uint16_t* values = (uint16_t*) [self.exposure.pixels bytes];
    if (!values)
    {
        NSLog(@"%s :: Failed to load exposure array.", __FUNCTION__);
        return nil;
    }

    CASRegionPixel* pixels = (CASRegionPixel*) malloc(numPixels * sizeof(CASRegionPixel));
    if (!pixels)
    {
        NSLog(@"%s :: Failed to allocate memory for array of %lu CASRegionPixel values.", __FUNCTION__, numPixels);
        return nil;
    }

    // Fill the pixels array with initial values.
    // Initially, all pixels are assigned to no region.
    for (NSUInteger p = 0; p < numPixels; ++p)
    {
        NSInteger x = cas_alg_X(numRows, numCols, p);
        NSInteger y = cas_alg_Y(numRows, numCols, p);

        CASRegionPixel pixel;
        pixel.indexInExposure = p;
        pixel.locationInImage = CASPointMake(x, y);
        pixel.regionID = UNASSIGNED_REGION_ID;

        pixels[p] = pixel;
    }

    NSUInteger curRegionID = 0;
    uint16_t thresh = self.threshold;

    // Array to hold the regions we'll be creating.
    NSMutableArray* mutA = [[NSMutableArray alloc] init];

    while (TRUE)
    {
        // Find the brightest pixel, skipping pixels that have
        // already been assigned to a region and taking into
        // account thresholding.

        uint16_t max = 0;
        NSUInteger idxOfMax = 0;

        for (NSUInteger p = 0; p < numPixels; ++p)
        {
            // Skip pixels already assigned to a region.
            if (pixels[p].regionID != UNASSIGNED_REGION_ID) continue;
            
            uint16_t value = values[p];

            // Apply thresholding, if needed.
            if (self.thresholdingMode != kThresholdingModeNoThresholding && thresh > 0)
            {
                if (value > thresh)
                {
                    value -= thresh;
                }
                else
                {
                    value = 0;
                }
            }
            
            if (value > max)
            {
                max = value;
                idxOfMax = p;
            }
        }

        if (max == 0)
        {
            // No more regions to grow.
            break;
        }

        // Set to hold the pixels for the region to be built.
        NSMutableSet* mutS = [[NSMutableSet alloc] init];

        // Assign a region to the brightest pixel.
        pixels[idxOfMax].regionID = curRegionID;

        // Add the brightest pixel to the region set.
        CASRegionPixel pixel = pixels[idxOfMax];
        [mutS addObject: [CASRegionPixelValue value: &pixel withObjCType: @encode(CASRegionPixel)]];

        // Check neighbours and assign the current region to any
        // neighbour that hasn't been assigned to a region yet
        // and which has a non-zero brightness value. Keep track
        // of the frame of the region as it's grown.

        NSInteger x = cas_alg_X(numRows, numCols, idxOfMax);
        NSInteger y = cas_alg_Y(numRows, numCols, idxOfMax);
        CASRect curFrame = CASRectMake2(x, y, 0, 0); // holds the frame of the region

        [self checkNeighboursOfPixelAtX: x andY: y
                                 values: values pixels: pixels
                            curRegionID: curRegionID frame: &curFrame
                               pixelSet: mutS];

        // By the time we get here, the region can't grow any further,
        // so create an object to represent it and add it to our array
        // of regions.

        // Ignore regions with not enough pixels.
        if ([mutS count] >= self.minNumPixelsInRegion)
        {
            CASRegion* region = [[CASRegion alloc] init];
            region.regionID = curRegionID;
            region.brightestPixel = pixels[idxOfMax];
            region.frame = curFrame;
            region.pixels = [NSSet setWithSet: mutS];

            // Add the region to the regions array.
            [mutA addObject: region];
        }

        // Finally, increment curRegionID and look for the next region.
        curRegionID += 1;
    }

    free(pixels);

    return [NSArray arrayWithArray: mutA];
}

@end


@implementation CASRegionGrowerSegmenter (private)

- (void) checkNeighboursOfPixelAtX: (NSInteger) x
                              andY: (NSInteger) y
                            values: (uint16_t*) values
                            pixels: (CASRegionPixel*) pixels
                       curRegionID: (NSUInteger) curRegionID
                             frame: (CASRect*) curFrame
                          pixelSet: (NSMutableSet*) set;
{
    if (x > 0)
    {
        // check pixel to the left of the current pixel
        [self checkPixelAtX: x-1 andY: y values: values pixels: pixels
                curRegionID: curRegionID frame: curFrame pixelSet: set];
    }

    if (x > 0 && y > 0)
    {
        // check pixel to the left of and below the current pixel
        [self checkPixelAtX: x-1 andY: y-1 values: values pixels: pixels
                curRegionID: curRegionID frame: curFrame pixelSet: set];
    }

    if (y > 0)
    {
        // check pixel below the current pixel
        [self checkPixelAtX: x andY: y-1 values: values pixels: pixels
                curRegionID: curRegionID frame: curFrame pixelSet: set];
    }

    if (x < self.numCols - 1 && y > 0)
    {
        // check pixel below and to the right of the current pixel
        [self checkPixelAtX: x+1 andY: y-1 values: values pixels: pixels
                curRegionID: curRegionID frame: curFrame pixelSet: set];
    }

    if (x < self.numCols - 1)
    {
        // check pixel to the right of the current pixel
        [self checkPixelAtX: x+1 andY: y values: values pixels: pixels
                curRegionID: curRegionID frame: curFrame pixelSet: set];
    }

    if (x < self.numCols - 1 && y < self.numRows - 1)
    {
        // check pixel to the right of and above the current pixel
        [self checkPixelAtX: x+1 andY: y+1 values: values pixels: pixels
                curRegionID: curRegionID frame: curFrame pixelSet: set];
    }

    if (y < self.numRows - 1)
    {
        // check pixel above the current pixel
        [self checkPixelAtX: x andY: y+1 values: values pixels: pixels
                curRegionID: curRegionID frame: curFrame pixelSet: set];
    }

    if (x > 0 && y < self.numRows - 1)
    {
        // check pixel above and to the left of the current pixel
        [self checkPixelAtX: x-1 andY: y+1 values: values pixels: pixels
                curRegionID: curRegionID frame: curFrame pixelSet: set];
    }
}


- (void) checkPixelAtX: (NSInteger) x
                  andY: (NSInteger) y
                values: (uint16_t*) values
                pixels: (CASRegionPixel*) pixels
           curRegionID: (NSUInteger) curRegionID
                 frame: (CASRect*) curFrame
              pixelSet: (NSMutableSet*) set;
{
    NSUInteger p = cas_alg_P(self.numRows, self.numCols, x, y);

    // Skip pixel if already assigned to a region.
    if (pixels[p].regionID != UNASSIGNED_REGION_ID) return;

    // Apply thresholding, if needed.

    uint16_t value = values[p];
    uint16_t thresh = self.threshold;

    if (self.thresholdingMode != kThresholdingModeNoThresholding && thresh > 0)
    {
        if (value > thresh)
        {
            value -= thresh;
        }
        else
        {
            value = 0;
        }
    }

    // Skip pixel if it's a background pixel.
    if (value == 0) return;

    // Ok, we're not skipping this pixel. Since it's a neighbour
    // of the calling pixel, we must assign it to the same region
    // and add it to the set of pixels for the current region.
    
    pixels[p].regionID = curRegionID;

    CASRegionPixel pixel = pixels[p];
    [set addObject: [CASRegionPixelValue value: &pixel withObjCType: @encode(CASRegionPixel)]];

    // Now update the region frame. If the newly added pixel
    // lies outside of the current frame, augment the frame
    // to contain it.
    
    NSInteger blx = (*curFrame).origin.x;
    NSInteger bly = (*curFrame).origin.y;
    NSInteger brx = blx + (*curFrame).size.width;
    NSInteger tly = bly + (*curFrame).size.height;

    if (x < blx) { blx = x; }
    if (x > brx) { brx = x; }

    if (y < bly) { bly = y; }
    if (y > tly) { tly = y; }

    (*curFrame).origin.x = blx;
    (*curFrame).origin.y = bly;
    (*curFrame).size.width = brx - blx;
    (*curFrame).size.height = tly - bly;

    // Finally, check *its* neighbours.
    [self checkNeighboursOfPixelAtX: x andY: y
                             values: values pixels: pixels
                        curRegionID: curRegionID frame: curFrame
                           pixelSet: set];
}

@end

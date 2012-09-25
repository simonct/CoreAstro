//
//  CASSegmenter.h
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
#import "CASAlgorithm+Exposure.h"


extern NSString* const keyNumRegions;
extern NSString* const keyRegions;
extern NSString* const keyMinNumPixelsInRegion;


#define UNASSIGNED_REGION_ID        -1

// Only makes sense in the context of a given exposure.
typedef struct
{
    NSInteger regionID;
    NSUInteger indexInExposure;
    CASPoint locationInImage;

} CASRegionPixel;


NS_INLINE NSString* NSStringFromCASRegionPixel(CASRegionPixel rp)
{
    return [NSString stringWithFormat: @"{%ld, %lu, %@}",
            rp.regionID, rp.indexInExposure, NSStringFromCASPoint(rp.locationInImage)];
}


@interface CASRegionPixelValue: NSValue
@end


// Only makes sense in the context of a given exposure.
@interface CASRegion: NSObject

@property (readonly, nonatomic) NSInteger regionID;
@property (readonly, nonatomic) CASRegionPixel brightestPixel;
@property (readonly, nonatomic) CASRect frame; // in image coordinates (origin at bottom-left corner)
@property (readonly, nonatomic, strong) NSSet* pixels; // set of NSValue-boxed CASRegionPixel structs

@end



@interface CASSegmenter: CASAlgorithm

@property (readonly, nonatomic, strong) CASCCDExposure* exposure;
@property (readonly, nonatomic, strong) NSArray* regions;

@property (readonly, nonatomic) NSUInteger numRows;
@property (readonly, nonatomic) NSUInteger numCols;
@property (readonly, nonatomic) NSUInteger numPixels;
@property (readonly, nonatomic) NSUInteger minNumPixelsInRegion;

@property (readonly, nonatomic) ThresholdingMode thresholdingMode;
@property (readonly, nonatomic) uint16_t threshold;

// For subclass use only.
// Returns an array of CASRegion objects.
// Must be overridden as this is the meat of the algorithm.
// Default implementation returns nil.
- (NSArray*) segmentExposureWithThresholdingMode: (ThresholdingMode) thresholdingMode;
- (NSArray*) segmentExposureWithThreshold: (uint16_t) threshold;

@end

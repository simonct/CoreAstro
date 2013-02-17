//
//  CASSegmenter.m
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


#import "CASSegmenter.h"


NSString* const keyMaxNumRegions = @"max number of regions";
NSString* const keyMinNumPixelsInRegion = @"min number of pixels in region";

NSString* const keyNumCandidatePixels = @"num candidate pixels";
NSString* const keyNumRegions = @"num regions";
NSString* const keyRegions = @"regions";


@interface CASSegmenter ()

@property (readwrite, nonatomic, strong) CASCCDExposure* exposure;
@property (readwrite, nonatomic, strong) NSArray* regions;

@property (readwrite, nonatomic) NSUInteger numRows;
@property (readwrite, nonatomic) NSUInteger numCols;
@property (readwrite, nonatomic) NSUInteger numPixels;

@property (readwrite, nonatomic) NSUInteger maxNumRegions;
@property (readwrite, nonatomic) NSUInteger minNumPixelsInRegion;

@property (readwrite, nonatomic) ThresholdingMode thresholdingMode;
@property (readwrite, nonatomic) uint16_t threshold;

@property (readwrite, nonatomic) NSUInteger numCandidatePixels;

@end


@implementation CASSegmenter

- (NSMutableDictionary*) resultsMutableDictionaryForDataDictionary: (NSDictionary*) dataD;
{
    id objInDataD = nil;

    // === keyExposure === //

    objInDataD = [self entryOfClass: [CASCCDExposure class]
                             forKey: keyExposure
                       inDictionary: dataD
                   withDefaultValue: nil];
    if (!objInDataD) return nil;

    CASCCDExposure* exposure = (CASCCDExposure*) objInDataD;

    if (exposure.params.bps != 16)
    {
        NSLog(@"%s :: This algorithm expects 16-bit exposures.", __FUNCTION__);
        return nil;
    }

    self.exposure = exposure;
    self.numCols = self.exposure.actualSize.width;
    self.numRows = self.exposure.actualSize.height;
    self.numPixels = self.numRows * self.numCols;

    NSMutableDictionary* resultsMutD = [[NSMutableDictionary alloc] init];
    [resultsMutD setObject: exposure forKey: keyExposure];
    [resultsMutD setObject: [NSNumber numberWithUnsignedInteger: self.numRows] forKey: keyNumRows];
    [resultsMutD setObject: [NSNumber numberWithUnsignedInteger: self.numCols] forKey: keyNumCols];
    [resultsMutD setObject: [NSNumber numberWithUnsignedInteger: self.numPixels] forKey: keyNumPixels];

    return resultsMutD;
}


- (NSDictionary*) resultsFromData: (NSDictionary*) dataD;
{
    NSMutableDictionary* resultsMutD = [self resultsMutableDictionaryForDataDictionary: dataD];
    id objInDataD = nil;

    // === keyMaxNumRegions === //

    objInDataD = [self entryOfClass: [NSNumber class]
                             forKey: keyMaxNumRegions
                       inDictionary: dataD
                   withDefaultValue: [NSNumber numberWithUnsignedInteger: NSUIntegerMax]];
    if (!objInDataD) return nil;

    self.maxNumRegions = [objInDataD unsignedIntegerValue];
    [resultsMutD setObject: objInDataD forKey: keyMaxNumRegions];

    // === keyMinNumPixelsInRegion === //

    objInDataD = [self entryOfClass: [NSNumber class]
                             forKey: keyMinNumPixelsInRegion
                       inDictionary: dataD
                   withDefaultValue: [NSNumber numberWithUnsignedInteger: 1]];
    if (!objInDataD) return nil;

    self.minNumPixelsInRegion = [objInDataD unsignedIntegerValue];
    [resultsMutD setObject: objInDataD forKey: keyMinNumPixelsInRegion];

    // === keyThresholdingMode === //

    objInDataD = [self entryOfClass: [NSNumber class]
                             forKey: keyThresholdingMode
                       inDictionary: dataD
                   withDefaultValue: [NSNumber numberWithInteger: kThresholdingModeUseAverage]];
    if (!objInDataD) return nil;

    self.thresholdingMode = [objInDataD integerValue];
    [resultsMutD setObject: objInDataD forKey: keyThresholdingMode];

    // === regions === //

    NSArray* regions = nil;

    switch (self.thresholdingMode)
    {
        case kThresholdingModeNoThresholding:
        case kThresholdingModeUseMininum:
        case kThresholdingModeUseAverage:
        {
            regions = [self segmentExposureWithThresholdingMode: self.thresholdingMode];
        }
            break;

        case kThresholdingModeUseCustomValue:
        {
            objInDataD = [self entryOfClass: [NSNumber class]
                                     forKey: keyThreshold
                               inDictionary: dataD
                           withDefaultValue: nil];
            if (!objInDataD) return nil;

            self.threshold = [objInDataD unsignedShortValue];
            regions = [self segmentExposureWithThreshold: self.threshold];
        }
            break;

        default:
        {
            NSLog(@"%s :: unknown/invalid thresholding mode ('%d') for the key '%@' in dataD dictionary.",
                  __FUNCTION__, self.thresholdingMode, keyThresholdingMode);

            return nil;
        }
            break;
    }
    
    [resultsMutD setObject: [NSNumber numberWithUnsignedShort: self.threshold] forKey: keyThreshold];

    if (regions)
    {
        self.regions = regions;

        [resultsMutD setObject: [NSNumber numberWithUnsignedInteger: self.numCandidatePixels] forKey: keyNumCandidatePixels];
        [resultsMutD setObject: [NSNumber numberWithUnsignedInteger: [regions count]] forKey: keyNumRegions];
        [resultsMutD setObject: regions forKey: keyRegions];
    }

    // =========================== //

    return [NSDictionary dictionaryWithDictionary: resultsMutD];
}


// For subclass use only.
// Returns an array of CASRegion objects.
// Must be overridden as this is the meat of the algorithm.
// Subclasses may directly access the data dictionary inherited from CASAlgorithm
// if there are extra arguments not directly passed to this method.
- (NSArray*) segmentExposureWithThresholdingMode: (ThresholdingMode) thresholdingMode;
{
    return nil;
}


// For subclass use only.
// Returns an array of CASRegion objects.
// Must be overridden as this is the meat of the algorithm.
// Subclasses may directly access the data dictionary inherited from CASAlgorithm
// if there are extra arguments not directly passed to this method.
- (NSArray*) segmentExposureWithThreshold: (uint16_t) threshold;
{
    return nil;
}


@end

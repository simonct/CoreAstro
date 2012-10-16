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

- (NSDictionary*) resultsFromData: (NSDictionary*) dataD;
{
    CASCCDExposure* exposure = nil;

    id objInDataD = [dataD objectForKey: keyExposure];
    if (!objInDataD)
    {
        NSLog(@"%s :: dataD dictionary does not contain a value for the key 'keyExposure'.",
              __FUNCTION__);
        
        return nil;
    }
    if (![objInDataD isKindOfClass: [CASCCDExposure class]])
    {
        NSLog(@"%s :: Value for key '%@' in dataD dictionary is not of class 'CASCCDExposure'.",
              __FUNCTION__, keyExposure);
        
        return nil;
    }

    exposure = (CASCCDExposure*) objInDataD;

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

    
    objInDataD = [dataD objectForKey: keyMaxNumRegions];
    if (!objInDataD)
    {
        NSLog(@"%s :: dataD dictionary does not contain a value for the key 'keyMaxNumRegions'. "
              "Will use the default value of 'NSUIntegerMax' (effectively, 'no limit').", __FUNCTION__);

        objInDataD = [NSNumber numberWithUnsignedInteger: NSUIntegerMax];
    }
    if (![objInDataD isKindOfClass: [NSNumber class]])
    {
        NSLog(@"%s :: Value for key '%@' in dataD dictionary is not of class 'NSNumber'.",
              __FUNCTION__, keyMaxNumRegions);

        return nil;
    }
    self.maxNumRegions = [objInDataD unsignedIntegerValue];
    [resultsMutD setObject: objInDataD forKey: keyMaxNumRegions];

    
    objInDataD = [dataD objectForKey: keyMinNumPixelsInRegion];
    if (!objInDataD)
    {
        NSLog(@"%s :: dataD dictionary does not contain a value for the key 'keyMinNumPixelsInRegion'. "
              "Will use the default value of 1.", __FUNCTION__);

        objInDataD = [NSNumber numberWithUnsignedInteger: 1];
    }
    if (![objInDataD isKindOfClass: [NSNumber class]])
    {
        NSLog(@"%s :: Value for key '%@' in dataD dictionary is not of class 'NSNumber'.",
              __FUNCTION__, keyMinNumPixelsInRegion);

        return nil;
    }
    self.minNumPixelsInRegion = [objInDataD unsignedIntegerValue];
    [resultsMutD setObject: objInDataD forKey: keyMinNumPixelsInRegion];

    
    objInDataD = [dataD objectForKey: keyThresholdingMode];
    if (!objInDataD)
    {
        NSLog(@"%s :: dataD dictionary does not contain a value for the key 'keyThresholdingMode'. "
              "Will use the default thresholding mode, 'kThresholdingModeUseAverage'.", __FUNCTION__);

        objInDataD = [NSNumber numberWithInteger: kThresholdingModeUseAverage];
    }
    if (![objInDataD isKindOfClass: [NSNumber class]])
    {
        NSLog(@"%s :: Value for key '%@' in dataD dictionary is not of class 'NSNumber'.",
              __FUNCTION__, keyThresholdingMode);

        return nil;
    }
    ThresholdingMode mode = (ThresholdingMode) [(NSNumber*) objInDataD integerValue];
    [resultsMutD setObject: objInDataD forKey: keyThresholdingMode];
    self.thresholdingMode = mode;

    NSArray* regions = nil;

    switch (mode)
    {
        case kThresholdingModeNoThresholding:
        case kThresholdingModeUseMininum:
        case kThresholdingModeUseAverage:
        {
            regions = [self segmentExposureWithThresholdingMode: mode];
        }
            break;

        case kThresholdingModeUseCustomValue:
        {
            objInDataD = [dataD objectForKey: keyThreshold];
            if (!objInDataD)
            {
                NSLog(@"%s :: dataD dictionary does not contain a value for the key 'keyThreshold'.",
                      __FUNCTION__);

                return nil;
            }
            if (![objInDataD isKindOfClass: [NSNumber class]])
            {
                NSLog(@"%s :: Value for key '%@' in dataD dictionary is not of class 'NSNumber'.",
                      __FUNCTION__, keyThreshold);

                return nil;
            }

            self.threshold = [(NSNumber*) objInDataD unsignedShortValue];
            regions = [self segmentExposureWithThreshold: self.threshold];
        }
            break;

        default:
        {
            NSLog(@"%s :: unknown/invalid thresholding mode ('%d') for the key '%@' in dataD dictionary.",
                  __FUNCTION__, mode, keyThreshold);

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

    return [NSDictionary dictionaryWithDictionary: resultsMutD];
}


// For subclass use only.
// Returns an array of CASRegion objects.
// Must be overridden as this is the meat of the algorithm.
// Default implementation returns nil.
- (NSArray*) segmentExposureWithThresholdingMode: (ThresholdingMode) thresholdingMode;
{
    return nil;
}


// For subclass use only.
// Returns an array of CASRegion objects.
// Must be overridden as this is the meat of the algorithm.
// Default implementation returns nil.
- (NSArray*) segmentExposureWithThreshold: (uint16_t) threshold;
{
    return nil;
}


@end

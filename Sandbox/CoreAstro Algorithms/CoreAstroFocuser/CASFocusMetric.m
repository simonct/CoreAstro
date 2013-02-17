//
//  CASFocusMetric.m
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


NSString* const keyFocusMetric = @"focus metric";
NSString* const keyBrightnessCentroid = @"brightness centroid";


@interface CASFocusMetric ()

@property (readwrite, nonatomic, strong) CASCCDExposure* exposure;
@property (readwrite, nonatomic, strong) CASRegion* region;

@property (readwrite, nonatomic) NSUInteger numRows;
@property (readwrite, nonatomic) NSUInteger numCols;
@property (readwrite, nonatomic) NSUInteger numPixels;

@property (readwrite, nonatomic) double pixelW;
@property (readwrite, nonatomic) double pixelH;

@end


@implementation CASFocusMetric

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

    // === keyRegion === //

    objInDataD = [self entryOfClass: [CASRegion class]
                             forKey: keyRegion
                       inDictionary: dataD
                   withDefaultValue: nil];
    if (!objInDataD) return nil;

    self.region = (CASRegion*) objInDataD;
    [resultsMutD setObject: objInDataD forKey: keyRegion];

    // === keyPixelW === //

    objInDataD = [self entryOfClass: [NSNumber class]
                             forKey: keyPixelW
                       inDictionary: dataD
                   withDefaultValue: nil];
    if (!objInDataD) return nil;

    self.pixelW = [(NSNumber*) objInDataD doubleValue];
    [resultsMutD setObject: objInDataD forKey: keyPixelW];

    // === keyPixelH === //

    objInDataD = [self entryOfClass: [NSNumber class]
                             forKey: keyPixelH
                       inDictionary: dataD
                   withDefaultValue: nil];
    if (!objInDataD) return nil;

    self.pixelH = [(NSNumber*) objInDataD doubleValue];
    [resultsMutD setObject: objInDataD forKey: keyPixelH];

    // === focusMetric === //

    CGPoint brightnessCentroid = CGPointMake(0, 0);
    CGFloat focusMetric = [self focusMetricForRegion: self.region
                                     inExposureArray: (uint16_t*) [self.exposure.pixels bytes]
                                            ofLength: self.numPixels
                                             numRows: self.numRows
                                             numCols: self.numCols
                                              pixelW: self.pixelW
                                              pixelH: self.pixelH
                                  brightnessCentroid: &brightnessCentroid];

    NSValue* value = [NSValue valueWithBytes: &brightnessCentroid objCType: @encode(CGPoint)];
    [resultsMutD setObject: value forKey: keyBrightnessCentroid];

    [resultsMutD setObject: [NSNumber numberWithFloat: focusMetric] forKey: keyFocusMetric];

    // =========================== //
    
    return [NSDictionary dictionaryWithDictionary: resultsMutD];
}


// Subclasses must override.
// Subclasses may directly access the data dictionary inherited from CASAlgorithm
// if there are extra arguments not directly passed to this method.
- (CGFloat) focusMetricForRegion: (CASRegion*) region
                 inExposureArray: (uint16_t*) values
                        ofLength: (NSUInteger) len
                         numRows: (NSUInteger) numRows
                         numCols: (NSUInteger) numCols
                          pixelW: (double) pixelW
                          pixelH: (double) pixelH
              brightnessCentroid: (CGPoint*) brightnessCentroidPtr;
{
    return 0.0;
}

@end

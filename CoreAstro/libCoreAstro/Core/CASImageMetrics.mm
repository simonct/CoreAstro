//
//  CASImageMetrics.m
//  CoreAstro
//
//  Copyright (c) 2013, Simon Taylor
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

#import "CASImageMetrics.h"
#import "CASCCDExposure.h"
#import "CASHalfFluxDiameter.h"

@implementation CASImageMetrics

+ (id<CASImageMetrics>)imageMetricsWithIdentifier:(NSString*)ident
{
    CASImageMetrics* result = nil;
    
    if (!ident){
        result = [[CASImageMetrics alloc] init];
    }
    else {
        // consult plugin manager for a plugin of the appropriate type and identifier
    }
    
    return result;
}

- (double)hfdForExposure:(CASCCDExposure*)exposure centroid:(CGPoint*)centroidPtr mode:(CASImageMetricsHFDMode)mode
{
    double result = 0;
    CASHalfFluxDiameter* hfd = [CASHalfFluxDiameter new];
    
    float* pixels = (float*)[exposure.floatPixels bytes];
    if (pixels){
        
        CGPoint centroid = CGPointZero;
        const CASSize size = exposure.actualSize;
        const NSInteger length = [exposure.floatPixels length];
        
        switch (mode) {
                
            case CASImageMetricsHFDModeFast:
                result = [hfd roughHfdForExposureArray:pixels
                                              ofLength:length
                                               numRows:size.height
                                               numCols:size.width
                                                pixelW:1
                                                pixelH:1
                                    brightnessCentroid:&centroid];
                break;
                
            case CASImageMetricsHFDModeAccurate:
                result = [hfd focusMetricForExposureArray:pixels
                                                 ofLength:length
                                                  numRows:size.height
                                                  numCols:size.width
                                                   pixelW:1
                                                   pixelH:1
                                       brightnessCentroid:&centroid];
                break;
        }
        
        if (centroidPtr){
            *centroidPtr = centroid;
        }
    }
    
    return result;
}

@end

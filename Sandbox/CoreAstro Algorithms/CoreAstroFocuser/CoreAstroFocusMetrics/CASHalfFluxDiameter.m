//
//  CASHalfFluxDiameter.m
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


// Uses the Half-Flux Diameter as a focus metric.

#import "CASHalfFluxDiameter.h"


@interface CASHalfFluxDiameter ()
@property (readwrite, nonatomic) CGPoint brightnessCentroid;
@end


@implementation CASHalfFluxDiameter

- (CGFloat) focusMetricForRegion: (CASRegion*) region
                 inExposureArray: (uint16_t*) values
                        ofLength: (NSUInteger) len
                         numRows: (NSUInteger) numRows
                         numCols: (NSUInteger) numCols
              brightnessCentroid: (CGPoint*) brightnessCentroidPtr;
{
    // XXX must not forget to set self.brightnessCentroid at the end!
//    self.brightnessCentroid = XXX;
//    *brightnessCentroidPtr = self.brightnessCentroid;

    return 0.0; // XXX
}

@end

//extern NSString* const keyFocusMetric;
//@interface CASFocusMetric: CASAlgorithm
//@property (readonly, nonatomic, strong) CASCCDExposure* exposure;
//@property (readonly, nonatomic, strong) CASRegion* region;
//@property (readonly, nonatomic) NSUInteger numRows;
//@property (readonly, nonatomic) NSUInteger numCols;
//@property (readonly, nonatomic) NSUInteger numPixels;
//@end


//typedef void(^CASAlgorithmCompletionBlock)(NSDictionary*);
//@interface CASAlgorithm: NSObject
//
//@property (readonly, nonatomic, strong) NSDictionary* dataD;
//@property (readonly, nonatomic) dispatch_queue_t completionQueue;
//@property (readonly, nonatomic, strong) CASAlgorithmCompletionBlock completionBlock;
//
//// For subclass use only.
//// Must be overridden as this is the meat of the algorithm.
//// The default implementation returns nil.
//- (NSDictionary*) resultsFromData: (NSDictionary*) dataD;
//
//// Utility method.
//// For subclass use only and not to be overridden.
//- (void) dispatchBlock: (CASAlgorithmCompletionBlock) block
//               toQueue: (dispatch_queue_t) queue
//                 async: (BOOL) async
//          withArgument: (NSDictionary*) resultsD;
//
//@end


//extern NSString* const keyRegion;
//@interface CASRegion: NSObject
//
//@property (nonatomic) NSUInteger regionID;
//@property (nonatomic) NSUInteger brightestPixelIndex; // index in the exposure array
//@property (nonatomic) CASPoint brightestPixelCoords; // coordinates in the exposure image
//@property (nonatomic) CASRect frame; // in image coordinates (origin at bottom-left corner)
//@property (nonatomic, strong) NSSet* pixels; // set of NSNumber-boxed indices into the exposure array
//
//@end

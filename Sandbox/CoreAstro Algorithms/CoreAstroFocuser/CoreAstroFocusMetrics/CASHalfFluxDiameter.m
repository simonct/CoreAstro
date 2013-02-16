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

@implementation CASHalfFluxDiameter

- (CGFloat) focusMetricForRegion: (CASRegion*) region
                 inExposureArray: (uint16_t*) values
                        ofLength: (NSUInteger) len
                         numRows: (NSUInteger) numRows
                         numCols: (NSUInteger) numCols;
{
    return 0.0; // XXX
}

@end

// XXX - argument params should be declared const ! (same for the other project)

// XXX here just for quick reference
//@property (nonatomic) NSUInteger regionID;
//@property (nonatomic) NSUInteger brightestPixelIndex; // index in the exposure array
//@property (nonatomic) CASPoint brightestPixelCoords; // coordinates in the exposure image
//@property (nonatomic) CASRect frame; // in image coordinates (origin at bottom-left corner)
//@property (nonatomic, strong) NSSet* pixels; // set of NSNumber-boxed indices into the exposure array

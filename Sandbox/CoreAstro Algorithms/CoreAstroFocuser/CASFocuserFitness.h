//
//  CASFocuserFitness.h
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


//  A class declaring a general interface for computing fitness values
//  for rectangular regions of an exposure.


#import "CASAlgorithm.h"
#import "CASAlgorithm+Exposure.h"
#import "CASRegion.h"


extern NSString* const keyFitness;

@interface CASFocuserFitness: CASAlgorithm

@property (readonly, nonatomic, strong) CASCCDExposure* exposure;
@property (readonly, nonatomic, strong) CASRegion* region;

@property (readonly, nonatomic) NSUInteger numRows;
@property (readonly, nonatomic) NSUInteger numCols;
@property (readonly, nonatomic) NSUInteger numPixels;

// Subclasses must override. Default returns zero.
// Subclasses may directly access the data dictionary inherited from CASAlgorithm
// if there are extra arguments not directly passed to this method.
- (CGFloat) fitnessForRegion: (CASRegion*) region
             inExposureArray: (uint16_t*) values
                    ofLength: (NSUInteger) len
                     numRows: (NSUInteger) numRows
                     numCols: (NSUInteger) numCols;

@end

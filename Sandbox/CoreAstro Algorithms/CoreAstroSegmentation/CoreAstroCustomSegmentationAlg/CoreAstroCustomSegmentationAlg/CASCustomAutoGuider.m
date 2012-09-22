//
//  CASCustomAutoGuider.m
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


#import "CASCustomAutoGuider.h"
#import "CASCustomSegmentationAlg.h"

#import "CASCCDExposure.h"


@implementation CASCustomAutoGuider

- (NSArray*) locateStars: (CASCCDExposure*) exposure;
{
    NSAssert([NSThread isMainThread], @"%s not called from the main thread!", __FUNCTION__);
    NSAssert(exposure, @"%s : exposure is nil!", __FUNCTION__);

    NSDictionary* dataD = [NSDictionary dictionaryWithObject: exposure forKey: @"keyExposure"];
    NSAssert(dataD, @"%s : dataD is nil!", __FUNCTION__);

    CASAlgorithm* alg = [[CASCustomSegmentationAlg alloc] init];
    [alg executeWithDictionary: dataD completionBlock: ^(NSDictionary* resultD) {

        // WLT-XXX Had to comment this assertion out because, otherwise, it fires.
        // Why isn't the block executing in the main thread? After all, I do dispatch
        // the block to the main thread. See CASCustomSegmentationAlg.m. Need to
        // investigate further.
        // NSAssert([NSThread isMainThread], @"completion block not called from the main thread!");

        // WLT-XXX
        NSLog(@"  dataD: %@",   dataD);
        NSLog(@"resultD: %@", resultD);

    }];

    return nil; // returning nil because the algorithm will do its thing in a
                // background thread while this method must return immediately.
}

@end
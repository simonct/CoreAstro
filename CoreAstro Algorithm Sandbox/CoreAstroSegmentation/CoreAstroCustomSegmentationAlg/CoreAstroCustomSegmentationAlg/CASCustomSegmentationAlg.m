//
//  CASCustomSegmentationAlg.m
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


#import "CASCustomSegmentationAlg.h"
#import "CASCCDExposure.h"

@implementation CASCustomSegmentationAlg


- (void) executeWithDictionary: (NSDictionary*) dataD
               completionBlock: (void(^)(NSDictionary*)) block;
{
    CASCCDExposure* exposure = nil;
    id objInDataD = [dataD objectForKey: @"keyExposure"];

    if (!objInDataD)
    {
        NSLog(@"dataD (%@) does not contain a value for the key 'keyExposure'.", dataD);
        [super executeWithDictionary: dataD completionBlock: block]; // super simply executes the block

        return;
    }

    if (![objInDataD isKindOfClass: [CASCCDExposure class]])
    {
        NSLog(@"Value (%@) for key 'keyExposure' in dataD dictionary (%@) is not of class 'CASCCDExposure'.", objInDataD, dataD);
        [super executeWithDictionary: dataD completionBlock: block]; // super simply executes the block

        return;
    }

    exposure = (CASCCDExposure*) objInDataD;

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0ul), ^{

        // WLT-XXX: perform the algorith here...
        NSDictionary* resultsD = [NSDictionary dictionary]; // XXX

        if (block)
        {
            // Upon completion, call back to the block passing the results dictionary.
            // Do it asynchronously in the main thread.

            dispatch_async(dispatch_get_main_queue(), ^{

                block(resultsD);
                
            });
        }

    });
}


@end
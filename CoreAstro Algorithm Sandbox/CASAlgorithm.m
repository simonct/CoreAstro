//
//  CASAlgorithm.m
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

@implementation CASAlgorithm


// Default implementation simply executes the completion block
// asynchronously in the main thread, passing an empty dictionary
// to the block.

- (void) executeWithDictionary: (NSDictionary*) dataD
               completionBlock: (void(^)(NSDictionary*)) block;
{
    NSLog(@"%s: This is the default implementation of this method, which executes the block "
          "passing an empty dictionary. It's most likely NOT what you meant to do...", __FUNCTION__);

    NSLog(@"%s : block == nil? %@ : dataD = %@",
          __FUNCTION__, (block ? @"NO" : @"YES"), dataD);

    if (block)
    {
        dispatch_async(dispatch_get_main_queue(), ^{

            // Call back, passing an empty dictionary.
            block([NSDictionary dictionary]);

        });
    }
}


@end
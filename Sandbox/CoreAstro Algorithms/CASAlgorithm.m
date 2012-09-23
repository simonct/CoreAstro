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


// For client use only. Not to be overridden by subclasses.
- (void) executeWithDictionary: (NSDictionary*) dataD
               completionAsync: (BOOL) async
               completionQueue: (dispatch_queue_t) queue
               completionBlock: (void(^)(NSDictionary*)) block;
{
    NSLog(@"%s : dataD = %@", __FUNCTION__, dataD);
    
    NSDictionary* resultsD = [self resultsFromData: dataD];

    [self dispatchBlock: block
                toQueue: queue
                  async: async
           withArgument: resultsD];
}


// The default implementation returns nil.
- (NSDictionary*) resultsFromData: (NSDictionary*) dataD;
{
    return nil;
}


// Utility method. Not to be overridden.
- (void) dispatchBlock: (void(^)(NSDictionary*)) block
               toQueue: (dispatch_queue_t) queue
                 async: (BOOL) async
          withArgument: (NSDictionary*) resultsD;
{
    NSLog(@"%s : block == nil? %@ : queue == NULL? %@ : async ? %@ : resultsD: %@", __FUNCTION__,
          (block ? @"NO" : @"YES"), (queue ? @"NO" : @"YES"), (async ? @"YES" : @"NO"), resultsD);

    if (block && queue)
    {
        if (async)
        {
            // dispatch async even if queue is the current queue
            dispatch_async(queue, ^{ block(resultsD); });
        }
        else
        {
            // dispatch sync only if queue is NOT the current queue
            if (queue != dispatch_get_current_queue())
            {
                dispatch_sync(queue, ^{ block(resultsD); });
            }
            else // don't dispatch but simply execute the block
                 // when queue is the current queue
            {
                block(resultsD);
            }
        }
    }
}


@end
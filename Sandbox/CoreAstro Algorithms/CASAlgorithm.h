//
//  CASAlgorithm.h
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


typedef void(^CASAlgorithmCompletionBlock)(NSDictionary*);


@interface CASAlgorithm: NSObject

@property (readonly, nonatomic, strong) NSDictionary* dataD;
@property (readonly, nonatomic) dispatch_queue_t completionQueue;
@property (readonly, nonatomic, strong) CASAlgorithmCompletionBlock completionBlock;


// A completely general interface for algorithms.
//
// Pass any kind of data to the algorithm using the 'dataD' argument. Upon
// completion (successful or not) the algorithm executes the given block in
// the given queue, synchronously or asynchronously depending on the boolean
// argument. The block can then extract from its dictionary argument a variety
// of results, such as completion booleans, error conditions, and any results
// produced by the algorithm.
//
// For client use and not to be overridden by subclasses.
- (void) executeWithDictionary: (NSDictionary*) dataD
               completionAsync: (BOOL) async
               completionQueue: (dispatch_queue_t) queue
               completionBlock: (CASAlgorithmCompletionBlock) block;


// For subclass use only.
// Must be overridden as this is the meat of the algorithm.
// The default implementation returns nil.
- (NSDictionary*) resultsFromData: (NSDictionary*) dataD;


// Utility method.
// For subclass use only and not to be overridden.
- (void) dispatchBlock: (CASAlgorithmCompletionBlock) block
               toQueue: (dispatch_queue_t) queue
                 async: (BOOL) async
          withArgument: (NSDictionary*) resultsD;


// Utility method for subclass-only use. Not to be overridden.
// Returns the entry value, if valid, or nil, if invalid.
- (id) entryOfClass: (Class) klass
             forKey: (NSString*) key
       inDictionary: (NSDictionary*) dataD
   withDefaultValue: (id) defaultValue;

@end

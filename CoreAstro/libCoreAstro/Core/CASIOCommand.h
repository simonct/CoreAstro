//
//  CASIOCommand.h
//  CoreAstro
//
//  Copyright (c) 2012, Simon Taylor
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
//  This is the base class of all CoreAstro IO Commands.

#import <Foundation/Foundation.h>

#import "CASIOTransport.h"

@interface CASIOCommand : NSObject

// serialize the command to an NSData object
- (NSData*)toDataRepresentation;

// return the response byte count
@property (nonatomic,readonly) NSInteger readSize;

// return YES if it's OK to read less than readSize
@property (nonatomic,readonly) BOOL allowsUnderrun;

// deserialize the data back into the object
- (NSError*)fromDataRepresentation:(NSData*)data;

// submit to the given transport, call block on completion (block is always called on the main thread)
- (void)submit:(id<CASIOTransport>)transport block:(void (^)(NSError*))block;

@end

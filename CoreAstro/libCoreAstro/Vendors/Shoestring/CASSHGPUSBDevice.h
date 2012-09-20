//
//  CASSHGPUSBDevice.h
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

#import "CASDevice.h"

@protocol CASGuider <NSObject>

typedef enum {
    kCASGuiderDirection_None = 0,
    kCASGuiderDirection_RAPlus,
    kCASGuiderDirection_RAMinus,
    kCASGuiderDirection_DecPlus,
    kCASGuiderDirection_DecMinus
} CASGuiderDirection;

- (void)pulse:(CASGuiderDirection)direction duration:(NSInteger)durationMS block:(void (^)(NSError*))block;

@end

@interface CASSHGPUSBDevice : CASDevice<CASGuider>

@property (nonatomic,assign) BOOL ledOn;
@property (nonatomic,assign) BOOL ledRed;
@property (nonatomic,assign) CASGuiderDirection guideDirection; // assuming only one is active at a time ?

@end


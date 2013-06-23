//
//  CASSHFCUSBDevice.h
//  CoreAstro
//
//  Copyright (c) 2013, Simon Taylor
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

typedef NS_ENUM(NSUInteger, CASFocuserDirection) {
    CASFocuserForward,
    CASFocuserReverse
};

typedef NS_ENUM(NSUInteger, CASFocuserPMWFreq) {
    CASFocuserPMWFreq1x,
    CASFocuserPMWFreq4x,
    CASFocuserPMWFreq16x
};

@protocol CASFocuserDevice <NSObject>
@property (nonatomic,assign) BOOL ledOn;
@property (nonatomic,assign) BOOL ledRed;
@property (nonatomic,assign) CGFloat motorSpeed; // 0 -> 1
@property (nonatomic,assign) CASFocuserPMWFreq pmwFreq;
- (void)pulse:(CASFocuserDirection)direction duration:(NSInteger)durationMS block:(void (^)(NSError*))block;
@end

@interface CASSHFCUSBDevice : CASDevice<CASFocuserDevice>

@end


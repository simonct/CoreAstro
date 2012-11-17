//
//  SXCCDIOCommand.h
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
//  SX CCD command set

#import "CASIOCommand.h"
#import "SXCCDDevice.h"

@class SXCCDParams;

// reset the camera
@interface SXCCDIOResetCommand : CASIOCommand
@end

// echo commmnd
@interface SXCCDIOEchoCommand : CASIOCommand
@property (nonatomic,strong) NSData* data;
@property (nonatomic,strong) NSData* response;
- (id)initWithData:(NSData*)data;
@end

// get ccd params
@interface SXCCDIOGetParamsCommand : CASIOCommand
@property (nonatomic,readonly) SXCCDParams* params;
@end

// flush the chip
@interface SXCCDIOFlushCommand : CASIOCommand
// todo; wipe/nowipe flag ?
@end

@interface SXCCDIOExposeCommand : CASIOCommand
@property (nonatomic,assign) NSInteger ms;
@property (nonatomic,assign) CASExposeParams params;
@property (nonatomic,assign) BOOL readPixels;
@property (nonatomic,readonly) NSData* pixels;
- (NSData*)postProcessPixels:(NSData*)pixels;
@end

@interface SXCCDIOExposeCommandM25C : SXCCDIOExposeCommand
@end

@interface SXCCDIOExposeCommandInterlaced : SXCCDIOExposeCommand
@property (nonatomic,strong) CASCCDExposure* biasExposure;
@end

@interface SXCCDIOReadCommand : CASIOCommand
@property (nonatomic,assign) CASExposeParams params;
@property (nonatomic,readonly) NSData* pixels;
@end

@interface SXCCDIOReadFieldCommand : SXCCDIOReadCommand
enum {
    kSXCCDIOReadFieldCommandOdd,
    kSXCCDIOReadFieldCommandEven,
    kSXCCDIOReadFieldCommandBoth
};
@property (nonatomic,assign) NSInteger field;
@end

@interface SXCCDIOCoolerCommand : CASIOCommand
@property (nonatomic,assign) BOOL on;
@property (nonatomic,assign) float centigrade;
@end
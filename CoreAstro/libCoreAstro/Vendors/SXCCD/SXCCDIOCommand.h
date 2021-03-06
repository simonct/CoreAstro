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

@class SXCCDProperties;

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
@property (nonatomic,readonly) SXCCDProperties* params;
@end

// flush the chip
@interface SXCCDIOFlushCommand : CASIOCommand
@property (nonatomic,assign) BOOL noWipe;
@property (nonatomic,assign) SXCCDIOField field;
@end

// read delayed; flushes, exposes using an internal timer and reads the pixels in one command
@interface SXCCDIOExposeCommand : CASIOCommand
@property (nonatomic,assign) NSInteger ms;
@property (nonatomic,assign) CASExposeParams params;
@property (nonatomic,assign) BOOL readPixels;
@property (nonatomic,assign) BOOL latchPixels;
@property (nonatomic,readonly) NSData* pixels;
@property (nonatomic,assign) SXCCDIOField field;
@property (nonatomic,readonly) BOOL isUnbinned;
- (NSData*)postProcessPixels:(NSData*)pixels;
@end

// specific expose command for the M25C that knows how to unpack the dual output register format
@interface SXCCDIOExposeCommandM25C : SXCCDIOExposeCommand
@end

// expose command for interlaced cameras that can de-interlace the two fields and apply an intensity correction
@interface SXCCDIOExposeCommandInterlaced : SXCCDIOExposeCommand
@property (nonatomic,assign) SXCCDIOField field;
@end

// specific expose command for the M26C that knows how to unpack the interleaved pixel format
@interface SXCCDIOExposeCommandM26C : SXCCDIOExposeCommandInterlaced
@end

// specific expose command for the Lodestar
@interface SXCCDIOExposeCommandLodestar : SXCCDIOExposeCommandInterlaced
@end

// bulk read command
@interface SXCCDIOReadCommand : CASIOCommand
@property (nonatomic,assign) CASExposeParams params;
@property (nonatomic,readonly) NSData* pixels;
@end

// reads odd, even or both fields from the ccd
@interface SXCCDIOReadFieldCommand : SXCCDIOReadCommand
@property (nonatomic,assign) NSInteger field;
@end

// get/set the ccd temperature
@interface SXCCDIOCoolerCommand : CASIOCommand
@property (nonatomic,assign) BOOL on;
@property (nonatomic,assign) float centigrade;
@end

// Star2K guide command
@interface SXCCDIOGuideCommand : CASIOCommand
enum {
    kSXCCDIOGuideCommandNone = 0,
    kSXCCDIOGuideCommandNorth = 2,
    kSXCCDIOGuideCommandSouth = 4,
    kSXCCDIOGuideCommandEast = 8,
    kSXCCDIOGuideCommandWest = 1
};
@property (nonatomic,assign) uint8_t direction;
@end

// Open/close mechanical shutter
@interface SXCCDIOShutterCommand : CASIOCommand
@property (nonatomic,assign) BOOL open;
@end


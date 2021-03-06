//
//  SXCCDDevice.h
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

#import "CASCCDDevice.h"
#import "CASCCDExposure.h"
#import "SXCCDProperties.h"

@class CASCCDExposure;

@interface SXCCDDevice : CASCCDDevice 

typedef NS_ENUM(NSInteger, SXCCDIOField) {
    kSXCCDIOFieldBoth,
    kSXCCDIOFieldOdd,
    kSXCCDIOFieldEven
};

@property (nonatomic,strong,readonly) SXCCDProperties* sensor;
@property (nonatomic,readonly) BOOL hasStar2KPort, hasCompressedPixels, hasEEPROM, hasIntegratedGuider, isInterlaced, hasShutter;
@property (nonatomic,assign) NSInteger productID;

- (void)disconnect;

- (void)reset:(void (^)(NSError*))block;

- (void)echoData:(NSData*)data block:(void (^)(NSError*,NSData*data))block;

- (void)getParams:(void (^)(NSError*,SXCCDProperties* sensor))block;

- (void)flushField:(SXCCDIOField)field wipe:(BOOL)wipe block:(void (^)(NSError*))block;

- (void)exposeWithParams:(CASExposeParams)params type:(CASCCDExposureType)type block:(void (^)(NSError*,CASCCDExposure*exposure))block;

@end


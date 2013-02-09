//
//  CASDevice.h
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
//  This is the base class of all CoreAstro CCD devices. Make this a protocol ?

#import "CASDevice.h"
#import "CASCCDProperties.h"
#import "CASCCDExposure.h"

@interface CASCCDDevice : CASDevice

@property (nonatomic,strong,readonly) CASCCDProperties* sensor;
@property (nonatomic,readonly) BOOL isColour, hasCooler;
@property (nonatomic,assign) CGFloat temperature; // temp in °C
@property (nonatomic,assign) CGFloat targetTemperature; // temp in °C
@property (nonatomic,readonly) NSInteger temperatureFrequency;
@property (nonatomic,strong) NSMutableArray* exposureTemperatures; // move to CASExposure ?

- (void)reset:(void (^)(NSError*))block;

- (void)getParams:(void (^)(NSError*,CASCCDProperties* sensor))block;

- (void)flush:(void (^)(NSError*))block;

- (void)exposeWithParams:(CASExposeParams)params type:(CASCCDExposureType)type block:(void (^)(NSError*,CASCCDExposure*exposure))block;

- (void)cancelExposure;

@end


//
//  FLICCDDevice.h
//  CoreAstro
//
//  Copyright (c) 2016, Simon Taylor
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

@interface FLICCDDevice : CASCCDDevice

- (instancetype)initWithId:(NSString*)ident path:(NSString*)path domain:(long)domain;

@property (copy,readonly) NSString* fli_ident;
@property (copy,readonly) NSString* fli_path;
@property (copy,readonly) NSString* fli_model;
@property (copy,readonly) NSString* fli_serial;
@property (readonly) NSInteger fli_domain;
@property (readonly) NSInteger fli_status;
@property (readonly) NSInteger fli_hwVersion, fli_fwVersion;
@property (readonly) double fli_ccdTemp, fli_coolerPower;
@property (readonly) CGSize fli_pixelSize;
@property (readonly) CGRect fli_area;
@property (readonly) NSString* fli_pixelSizeString;
@property (readonly) NSString* fli_areaString;

@end

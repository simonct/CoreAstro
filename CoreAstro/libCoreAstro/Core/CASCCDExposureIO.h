//
//  CASCCDExposureIO.h
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

#import "CASCCDExposure.h"

@interface CASCCDExposureIO : NSObject

@property (nonatomic,copy) NSURL* url;

+ (CASCCDExposureIO*)exposureIOWithPath:(NSString*)path;

+ (CASCCDExposure*)exposureWithPath:(NSString*)path readPixels:(BOOL)readPixels error:(NSError**)error;
+ (void)enumerateExposuresWithURL:(NSURL*)url block:(void(^)(CASCCDExposure*,BOOL*))block;

+ (BOOL)writeExposure:(CASCCDExposure*)exposure toPath:(NSString*)path error:(NSError**)error;

+ (NSString*)defaultFilenameForExposure:(CASCCDExposure*)exposure;

+ (NSString*)sanitizeExposurePath:(NSString*)path;

@property (nonatomic,readonly) NSImage* thumbnail;

- (BOOL)writeExposure:(CASCCDExposure*)exposure writePixels:(BOOL)writePixels error:(NSError**)error;
- (BOOL)readExposure:(CASCCDExposure*)exposure readPixels:(BOOL)readPixels error:(NSError**)error;
- (BOOL)deleteExposure:(CASCCDExposure*)exposure error:(NSError**)error;

- (NSURL*)derivedDataURLForName:(NSString*)name;

@end

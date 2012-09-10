//
//  CASCCDExposure.h
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

#import "CASCCDParams.h"
#import "CASCCDImage.h"

@class SXCCDDevice;
@class CASCCDExposureIO;
#import "SXCCDDevice.h" // -> CASCCDDevice
#import "CASScriptableObject.h"

@interface CASCCDExposure : CASScriptableObject

// represents the raw pixels of an exposure, contains metadata describing the source camera and exposure settings. saves the data to a persistent store

@property (nonatomic,strong) NSData* pixels;
@property (nonatomic,readonly) BOOL hasPixels;
@property (nonatomic,strong) NSDictionary* meta;
@property (nonatomic,readonly) BOOL hasMeta;
@property (nonatomic,assign) CASExposeParams params;

@property (nonatomic,readonly) CASSize actualSize; // frame.size / bin.size

@property (nonatomic,readonly) NSDate* date;
@property (nonatomic,readonly) NSString* displayDate;
@property (nonatomic,readonly) NSString* displayExposure;
@property (nonatomic,readonly) NSURL* persistentStoreURL;

@property (nonatomic,readonly) NSString* uuid;
@property (nonatomic,readonly) NSString* deviceID;

@property (nonatomic,strong) CASCCDExposureIO* io;

typedef enum {
    kCASCCDExposureLightType,
    kCASCCDExposureDarkType,
    kCASCCDExposureBiasType,
    kCASCCDExposureFlatType
} CASCCDExposureType;

@property (nonatomic,assign) CASCCDExposureType type;

@property (nonatomic,strong) NSString* note;

- (CASCCDImage*)createImage;
- (CASCCDImage*)createBlankImageWithSize:(CASSize)size;

- (void)reset;

// enumerateExposuresWithBlock

- (void)deleteExposure;

+ (id)exposureWithPixels:(NSData*)pixels camera:(SXCCDDevice*)camera params:(CASExposeParams)params time:(NSDate*)time;

@end
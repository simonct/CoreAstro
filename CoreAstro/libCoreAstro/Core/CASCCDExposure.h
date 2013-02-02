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

#import "CASCCDProperties.h"
#import "CASCCDImage.h"
#import "CASScriptableObject.h"

@class CASCCDDevice, CASCCDExposureIO;

@interface CASCCDExposure : CASScriptableObject<NSCopying>

// represents the raw pixels of an exposure, contains metadata describing the source camera and exposure settings. saves the data to a persistent store

@property (nonatomic,strong) NSData* pixels; // original 16-bit unsigned int samples
@property (nonatomic,strong) NSData* floatPixels; // float values rescaled to 0.0-1.0 for better compatibility with vImage, CoreImage, etc

@property (nonatomic,readonly) BOOL hasPixels;
@property (nonatomic,strong) NSDictionary* meta;
@property (nonatomic,readonly) BOOL hasMeta;
@property (nonatomic,assign) CASExposeParams params;
@property (nonatomic,readonly) BOOL isSubframe;
@property (nonatomic,readonly) NSInteger maxPixelValue;

@property (nonatomic,readonly) BOOL rgba;
@property (nonatomic,readonly) CASSize actualSize; // frame.size / bin.size

@property (nonatomic,readonly) NSDate* date;
@property (nonatomic,readonly) NSInteger exposureMS;

@property (nonatomic,copy) NSString* displayName;
@property (nonatomic,readonly) NSString* displayDate;
@property (nonatomic,readonly) NSString* displayExposure;
@property (nonatomic,readonly) NSString* displayDeviceName;
@property (nonatomic,readonly) NSString* displayType;

@property (nonatomic,readonly) NSURL* persistentStoreURL;

@property (nonatomic,readonly) NSString* uuid;
@property (nonatomic,readonly) NSString* deviceID;

@property (nonatomic,readonly) NSImage* thumbnail;

@property (nonatomic,strong) CASCCDExposureIO* io;

typedef enum {
    kCASCCDExposureLightType,
    kCASCCDExposureDarkType,
    kCASCCDExposureBiasType,
    kCASCCDExposureFlatType
} CASCCDExposureType;

@property (nonatomic,assign) CASCCDExposureType type;

typedef enum CASCCDExposureFormat {
    kCASCCDExposureFormatUInt16 = 0,
    kCASCCDExposureFormatFloat = 1,
    kCASCCDExposureFormatFloatRGBA = 2
} CASCCDExposureFormat;

@property (nonatomic,assign) CASCCDExposureFormat format;

@property (nonatomic,strong) NSString* note;

- (CASCCDImage*)newImage;
- (CASCCDImage*)newBlankImageWithSize:(CASSize)size;

- (CASCCDExposure*)subframeWithRect:(CASRect)rect;

- (void)reset;

- (void)deleteExposure;

+ (id)exposureWithPixels:(NSData*)pixels camera:(CASCCDDevice*)camera params:(CASExposeParams)params time:(NSDate*)time;
+ (id)exposureWithFloatPixels:(NSData*)pixels camera:(CASCCDDevice*)camera params:(CASExposeParams)expParams time:(NSDate*)time;
+ (id)exposureWithRGBAFloatPixels:(NSData*)pixels camera:(CASCCDDevice*)camera params:(CASExposeParams)expParams time:(NSDate*)time;

+ (id)exposureWithTestStars:(NSArray*)stars params:(CASExposeParams)expParams;

@end

@interface CASCCDExposure (DerivedData)

@property (nonatomic,readonly) CASCCDExposure* normalisedExposure;
@property (nonatomic,readonly) CASCCDExposure* correctedExposure;
@property (nonatomic,readonly) CASCCDExposure* debayeredExposure;

extern NSString* const kCASCCDExposureNormalisedKey;
extern NSString* const kCASCCDExposureCorrectedKey;
extern NSString* const kCASCCDExposureDebayeredKey;
extern NSString* const kCASCCDExposurePlateSolutionKey;

- (CASCCDExposure*)derivedExposureWithIdentifier:(NSString*)identifier;

@end

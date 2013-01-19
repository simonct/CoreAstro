//
//  CASCCDExposure.m
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
#import "CASCCDExposureIO.h"
#import "CASCCDDevice.h"
#import "CASUtilities.h"
#import <Accelerate/Accelerate.h>
#import <QuartzCore/QuartzCore.h>

@interface CASCCDExposure ()
@property (nonatomic) BOOL rgba;
@end

@implementation CASCCDExposure {
    NSData* _pixels;
    NSData* _floatPixels;
    NSDictionary* _meta;
    enum {
        kCASCCDExposureReadMeta = 1,
        kCASCCDExposureReadPixels
    };
    NSInteger _readState;
}

- (id)copyWithZone:(NSZone *)zone
{
    CASCCDExposure* result = nil;
    NSMutableData* floatPixels = [NSMutableData dataWithLength:[self.floatPixels length]];
    if ([floatPixels mutableBytes]){
        memcpy([floatPixels mutableBytes], [self.floatPixels bytes], [self.floatPixels length]);
        result = [CASCCDExposure exposureWithFloatPixels:floatPixels camera:nil params:self.params time:[NSDate date]];
        result.meta = [[NSDictionary alloc] initWithDictionary:self.meta copyItems:YES]; // or serialize/deserialize
        result.rgba = self.rgba;
    }
    return result;
}

- (NSDate*) date
{
    return [NSDate dateWithTimeIntervalSinceReferenceDate:[[self.meta objectForKey:@"time"] doubleValue]];
}

- (NSInteger) exposureMS
{
    return self.params.ms;
}

- (NSString*)uuid
{
    return [self.meta objectForKey:@"uuid"];
}

- (NSString*)deviceID
{
    return [self.meta valueForKeyPath:@"device.deviceID"];
}

- (NSImage*) thumbnail
{
    return self.io.thumbnail;
}

- (NSString*) displayName
{
    NSString* displayName = [self.meta objectForKey:@"displayName"];
    if (!displayName){
        displayName = self.displayDeviceName;
    }
    return displayName;
}

- (void)setDisplayName:(NSString *)displayName
{
    [self setMetaObject:displayName forKey:@"displayName"];
}

- (NSString*) displayType
{
    switch (self.type) {
        case kCASCCDExposureLightType:
            return @"Light";
        case kCASCCDExposureDarkType:
            return @"Dark";
        case kCASCCDExposureBiasType:
            return @"Bias";
        case kCASCCDExposureFlatType:
            return @"Flat";
    }
    return nil;
}

- (NSString*) displayDate
{
    static NSDateFormatter* dateFormatter = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        dateFormatter = [[NSDateFormatter alloc] init];
        dateFormatter.dateStyle = kCFDateFormatterMediumStyle;
        dateFormatter.timeStyle = kCFDateFormatterMediumStyle;
    });
    return [dateFormatter stringFromDate:self.date];
}

- (NSString*) displayExposure
{
    static NSNumberFormatter* numberFormatter = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        numberFormatter = [[NSNumberFormatter alloc] init];
        numberFormatter.numberStyle = NSNumberFormatterDecimalStyle;
        numberFormatter.generatesDecimalNumbers = YES;
        numberFormatter.minimumFractionDigits = 0;
        numberFormatter.maximumFractionDigits = 3;
    });
    return [NSString stringWithFormat:@"%@s",[numberFormatter stringFromNumber:[NSNumber numberWithDouble:self.params.ms/1000.0]]];
}

- (NSString*)displayDeviceName
{
    return [self.meta valueForKeyPath:@"device.name"];
}

- (CASSize)actualSize
{
    if (!self.params.bin.width || !self.params.bin.height){
        return CASSizeMake(0, 0);
    }
    return CASSizeMake(self.params.size.width / self.params.bin.width, self.params.size.height / self.params.bin.height);
}

- (void)readFromPersistentStore:(BOOL)readPixels
{
    @synchronized(self){
        
        if (_readState == kCASCCDExposureReadPixels){
            return;
        }
        if (!readPixels && _readState == kCASCCDExposureReadMeta){
            return;
        }
        _readState = readPixels ? kCASCCDExposureReadPixels : kCASCCDExposureReadMeta;
        [self.io readExposure:self readPixels:readPixels error:nil];
    }
}

- (NSData*)pixels
{
    [self readFromPersistentStore:YES];
    return _pixels;
}

- (NSData*)floatPixels
{
    @synchronized(self){
        
        if (!_floatPixels){
            
            NSData* pixels = self.pixels;
            if (pixels){
                
                //const NSTimeInterval duration = CASTimeBlock(^{
                
                const NSInteger count = [pixels length] / sizeof(uint16_t);
                float* fp = malloc(count * sizeof(float));
                if (!fp){
                    NSLog(@"*** Out of memory converting to float pixels");
                }
                else{
                    vDSP_vfltu16((uint16_t*)[pixels bytes],1,fp,1,count);
                    const float max = self.maxPixelValue;
                    vDSP_vsdiv(fp,1,(float*)&max,fp,1,count);
                    _floatPixels = [NSData dataWithBytesNoCopy:fp length:(count * sizeof(float))];
                }
                //});
                // NSLog(@"floatPixels: %fs",duration);
            }
        }
    }
    return _floatPixels;
}

- (BOOL)hasPixels
{
    return (_pixels != nil);
}

- (NSDictionary*)meta
{
    [self readFromPersistentStore:NO];
    return _meta;
}

- (BOOL)hasMeta
{
    return (_meta != nil);
}

- (void)setMeta:(NSDictionary *)meta
{
    if (meta != _meta){
        _meta = meta;
        if (_meta){
            self.params = CASExposeParamsFromNSString([_meta objectForKey:@"exposure"]);
        }
    }
}

- (CASExposeParams)params
{
    [self readFromPersistentStore:NO];
    return _params;
}

- (BOOL)isSubframe
{
    const CASExposeParams p = self.params;
    return (p.origin.x != 0 || p.origin.y != 0 || p.size.width != p.frame.width || p.size.height != p.frame.height);
}

- (NSInteger) maxPixelValue
{
    return 65535;
}

- (void)setMetaObject:(id)obj forKey:(id)key
{
    // update meta
    NSMutableDictionary* m = [NSMutableDictionary dictionaryWithDictionary:self.meta];
    if (!obj){
        [m removeObjectForKey:key];
    }
    else {
        [m setObject:obj forKey:key];
    }
    self.meta = [m copy];
    
    // save the changes
    [self.io writeExposure:self writePixels:NO error:nil];
}

- (CASCCDExposureType)type
{
    return (CASCCDExposureType)[[self.meta objectForKey:@"type"] integerValue];
}

- (void)setType:(CASCCDExposureType)type
{
    [self setMetaObject:[NSNumber numberWithInteger:type] forKey:@"type"];
}

- (CASCCDExposureFormat) format
{
    return (CASCCDExposureFormat)[[self.meta objectForKey:@"format"] integerValue];
}

- (NSString*)note
{
    return [self.meta objectForKey:@"note"];
}

- (void)setNote:(NSString *)note
{
    [self setMetaObject:note forKey:@"note"];
}

- (CASCCDImage*)newImage
{
    if (!self.floatPixels){
        NSLog(@"-createImage: no pixels");
        return nil;
    }

    return [CASCCDImage newImageWithPixels:self.floatPixels size:CASSizeMake(self.params.size.width/self.params.bin.width, self.params.size.height/self.params.bin.height) rgba:self.rgba];
}

- (CASCCDImage*)newBlankImageWithSize:(CASSize)size
{
    return [CASCCDImage newImageWithPixels:nil size:size rgba:NO];
}

- (CASCCDExposure*)subframeWithRect:(CASRect)rect // rect is assumed to be in full frame co-ords
{
    // not currently supporting subframes of subframes
//    NSParameterAssert(self.params.origin.x == 0 && self.params.origin.y == 0);
//    NSParameterAssert(self.params.size.width == self.params.frame.width && self.params.size.height == self.params.frame.height);

    if (!self.floatPixels){
        return nil;
    }
    if (rect.size.width < 1 || rect.size.height < 1){
        return nil;
    }

    NSData* subframePixels = [NSMutableData dataWithLength:rect.size.width*rect.size.height*sizeof(float)]; // bin size
    if (!subframePixels){
        return nil;
    }
    
    const CASSize size = self.params.size;
    const CASPoint origin = self.params.origin;

    rect.origin.x = MAX(rect.origin.x - origin.x,0);
    rect.origin.y = MAX(rect.origin.y - origin.y,0);
    rect.size.width = MIN(rect.size.width,size.width);
    rect.size.height = MIN(rect.size.height,size.height);

    if (rect.origin.x + rect.size.width > size.width){
        rect.origin.x = size.width - rect.size.width;
    }
    if (rect.origin.y + rect.size.height > size.height){
        rect.origin.y = size.height - rect.size.height;
    }
    
    CASExposeParams params = self.params;
    params.origin = rect.origin;
    params.size = rect.size;
    CASCCDExposure* subframe = [CASCCDExposure exposureWithPixels:nil camera:nil params:params time:[NSDate date] floatPixels:YES rgba:self.rgba];
    
    const CASSize actualSize = self.actualSize;

    CASRect scaledRect = rect;
    scaledRect.size.width /= self.params.bin.width;
    scaledRect.size.height /= self.params.bin.height;
    scaledRect.origin.x /= self.params.bin.width;
    scaledRect.origin.y /= self.params.bin.height;

    float* floatPixels = scaledRect.origin.x + (scaledRect.origin.y * actualSize.width) + (float*)[self.floatPixels bytes];
    float* subframeFloatPixels = (float*)[subframePixels bytes];
    
    for (NSInteger y = 0; y < scaledRect.size.height; ++y, subframeFloatPixels += scaledRect.size.width, floatPixels += actualSize.width){
        memcpy(subframeFloatPixels, floatPixels, scaledRect.size.width*sizeof(float));
    }
    
    subframe.floatPixels = subframePixels;
    
    // todo; meta updates if appropriate
    
    return subframe;
}

- (void)reset
{
    @synchronized(self){
        if (self.io){
            self.pixels = nil;
            self.floatPixels = nil;
            _readState = _meta ? kCASCCDExposureReadMeta : 0;
        }
    }
}

- (void)deleteExposure
{
    [self.io deleteExposure:self error:nil];
}

- (NSString*) description;
{
    NSMutableString* mutStr = [[NSMutableString alloc] init];

    [mutStr appendFormat: @"hasPixels: %@\r", (self.hasPixels ? @"YES" : @"NO")];

    [mutStr appendFormat: @"hasMeta: %@\r", (self.hasMeta ? @"YES" : @"NO")];
    if (self.hasMeta)
    {
        [mutStr appendFormat: @"meta: %@\r", self.meta];
    }

    NSDictionary* paramsD = [NSDictionary dictionaryWithObjectsAndKeys:
                             [NSNumber numberWithDouble: self.params.bin.width], @"bin.width",
                             [NSNumber numberWithDouble: self.params.bin.height], @"bin.height",
                             [NSNumber numberWithDouble: self.params.origin.x], @"origin.x",
                             [NSNumber numberWithDouble: self.params.origin.y], @"origin.y",
                             [NSNumber numberWithDouble: self.params.size.width], @"size.width",
                             [NSNumber numberWithDouble: self.params.size.height], @"size.height",
                             [NSNumber numberWithDouble: self.params.frame.width], @"frame.width",
                             [NSNumber numberWithDouble: self.params.frame.height], @"frame.height",
                             [NSNumber numberWithUnsignedInteger: self.params.bps], @"bps",
                             [NSNumber numberWithUnsignedInteger: self.params.ms], @"ms",
                             nil];
    [mutStr appendFormat: @"params: %@\r", paramsD];

    NSDictionary* actualSizeD = [NSDictionary dictionaryWithObjectsAndKeys:
                                 [NSNumber numberWithDouble: self.actualSize.width], @"actualSize.width",
                                 [NSNumber numberWithDouble: self.actualSize.height], @"actualSize.height",
                                 nil];
    [mutStr appendFormat: @"actualSize: %@\r", actualSizeD];

    [mutStr appendFormat: @"displayDate: %@\r", self.displayDate];
    [mutStr appendFormat: @"displayExposure: %@\r", self.displayExposure];
    [mutStr appendFormat: @"persistentStoreURL: %@\r", self.persistentStoreURL];
    [mutStr appendFormat: @"uuid: %@\r", self.uuid];
    [mutStr appendFormat: @"deviceID: %@\r", self.deviceID];

    return [NSString stringWithString: mutStr];
}

+ (id)exposureWithPixels:(NSData*)pixels camera:(CASCCDDevice*)camera params:(CASExposeParams)expParams time:(NSDate*)time floatPixels:(BOOL)floatPixels rgba:(BOOL)rgba
{
    CASCCDExposure* exp = [[CASCCDExposure alloc] init];
    
    exp.rgba = rgba;
    
    if (floatPixels){
        exp.floatPixels = pixels;
    }
    else {
        exp.pixels = pixels;
    }
    exp.params = expParams;

    NSMutableDictionary* deviceMeta = [NSMutableDictionary dictionaryWithCapacity:3];
        
    if (camera.deviceName){
        [deviceMeta setObject:camera.deviceName forKey:@"name"];
    }
    if (camera.vendorName){
        [deviceMeta setObject:camera.vendorName forKey:@"vendor"];
    }
    if (camera.serialNumber){
        [deviceMeta setObject:camera.serialNumber forKey:@"serialNumber"];
    }
    if (camera.uniqueID){
        [deviceMeta setObject:camera.uniqueID forKey:@"deviceID"];
    }
    NSDictionary* cameraParams = [camera.sensor cas_propertyValues];
    if (cameraParams){
        [deviceMeta setObject:cameraParams forKey:@"params"];
    }
    
    NSMutableDictionary* meta = [NSMutableDictionary dictionaryWithCapacity:2];
    
    [meta setObject:deviceMeta forKey:@"device"];
    [meta setObject:[NSNumber numberWithDouble:[time timeIntervalSinceReferenceDate]] forKey:@"time"];
    [meta setObject:NSStringFromCASExposeParams(expParams) forKey:@"exposure"];
    
    NSInteger format = kCASCCDExposureFormatUInt16;
    if (floatPixels){
        if (rgba){
            format = kCASCCDExposureFormatFloatRGBA;
        }
        else {
            format = kCASCCDExposureFormatFloat;
        }
    }
    [meta setObject:[NSNumber numberWithInteger:format] forKey:@"format"];
    
    if (camera.hasCooler){
        NSMutableDictionary* temp = [NSMutableDictionary dictionaryWithCapacity:2];
        [temp setObject:[NSNumber numberWithInteger:camera.temperatureFrequency] forKey:@"frequency"];
        [temp setObject:camera.exposureTemperatures forKey:@"temperatures"];
        [meta setObject:temp forKey:@"temperature"];
    }

    CFUUIDRef uuid = CFUUIDCreate(NULL);
    CFStringRef uuids = CFUUIDCreateString(NULL, uuid);
    [meta setObject:(__bridge NSString*)uuids forKey:@"uuid"];
    CFRelease(uuid);
    CFRelease(uuids);

    const CASExposeParams check = CASExposeParamsFromNSString([meta objectForKey:@"exposure"]);;
    NSAssert(memcmp(&expParams, &check, sizeof check) == 0,@"CASExposeParams check failed");
    exp.meta = meta;
    
    return exp;
}

+ (id)exposureWithPixels:(NSData*)pixels camera:(CASCCDDevice*)camera params:(CASExposeParams)expParams time:(NSDate*)time
{
    return [[self class] exposureWithPixels:pixels camera:camera params:expParams time:time floatPixels:NO rgba:NO];
}

+ (id)exposureWithFloatPixels:(NSData*)pixels camera:(CASCCDDevice*)camera params:(CASExposeParams)expParams time:(NSDate*)time
{
    return [[self class] exposureWithPixels:pixels camera:camera params:expParams time:time floatPixels:YES rgba:NO];
}

+ (id)exposureWithRGBAFloatPixels:(NSData*)pixels camera:(CASCCDDevice*)camera params:(CASExposeParams)expParams time:(NSDate*)time
{
    return [[self class] exposureWithPixels:pixels camera:camera params:expParams time:time floatPixels:YES rgba:YES];
}

+ (id)exposureWithTestStars:(NSArray*)stars params:(CASExposeParams)expParams
{
    const CGFloat kCASStarRadius = 2.5;
    const CGSize size = CGSizeMake(expParams.size.width/expParams.bin.width, expParams.size.height/expParams.bin.height);
    const CGFloat radius = 1;
    
    CGContextRef context = [CASCCDImage newFloatBitmapContextWithSize:CASSizeMake(size.width, size.height)];
    
    // clear the background
    CGContextSetRGBFillColor(context,0,0,0,1);
    CGContextFillRect(context,CGRectMake(0, 0, size.width, size.height));
    
    // draw a star
    CGContextSetRGBFillColor(context,1,1,1,1);
    for (NSValue* value in stars){
        const NSPoint p = [value pointValue];
        CGContextFillEllipseInRect(context, CGRectMake(p.x, p.x, kCASStarRadius, kCASStarRadius));
    }
    
    // blur it
    CIFilter* filter = [CIFilter filterWithName:@"CIGaussianBlur"];
    [filter setDefaults];
    
    CIImage* inputImage = [CIImage imageWithCGImage:CGBitmapContextCreateImage(context)];
    [filter setValue:inputImage forKey:@"inputImage"];
    [filter setValue:[NSNumber numberWithFloat:radius] forKey:@"inputRadius"];
    
    CIImage* outputImage = [filter valueForKey:@"outputImage"];
    CIContext* cicontext = [CIContext contextWithCGContext:context options:nil];
    [cicontext drawImage:outputImage inRect:CGRectMake(0, 0, size.width, size.height) fromRect:CGRectMake(0, 0, size.width, size.height)];
    
    // build an exposure
    NSData* pixels = [NSData dataWithBytesNoCopy:CGBitmapContextGetData(context) length:size.width * size.height * 4 freeWhenDone:NO];
    return [CASCCDExposure exposureWithFloatPixels:pixels camera:nil params:expParams time:[NSDate date]];
}

@end

// CASCCDExposureController ?
@implementation CASCCDExposure (CASScripting)

- (id)uniqueID
{
    id result = [self.meta objectForKey:@"uuid"];
    if (!result){
        result = [[self.meta objectForKey:@"time"] description];
    }
    return result;
}

- (NSString*)containerAccessor
{
	return @"exposures";
}

- (NSNumber*)scriptingWidth
{
    return [NSNumber numberWithInteger:self.params.size.width];
}

- (NSNumber*)scriptingHeight
{
    return [NSNumber numberWithInteger:self.params.size.height];
}

- (NSNumber*)scriptingMilliseconds
{
    return [NSNumber numberWithInteger:self.params.ms];
}

- (id)scriptingType
{
    OSType result = 0;
    switch (self.type) {
        case kCASCCDExposureLightType:
            result = 'Ligt';
            break;
        case kCASCCDExposureDarkType:
            result = 'Dark';
            break;
        case kCASCCDExposureBiasType:
            result = 'Bias';
            break;
        case kCASCCDExposureFlatType:
            result = 'Flat';
            break;
    }
    return [NSNumber numberWithInteger:result];
}

- (void)setScriptingType:(NSNumber*)type
{
    switch ([type integerValue]) {
        case 'Ligt':
            self.type = kCASCCDExposureLightType;
            break;
        case 'Dark':
            self.type = kCASCCDExposureDarkType;
            break;
        case 'Bias':
            self.type = kCASCCDExposureBiasType;
            break;
        case 'Flat':
            self.type = kCASCCDExposureFlatType;
            break;
    }
}

- (NSString*)scriptingNote
{
    return self.note;
}

- (void)setScriptingNote:(NSString*)note
{
    self.note = note;
}

- (NSString*)scriptingPath
{
    NSURL* url = self.io.url;
    return [url isFileURL] ? [self.io.url path] : nil;
}

@end

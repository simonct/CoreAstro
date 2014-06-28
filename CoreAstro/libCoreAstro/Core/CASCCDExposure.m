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

@implementation CASCCDExposure {
    NSData* _pixels;
    NSData* _floatPixels;
    NSDictionary* _meta;
    enum {
        kCASCCDExposureReadMeta = 1,
        kCASCCDExposureReadPixels
    };
    NSInteger _readState;
    NSURL* _pngURL; // tmp hack
}

- (id)copyWithZone:(NSZone *)zone
{
    CASCCDExposure* result = nil;
    NSMutableData* floatPixels = [NSMutableData dataWithLength:[self.floatPixels length]];
    if ([floatPixels mutableBytes]){
        memcpy([floatPixels mutableBytes], [self.floatPixels bytes], [self.floatPixels length]);
        result = [CASCCDExposure exposureWithFloatPixels:floatPixels camera:nil params:self.params time:[NSDate date]];
        NSMutableDictionary* meta = [[NSMutableDictionary alloc] initWithDictionary:self.meta copyItems:YES]; // or serialize/deserialize
        [meta setObject:CASCreateUUID() forKey:@"uuid"];
        result.meta = [meta copy];
        result.format = kCASCCDExposureFormatFloat;
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

- (NSArray*) filters
{
    return self.meta[@"filters"];
}

- (void)setFilters:(NSArray *)filters
{
    NSMutableDictionary* meta = [self.meta mutableCopy];
    if (!filters){
        [meta removeObjectForKey:@"filters"];
    }
    else {
        meta[@"filters"] = [filters copy];
    }
    self.meta = [meta copy];
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

- (NSInteger) pixelSize
{
    return self.rgba ? sizeof(Pixel_FFFF) : sizeof(Pixel_F);
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

- (void)setFormat:(CASCCDExposureFormat)format
{
    [self setMetaObject:[NSNumber numberWithInteger:format] forKey:@"format"];
}

- (BOOL) rgba
{
    return ([[self.meta valueForKey:@"format"] integerValue] == kCASCCDExposureFormatFloatRGBA);
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
    if (self.params.bin.width < 1 || self.params.bin.height < 1){
        return nil;
    }
    
    const NSInteger pixelSize = self.pixelSize;

    NSData* subframePixels = [NSMutableData dataWithLength:rect.size.width*rect.size.height*pixelSize]; // bin size
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

    // todo; revist need for this as actualSize already accounts for binning...
    CASRect scaledRect = rect;
    if (self.params.bin.width != 0){
        scaledRect.size.width /= self.params.bin.width;
        scaledRect.origin.x /= self.params.bin.width;
    }
    if (self.params.bin.height != 0){
        scaledRect.size.height /= self.params.bin.height;
        scaledRect.origin.y /= self.params.bin.height;
    }

    uint8_t* floatPixels = (scaledRect.origin.x  * pixelSize) + (scaledRect.origin.y * actualSize.width /* todo; scaledRect.size.width ? */  * pixelSize) + (uint8_t*)[self.floatPixels bytes];
    uint8_t* subframeFloatPixels = (uint8_t*)[subframePixels bytes];
    
    dispatch_apply(scaledRect.size.height, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^(size_t row) {
        
        uint8_t* floatPixels1 = floatPixels + (row * actualSize.width /* todo; scaledRect.size.width ? */  * pixelSize);
        uint8_t* subframeFloatPixels1 = subframeFloatPixels + (row * scaledRect.size.width * pixelSize);
        
        memcpy(subframeFloatPixels1, floatPixels1, scaledRect.size.width * pixelSize);
    });
    
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

    [meta setObject:CASCreateUUID() forKey:@"uuid"];

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
    
    CGImageRef bitmapImage = CGBitmapContextCreateImage(context);
    CIImage* inputImage = [CIImage imageWithCGImage:bitmapImage];
    CGImageRelease(bitmapImage);
    [filter setValue:inputImage forKey:@"inputImage"];
    [filter setValue:[NSNumber numberWithFloat:radius] forKey:@"inputRadius"];
    
    CIImage* outputImage = [filter valueForKey:@"outputImage"];
    CIContext* cicontext = [CIContext contextWithCGContext:context options:nil];
    [cicontext drawImage:outputImage inRect:CGRectMake(0, 0, size.width, size.height) fromRect:CGRectMake(0, 0, size.width, size.height)];
    
    // build an exposure
    NSData* pixels = [NSData dataWithBytesNoCopy:CGBitmapContextGetData(context) length:size.width * size.height * 4 freeWhenDone:NO];
    CASCCDExposure* exposure = [CASCCDExposure exposureWithFloatPixels:pixels camera:nil params:expParams time:[NSDate date]];
    
    CGContextRelease(context);
    
    return exposure;
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

- (NSURL*)scriptingFile
{
    if (self.pngURL){
        return self.pngURL; // temp hack until pngs are incorporated into exposure io
    }
    return self.io.url;
}

@end

@implementation CASCCDExposure (DerivedData)

NSString* const kCASCCDExposureNormalisedKey = @"normalised";
NSString* const kCASCCDExposureCorrectedKey = @"corrected";
NSString* const kCASCCDExposureDebayeredKey = @"debayered";
NSString* const kCASCCDExposurePlateSolutionKey = @"plate-solve";

- (CASCCDExposure*)normalisedExposure
{
    return [self derivedExposureWithIdentifier:kCASCCDExposureNormalisedKey];
}

- (CASCCDExposure*)correctedExposure
{
    return [self derivedExposureWithIdentifier:kCASCCDExposureCorrectedKey];
}

- (CASCCDExposure*)debayeredExposure
{
    return [self derivedExposureWithIdentifier:kCASCCDExposureDebayeredKey];
}

- (CASCCDExposure*)derivedExposureWithIdentifier:(NSString*)identifier
{
    CASCCDExposure* exposure = nil;
    NSURL* url = [[self.io derivedDataURLForName:identifier] URLByAppendingPathExtension:@"caExposure"];
    if ([url checkResourceIsReachableAndReturnError:nil]){
        CASCCDExposureIO* io = [CASCCDExposureIO exposureIOWithPath:[url path]];
        if (io){
            exposure = [[CASCCDExposure alloc] init];
            exposure.io = io;
        }
    }
    return exposure;
}

@end

@implementation CASCCDExposure (DisplayValues)

// put into a category on ccdexposure
- (NSString*)stringBySubstitutingPlaceholders:(NSString*)placeholders
{
    if ([placeholders rangeOfString:@"$"].location != NSNotFound) {
        
        NSMutableString* ms = [placeholders mutableCopy];
        
        // binning
        [ms replaceOccurrencesOfString:@"$bin" withString:[NSString stringWithFormat:@"%ldx%ld",(long)self.params.bin.width,(long)self.params.bin.height] options:NSLiteralSearch range:NSMakeRange(0, [ms length])];
        
        // camera model
        if (self.displayDeviceName){
            [ms replaceOccurrencesOfString:@"$camera" withString:self.displayDeviceName options:NSLiteralSearch range:NSMakeRange(0, [ms length])];
        }
        
        // exposure duration
        NSString* duration;
        if (self.params.ms > 999){
            duration = [NSString stringWithFormat:@"%lds",self.params.ms/1000];
        }
        else {
            duration = [NSString stringWithFormat:@"%ldms",self.params.ms];
        }
        [ms replaceOccurrencesOfString:@"$duration" withString:duration options:NSLiteralSearch range:NSMakeRange(0, [ms length])];
        
        // filter
        NSArray* filters = self.filters;
        if ([filters count]) {
            NSString* filter = self.filters[0];
            [ms replaceOccurrencesOfString:@"$filter" withString:filter options:NSLiteralSearch range:NSMakeRange(0, [ms length])];
        }
        
        // $date
        if (self.displayDate){
            [ms replaceOccurrencesOfString:@"$date" withString:self.displayDate options:NSLiteralSearch range:NSMakeRange(0, [ms length])];
        }
        
        // $temp
        
        placeholders = [ms copy];
    }
    
    return placeholders;
}

@end

@implementation CASCCDExposure (TemporaryHack)

- (NSURL*)pngURL
{
    return _pngURL;
}

- (void)setPngURL:(NSURL *)pngURL
{
    _pngURL = pngURL;
}

@end



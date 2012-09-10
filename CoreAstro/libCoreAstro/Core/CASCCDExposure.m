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

@interface CASCCDExposure ()
@end

@implementation CASCCDExposure

@synthesize io, persistentStoreURL;
@synthesize pixels = _pixels, params = _params, meta = _meta, type = _type;

// image factory

- (NSDate*) date
{
    return [NSDate dateWithTimeIntervalSinceReferenceDate:[[self.meta objectForKey:@"time"] doubleValue]];
}

- (NSString*)uuid
{
    return [self.meta objectForKey:@"uuid"];
}

- (NSString*)deviceID
{
    return [self.meta valueForKeyPath:@"device.deviceID"];
}

- (NSString*) displayDate
{
    static NSDateFormatter* formatter = nil;
    if (!formatter) {
        formatter = [[NSDateFormatter alloc] init];
        formatter.dateStyle = NSDateFormatterShortStyle;
        formatter.timeStyle = NSDateFormatterShortStyle;
    }
    return [formatter stringFromDate:self.date];
}

- (NSString*) displayExposure
{
    static NSNumberFormatter* formatter = nil;
    if (!formatter) {
        formatter = [[NSNumberFormatter alloc] init];
        formatter.numberStyle = NSNumberFormatterDecimalStyle;
        formatter.generatesDecimalNumbers = YES;
        formatter.minimumFractionDigits = 0;
        formatter.maximumFractionDigits = 3;
    }
    return [NSString stringWithFormat:@"%@s",[formatter stringFromNumber:[NSNumber numberWithDouble:self.params.ms/1000.0]]];
}

- (NSString*)displayDeviceName
{
    return [self.meta valueForKeyPath:@"device.name"];
}

- (CASSize)actualSize
{
    return CASSizeMake(self.params.size.width / self.params.bin.width, self.params.size.height / self.params.bin.height);
}

- (void)readFromPersistentStore:(BOOL)readPixels
{
    [self.io readExposure:self readPixels:readPixels error:nil];
}

- (NSData*)pixels
{
    [self readFromPersistentStore:YES];
    return _pixels;
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

- (NSString*)note
{
    return [self.meta objectForKey:@"note"];
}

- (void)setNote:(NSString *)note
{
    [self setMetaObject:note forKey:@"note"];
}

- (CASCCDImage*)createImage
{
    if (!self.pixels){
        return nil;
    }

    return [CASCCDImage createImageWithPixels:self.pixels 
                                         size:CASSizeMake(self.params.size.width/self.params.bin.width, self.params.size.height/self.params.bin.height) 
                                 bitsPerPixel:self.params.bps];    
}

- (CASCCDImage*)createBlankImageWithSize:(CASSize)size
{
    return [CASCCDImage createImageWithPixels:nil
                                         size:size
                                 bitsPerPixel:self.params.bps];    
}

- (void)reset
{
    self.pixels = nil;
}

- (void)deleteExposure
{
    [self.io deleteExposure:self error:nil];
}

+ (id)exposureWithPixels:(NSData*)pixels camera:(CASCCDDevice*)camera params:(CASExposeParams)expParams time:(NSDate*)time
{
    CASCCDExposure* exp = [[CASCCDExposure alloc] init];
    
    exp.pixels = pixels;
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
    NSDictionary* cameraParams = [camera.params cas_propertyValues];
    if (cameraParams){
        [deviceMeta setObject:cameraParams forKey:@"params"];
    }
    
    NSMutableDictionary* meta = [NSMutableDictionary dictionaryWithCapacity:2];
    
    [meta setObject:deviceMeta forKey:@"device"];
    [meta setObject:[NSNumber numberWithDouble:[time timeIntervalSinceReferenceDate]] forKey:@"time"];
    [meta setObject:NSStringFromCASExposeParams(expParams) forKey:@"exposure"];
    
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
    
    const CASExposeParams check = CASExposeParamsFromNSString([meta objectForKey:@"exposure"]);;
    NSAssert(memcmp(&expParams, &check, sizeof check) == 0,@"CASExposeParams check failed");
    exp.meta = meta;
    
    return exp;
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

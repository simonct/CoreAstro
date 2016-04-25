//
//  CASCCDExposureIO.m
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

#import "CASCCDExposureIO.h"
#import "CASFITSUtilities.h"
#import <Accelerate/Accelerate.h>

#if CAS_ENABLE_FITS
#import "fitsio.h"
#endif

@interface CASCCDExposureIOv1 : CASCCDExposureIO
@end

@implementation CASCCDExposureIOv1

- (NSURL*)pixelsURL
{
    return [[self url] URLByAppendingPathExtension:@"rawPixels"];
}

- (NSURL*)metaURL
{
    return [[self url] URLByAppendingPathExtension:@"plist"];
}

- (BOOL)writeExposure:(CASCCDExposure*)exposure writePixels:(BOOL)writePixels error:(NSError**)errorPtr
{
    NSError* error = nil;
    
    if ([self.url isFileURL]){
        [[NSFileManager defaultManager] createDirectoryAtPath:[[self.url path] stringByDeletingLastPathComponent] withIntermediateDirectories:YES attributes:nil error:&error];
    }
    
    [exposure.meta writeToURL:[self metaURL] atomically:YES];

    if (writePixels){
        
        NSURL* pixelsUrl = [self pixelsURL];
        [exposure.pixels writeToURL:pixelsUrl options:NSDataWritingAtomic error:&error];
        
        if (error){
            NSLog(@"Error writing image to store: %@",error);
        }
        else {
            NSLog(@"Wrote image to %@",pixelsUrl);
        }
    }
    
    return YES;
}

- (BOOL)readExposure:(CASCCDExposure*)exposure readPixels:(BOOL)readPixels error:(NSError**)errorPtr 
{
    if (readPixels && !exposure.hasPixels){
        exposure.pixels = [NSData dataWithContentsOfURL:[self pixelsURL]]; // lazy load, NSCache ?
    }
    if (!exposure.hasMeta){
        exposure.meta = [NSDictionary dictionaryWithContentsOfURL:[self metaURL]];
        if (exposure.meta){
            exposure.params = CASExposeParamsFromNSString([exposure.meta objectForKey:@"exposure"]);
        }
    }
    
    return YES;
}

- (BOOL)deleteExposure:(CASCCDExposure*)exposure error:(NSError**)errorPtr
{
    NSError* error = nil;
    
    NSURL* pixelsUrl = [self pixelsURL];
    if ([pixelsUrl isFileURL]){
        [[NSFileManager defaultManager] removeItemAtURL:pixelsUrl error:&error];
        if (error){
            NSLog(@"Error deleting pixels: %@",error);
        }
    }
    error = nil;
    NSURL* metaURL = [self metaURL];
    if ([metaURL isFileURL]){
        [[NSFileManager defaultManager] removeItemAtURL:metaURL error:&error];
        if (error){
            NSLog(@"Error deleting metadata: %@",error);
        }
    }
    
    return YES;
}

@end

@interface CASCCDExposureIOv2 : CASCCDExposureIO
@end

@implementation CASCCDExposureIOv2

- (NSString*)metaKey
{
    return @"meta.json";
}

- (NSString*)pixelsKey
{
    return @"samples.data";
}

- (NSString*)thumbKey
{
    return @"thumbnail.png";
}

- (NSString*)derivedKey
{
    return @"derived";
}

- (NSURL*)derivedURL
{
    return [self.url URLByAppendingPathComponent:self.derivedKey];
}

- (NSURL*)derivedDataURLForName:(NSString*)name
{
    return [name length] ? [self.derivedURL URLByAppendingPathComponent:name] : nil;
}

- (NSImage*)thumbnail
{
    NSError* error = nil;
    NSFileWrapper* wrapper = [[NSFileWrapper alloc] initWithURL:self.url options:0 error:&error];
    if (wrapper){
        NSDictionary* wrappers = [wrapper fileWrappers];
        NSString* thumbName = [[wrappers objectForKey:[self thumbKey]] filename];
        if (thumbName){
            return [[NSImage alloc] initWithContentsOfURL:[self.url URLByAppendingPathComponent:thumbName]];
        }
    }
    return nil;
}

- (BOOL)writeExposure:(CASCCDExposure*)exposure writePixels:(BOOL)writePixels error:(NSError**)errorPtr
{
    NSError* error = nil;
    
    [[NSFileManager defaultManager] createDirectoryAtURL:self.url withIntermediateDirectories:YES attributes:nil error:&error];
    
    NSFileWrapper* wrapper = [[NSFileWrapper alloc] initWithURL:self.url options:0 error:&error];
    if (wrapper){
        
        NSString* metaName = nil;
        NSString* samplesName = nil;
        NSString* thumbName = nil;
        
        NSDictionary* wrappers = [wrapper fileWrappers];
        if ([wrappers count]){
            metaName = [[wrappers objectForKey:[self metaKey]] filename];
            samplesName = [[wrappers objectForKey:[self pixelsKey]] filename];
            thumbName = [[wrappers objectForKey:[self thumbKey]] filename];
        }
        if (!metaName){
            metaName = [wrapper addRegularFileWithContents:nil preferredFilename:[self metaKey]];
        }
        if (!samplesName){
            samplesName = [wrapper addRegularFileWithContents:nil preferredFilename:[self pixelsKey]];
        }
        if (!thumbName){
            thumbName = [wrapper addRegularFileWithContents:nil preferredFilename:[self thumbKey]];
        }
        
        // write samples and metadata
        NSDictionary* dict = [NSDictionary dictionaryWithObjectsAndKeys:[exposure.meta copy],@"exposure",[NSNumber numberWithInteger:1],@"version",nil];
        NSData* metaData = [NSJSONSerialization dataWithJSONObject:dict options:0 error:&error]; // occassional exception ?
        if (metaData){
            if ([metaData writeToURL:[self.url URLByAppendingPathComponent:metaName] options:NSDataWritingAtomic error:&error] && writePixels) {
                switch ([[dict valueForKeyPath:@"exposure.format"] integerValue]) {
                    case kCASCCDExposureFormatFloat:
                    case kCASCCDExposureFormatFloatRGBA:
                        NSAssert(exposure.floatPixels, @"Pixel format set to floating point but no pixels");
                        [exposure.floatPixels writeToURL:[self.url URLByAppendingPathComponent:samplesName] options:NSDataWritingAtomic error:&error];
                        break;
                    default:
                        NSAssert(exposure.pixels, @"Pixel format set to integer but no pixels");
                        [exposure.pixels writeToURL:[self.url URLByAppendingPathComponent:samplesName] options:NSDataWritingAtomic error:&error];
                        break;
                }
            }
        }
        
        // create a thumbnail (could use the QuickLook generator but that then introduces an unnecessary dependency)
        if (writePixels){
            
            CASCCDImage* image = [exposure newImage];
            if (image){
                
                const CASSize size = image.size;
                const NSInteger thumbWidth = 256;
                const CASSize thumbSize = CASSizeMake(thumbWidth, thumbWidth * ((float)size.height/(float)size.width));
                CGImageRef thumb = [image newImageWithSize:thumbSize];
                if (!thumb){
                    NSLog(@"Failed to create thumbnail image of size %@",NSStringFromCASSize(thumbSize));
                }
                else{
                    
                    NSURL* thumbURL = [self.url URLByAppendingPathComponent:thumbName];
                    CGImageDestinationRef destination = CGImageDestinationCreateWithURL((__bridge CFURLRef)thumbURL, CFSTR("public.png"), 1, nil);
                    if (!destination){
                        NSLog(@"Failed to create image destination for thumbnail at %@",thumbURL);
                    }
                    else{
                        CGImageDestinationAddImage(destination, thumb, nil);
                        if (!CGImageDestinationFinalize(destination)){
                            NSLog(@"Failed to write thumbnail to %@",thumbURL);
                        }
                        CFRelease(destination);
                    }
                    CGImageRelease(thumb);
                }
            }
        }
    }
    
    if (errorPtr){
        *errorPtr = error;
    }
    
    return (error == nil);
}

- (BOOL)readExposure:(CASCCDExposure*)exposure readPixels:(BOOL)readPixels error:(NSError**)errorPtr
{
    NSError* error = nil;
    
    NSFileWrapper* wrapper = [[NSFileWrapper alloc] initWithURL:self.url options:0 error:&error];
    if (wrapper){
        
        if (!exposure.hasMeta){
            
            NSFileWrapper* meta = [[wrapper fileWrappers] objectForKey:[self metaKey]];
            if (meta){
                
                NSDictionary* dict = [NSJSONSerialization JSONObjectWithData:[NSData dataWithContentsOfURL:[self.url URLByAppendingPathComponent:meta.filename]] options:0 error:&error];
                exposure.meta = [dict objectForKey:@"exposure"];
            }
        }
        
        if (readPixels && !exposure.hasPixels){
            
            NSFileWrapper* samples = [[wrapper fileWrappers] objectForKey:[self pixelsKey]];
            if (samples){
                
                NSData* pixels = [NSData dataWithContentsOfURL:[self.url URLByAppendingPathComponent:samples.filename] options:NSDataReadingUncached error:&error];
                if (pixels){
                    
                    const NSInteger format = [[exposure.meta valueForKey:@"format"] integerValue];
                    switch (format) {
                        case kCASCCDExposureFormatFloat:
                            exposure.floatPixels = pixels;
                            break;
                        case kCASCCDExposureFormatFloatRGBA:
                            exposure.floatPixels = pixels;
                            break;
                        default:
                            exposure.pixels = pixels;
                            break;
                    }
                }
            }
        }
    }
    
    if (errorPtr){
        *errorPtr = error;
    }
    
    return (error == nil);
}

- (BOOL)deleteExposure:(CASCCDExposure*)exposure error:(NSError**)errorPtr
{
    return [[NSFileManager defaultManager] removeItemAtURL:self.url error:errorPtr];
}

@end

#if CAS_ENABLE_FITS

@interface CASCCDExposureFITS : CASCCDExposureIO
@property (nonatomic,readonly) NSDateFormatter* utcDateFormatter;
@end

@implementation CASCCDExposureFITS {
    NSDateFormatter* _utcDateFormatter;
}

- (NSString*)metaKey
{
    return @"meta.json";
}

- (NSString*)pixelsKey
{
    return @"samples.data";
}

static NSError* (^createFITSError)(NSInteger,NSString*) = ^(NSInteger status,NSString* msg){
    if (status && !msg){
        msg = [NSString stringWithFormat:@"FITS error: %ld",status];
    }
    return [NSError errorWithDomain:@"CASCCDExposureFITS"
                               code:status
                           userInfo:[NSDictionary dictionaryWithObject:msg forKey:NSLocalizedFailureReasonErrorKey]];
};

- (NSDateFormatter*)utcDateFormatter
{
    if (!_utcDateFormatter){
        _utcDateFormatter = [[NSDateFormatter alloc] init];
        _utcDateFormatter.timeZone = [NSTimeZone timeZoneWithName:@"UTC"];
        [_utcDateFormatter setDateFormat:@"yyyy'.'M'.'dd'T'HH':'mm':'ss'.'SSS"];
    }
    return _utcDateFormatter;
}

- (NSString*)stringForCoordinate:(float)coord
{
    // SDD MM SS.SSS
    const char sign = coord < 0 ? '-' : '+';
    
    const float degs = fabsf(truncf(coord));
    const float mins1 = (fabsf(coord) - degs)*60;
    const float mins = truncf(mins1);
    const float secs = (mins1 - mins)*60;
    
    return [NSString stringWithFormat:@"%c%02d %02d %0.3f",sign,(int)degs,(int)mins,secs];
}

- (void)addStringHeader:(const char*)header comment:(const char*)comment withValue:(id)value toFile:(fitsfile*)fptr
{
    if (value){
        value = [value description];
        if ([value length]){
            const char* s = [value UTF8String];
            if (s){
                int status = 0;
                fits_update_key(fptr, TSTRING, header, (void*)s, comment, &status);
            }
        }
    }
}

- (BOOL)writeExposure:(CASCCDExposure*)exposure writePixels:(BOOL)writePixels error:(NSError**)errorPtr
{
    NSError* error = nil;
    
    NSString* s = [[self class] sanitizeExposurePath:[self.url path]];
    
    NSString* directory = [s stringByDeletingLastPathComponent];
    if (![[NSFileManager defaultManager] createDirectoryAtURL:[NSURL fileURLWithPath:directory] withIntermediateDirectories:YES attributes:nil error:&error]){
        NSLog(@"Failed to create directory for fits file at %@",directory);
    }
    else {
        
        int status = 0;
        fitsfile *fptr;
        
        const char * path = [s fileSystemRepresentation];
        if (fits_create_diskfile(&fptr, path, &status)) {
            error = createFITSError(status,[NSString stringWithFormat:@"Failed to create FITS file %d",status]);
        }
        else {
            
            int format = 0;
            int datatype = 0;
            float scale = 1;
            float zero = 0;
            NSInteger pixelCount = 0;
            NSData* pixelData = nil;
            switch ([[exposure.meta objectForKey:@"format"] integerValue]) {
                case kCASCCDExposureFormatFloat:
                    format = FLOAT_IMG;
                    datatype = TFLOAT;
                    pixelData = exposure.floatPixels;
                    pixelCount = [pixelData length]/sizeof(float);
                    scale = exposure.maxPixelValue;
                    break;
                case kCASCCDExposureFormatFloatRGBA:
                    NSLog(@"*** Unsupported format"); // write as planar rgb ?
                    break;
                default:
                    format = USHORT_IMG;
                    datatype = TUSHORT;
                    zero = 32768;
                    pixelData = exposure.pixels;
                    pixelCount = [pixelData length]/sizeof(uint16_t);
                    break;
            }

            const CASSize size = exposure.actualSize;
            long naxes[2] = { size.width, size.height };
            if ( fits_create_img(fptr, format, 2, naxes, &status) ){
                error = createFITSError(status,[NSString stringWithFormat:@"Failed to create FITS file %d",status]);
            }
            else {
                
                if ( fits_update_key(fptr, TFLOAT, "BSCALE", (void*)&scale, "pixel scaling factor", &status) ) {
                    error = createFITSError(status,[NSString stringWithFormat:@"Failed to write FITS metadata %d",status]);
                }
                if ( fits_update_key(fptr, TFLOAT, "BZERO", (void*)&zero, "pixel zero value", &status) ) {
                    error = createFITSError(status,[NSString stringWithFormat:@"Failed to write FITS metadata %d",status]);
                }

                if ( fits_write_img(fptr, datatype, 1, pixelCount, (void*)[pixelData bytes], &status) ){
                    error = createFITSError(status,[NSString stringWithFormat:@"Failed to write FITS file %d",status]);
                }
                else {
                    
                    // add basic keywords (from http://heasarc.gsfc.nasa.gov/docs/fcg/standard_dict.html)
                    
                    fits_write_date(fptr, &status);
                    
                    NSString* deviceID = exposure.deviceID;
                    if ([deviceID length]){
                        const char* s = [deviceID cStringUsingEncoding:NSASCIIStringEncoding];
                        if (s){
                            fits_update_key(fptr, TSTRING, "INSTRUME", (void*)s, "acquisition instrument", &status);
                        }
                    }
                    
                    const float exposureMS = exposure.params.ms;
                    fits_update_key(fptr, TFLOAT, "EXPTIME", (void*)&exposureMS, "exposure time in milliseconds", &status);
                    
                    NSDate* date = exposure.date;
                    if (date){
                        // yyyy.mm.ddThh:mm:ss[.sss]
                        NSString* dateStr = [self.utcDateFormatter stringFromDate:date];
                        if ([dateStr length]){
                            const char* s = [dateStr cStringUsingEncoding:NSASCIIStringEncoding];
                            if (s){
                                fits_update_key(fptr, TSTRING, "DATE-OBS", (void*)s, "acquisition date (UTC)", &status);
                            }
                        }
                    }
                    
                    // leave this as the host app version and have a new key to identify CAS ?
                    // SWCREATE ?
                    const char* version = [[NSString stringWithFormat:@"CoreAstro %@",[[NSBundle bundleForClass:[self class]] objectForInfoDictionaryKey:@"CFBundleVersion"]] UTF8String];
                    fits_update_key(fptr, TSTRING, "CREATOR", (void*)version, "CoreAstro version", &status);

                    unsigned short xbin = exposure.params.bin.width;
                    fits_update_key(fptr, TUSHORT, "XBINNING", (void*)&xbin, "X Binning", &status);
                    unsigned short ybin = exposure.params.bin.height;
                    fits_update_key(fptr, TUSHORT, "YBINNING", (void*)&ybin, "Y Binning", &status);

//                    if (exposure.params.origin.x != 0 || exposure.params.origin.y != 0){
//                        long orx = exposure.params.origin.x;
//                        fits_update_key(fptr, TLONG, "XORGSUBF", (void*)&orx, "X origin of subframe", &status);
//                        long ory = exposure.params.origin.y;
//                        fits_update_key(fptr, TLONG, "YORGSUBF", (void*)&ory, "Y origin of subframe", &status);
//                    }
                    
                    char* imageType = nil;
                    switch ([exposure.meta[@"type"] intValue]) {
                        case kCASCCDExposureLightType:
                            imageType = "Light Frame";
                            break;
                        case kCASCCDExposureDarkType:
                            imageType = "Dark Frame";
                            break;
                        case kCASCCDExposureBiasType:
                            imageType = "Bias Frame";
                            break;
                        case kCASCCDExposureFlatType:
                            imageType = "Flat Frame";
                            break;
                    }
                    if (imageType){
                        fits_update_key(fptr, TSTRING, "IMAGETYP", (void*)imageType, "Image type", &status);
                    }

                    // filters
                    NSArray* filters = exposure.meta[@"filters"];
                    if ([filters count] > 0){
                        
                        if ([filters count] == 1){
                            
                            NSString* filterName = filters[0];
                            if (filterName){
                                const char* filterNameC = [filterName UTF8String];
                                if (filterNameC){
                                    fits_update_key(fptr, TSTRING, "FILTER", (void*)filterNameC, "Filter", &status);
                                }
                            }
                        }
                        else{
                            
                            NSInteger i = 1;
                            for (NSString* filterName in filters) {
                                const char* filterNameC = [filterName UTF8String];
                                if (filterNameC){
                                    fits_update_key(fptr, TSTRING, [[NSString stringWithFormat:@"FILTER%ld",i] UTF8String], (void*)filterNameC, [[NSString stringWithFormat:@"Filter %ld",i] UTF8String], &status);
                                }
                                ++i;
                            }
                        }
                    }

                    if (exposure.uuid){
                        const char* uuid = [exposure.uuid UTF8String];
                        fits_update_key(fptr, TSTRING, "CAS_UUID", (void*)uuid, "CoreAstro exposure UUID", &status);
                    }
                    
                    if (exposure.meta[@"latitude"]){
                        [self addStringHeader:"SITELAT" comment:"Latitude of the site" withValue:[self stringForCoordinate:[exposure.meta[@"latitude"] doubleValue]] toFile:fptr];
                    }
                    if (exposure.meta[@"longitude"]){
                        [self addStringHeader:"SITELONG" comment:"Longitude of the site" withValue:[self stringForCoordinate:[exposure.meta[@"longitude"] doubleValue]] toFile:fptr];
                    }
                    
                    // temperature
                    NSDictionary* temperature = exposure.meta[@"temperature"];
                    if ([temperature count]){
                        NSNumber* setPoint = temperature[@"setpoint"];
                        if (setPoint){
                            const float setPointFloat = [setPoint floatValue];
                            fits_update_key(fptr, TFLOAT, "SET-TEMP", (void*)&setPointFloat, "Set Point Centigrade", &status);
                        }
                        NSArray* temperatures = temperature[@"temperatures"];
                        if ([temperatures count]){
                            const float startTempFloat = [[temperatures firstObject] floatValue];
                            fits_update_key(fptr, TFLOAT, "CCD-TEMP", (void*)&startTempFloat, "CCD Temperature Centigrade", &status);
                        }
                    }
                    
                    /*
                    NSString* notes = exposure.note;
                    if ([notes length]){
                        const char* s = [notes cStringUsingEncoding:NSASCIIStringEncoding]; // escape, length limit ?
                        if (s){
                            if ( fits_update_key(fptr, TSTRING, "COMMENT", (void*)s, "", &status) ) {
                                error = createFITSError(status,[NSString stringWithFormat:@"Failed to write FITS metadata %d",status]);
                            }
                        }
                    }
                    */
                    
                    // add another data unit with the plist
                    char* form[] = {"PA"};
                    char* type[] = {"CAS_EXPROPS"};
                    if ( fits_create_tbl( fptr, BINARY_TBL, 0, 1, type, form, NULL, NULL, &status) ){
                        error = createFITSError(status,[NSString stringWithFormat:@"Failed to write FITS metadata %d",status]);
                    }
                    
                    NSData* metaData = [NSJSONSerialization dataWithJSONObject:exposure.meta options:0 error:&error];
                    if (!error){
                        NSMutableData* mutableMetaData = [NSMutableData dataWithData:metaData];
                        [mutableMetaData setLength:[mutableMetaData length] + 1]; // ensure a trailing null
                        const char* metaDataStr = [mutableMetaData bytes];
                        const char* metaDataStrArg[] = {metaDataStr};
                        if (fits_write_col(fptr, TSTRING, 1, 1, 1, 1, metaDataStrArg, &status)){
                            error = createFITSError(status,[NSString stringWithFormat:@"Failed to write FITS metadata %d",status]);
                        }
                    }
                }
            }
            fits_close_file(fptr, &status);
        }
        
        if (status){
            fits_report_error(stderr, status);
        }
    }

    if (errorPtr){
        *errorPtr = error;
    }
    
    return (error == nil);
}

- (NSDictionary*)readExposureMetadata:(fitsfile*)fptr
{
    NSDictionary* result = nil;
    
    int status = 0;
    int numhdu = 0;
    int hdutype = 0;
    
    fits_get_num_hdus(fptr,&numhdu,&status);
    if (numhdu > 0){
        
        // get current hdu
        int curhdu = 0;
        fits_get_hdu_num(fptr,&curhdu);
        
        while(!result && !fits_movrel_hdu(fptr,1,&hdutype,&status)){
            
            if (hdutype == BINARY_TBL){
                
                int colnum = 1;
                char colname[68+1];
                if (fits_get_colname(fptr,0,"CAS_EXPROPS",colname,&colnum,&status)){
                    status = 0;
                    continue;
                }
                else{
                
                    long rowsize = 0;
                    if (!fits_get_rowsize(fptr,&rowsize,&status)){
                        
                        char* data = calloc(rowsize, 1);
                        if (data){
                            
                            const char* dataArg[] = {data};
                            if (!fits_read_col(fptr,TSTRING,1,1,1,1,NULL,dataArg,NULL,&status)){
                                
                                char* end = data;
                                while(*end && end < data + rowsize)
                                    ++end;
                                
                                @try {
                                    NSError* error;
                                    NSDictionary* params = [NSJSONSerialization JSONObjectWithData:[NSData dataWithBytesNoCopy:data length:(end - data) freeWhenDone:NO] options:NSJSONReadingAllowFragments error:&error];
                                    if ([params isKindOfClass:[NSDictionary class]]){
                                        result = params;
                                    }
                                    else if (params) {
                                        NSLog(@"Expecting exposure metadata to be a NSDictionary but it's a %@",NSStringFromClass([params class]));
                                    }
                                    if (error){
                                        NSLog(@"Error reading reading FITS JSON: %@",error);
                                    }
                                }
                                @catch (NSException *exception) {
                                    NSLog(@"Exception reading FITS JSON: %@",exception);
                                }
                            }
                            free(data);
                        }
                    }
                }
            }
        }
        
        // restore current hdu
        if (curhdu > 0){
            fits_movabs_hdu(fptr,curhdu,&hdutype,&status);
        }
    }
    
//    if (status){
//        NSLog(@"Status %d reading exposure metadata",status);
//    }
    
    return result;
}

- (BOOL)readExposure:(CASCCDExposure*)exposure readPixels:(BOOL)readPixels error:(NSError**)errorPtr
{
    NSError* error = nil;
    
    NSString* path = [self.url path];
    
    int status = 0;
    fitsfile *fptr;
    int hdutype;
    
    if (cas_fits_open_image(&fptr, [[self.url path] UTF8String], READONLY, &status)){
        error = createFITSError(status,[NSString stringWithFormat:@"Failed to open FITS file %d",status]);
    }
    else {
        
        if (fits_get_hdu_type(fptr, &hdutype, &status) || hdutype != IMAGE_HDU) {
            error = createFITSError(unimpErr,[NSString stringWithFormat:@"FITS file isn't an image %@",path]);
        }
        else {
            
            // get the image dimensions
            int naxis;
            long naxes[2];
            fits_get_img_dim(fptr, &naxis, &status);
            fits_get_img_size(fptr, 2, naxes, &status);
            
            // get the pixel format
            int type;
            fits_get_img_type(fptr,&type,&status);
            //NSLog(@"CASCCDExposureFITS: fits_get_img_type: %d",type);
            
            if (status || naxis != 2 || (type != FLOAT_IMG && type != USHORT_IMG && type != SHORT_IMG)) {
                error = createFITSError(unimpErr,[NSString stringWithFormat:@"Only 16-bit in t or floating point 2D images supported %@",path]);
            }
            else {
                
                // get the zero and scaling values
                float zero = 0;
                float scale = 1;
                fits_read_key(fptr,TFLOAT,"BSCALE",(void*)&scale,NULL,&status); status = 0;
                fits_read_key(fptr,TFLOAT,"BZERO",(void*)&zero,NULL,&status); status = 0;
                //NSLog(@"CASCCDExposureFITS: BSCALE: %f, BZERO: %f",scale,zero);
                                
                // pixels
                UInt16* shortPixels = nil;
                float* floatPixels = nil;
                if (readPixels){
                    
                    // create a buffer todo; round to 4 or 16 bytes ?
                    if (type == USHORT_IMG || type == SHORT_IMG){
                        shortPixels = calloc(naxes[0] * naxes[1],sizeof(UInt16));
                    }
                    else {
                        floatPixels = calloc(naxes[0] * naxes[1],sizeof(float));
                    }
                    
                    if (!floatPixels && !shortPixels){
                        error = createFITSError(memFullErr,@"Out of memory");
                    }
                    else {
                        
                        long fpixel[2] = {1,0};
                        float* floatPix = floatPixels;
                        UInt16* shortPix = shortPixels;
                        
                        for (fpixel[1] = 1; fpixel[1] <= naxes[1]; fpixel[1]++) {
                            
                            // read a row of pixels into the bitmap
                            if (floatPix){
                                if (fits_read_pix(fptr,TFLOAT,fpixel,naxes[0],0,floatPix,0,&status)){
                                    error = createFITSError(status,[NSString stringWithFormat:@"Failed to read a row %d: %@",status,path]);
                                    break;
                                }
                            }
                            if (shortPix){
                                if (fits_read_pix(fptr,TUSHORT,fpixel,naxes[0],0,shortPix,0,&status)){
                                    error = createFITSError(status,[NSString stringWithFormat:@"Failed to read a row %d: %@",status,path]);
                                    break;
                                }
                            }

                            // handle scale and offset
                            if (floatPix){
                                
                                if (zero != 0 || scale != 1){
                                    
                                    if (zero == 32768 && scale == 1){
                                        // frames from before setting the scale and zero keys for every exposure
                                        zero = 0;
                                        scale = 1.0/65535.0;
                                        vDSP_vsmsa(floatPix,1,&scale,&zero,floatPix,1,naxes[0]);
                                    }
                                    else if (zero == 0 && scale == 65535){
                                        // nothing, already in the 0-1 scale
                                    }
                                    else {
                                        vDSP_vsmsa(floatPix,1,&scale,&zero,floatPix,1,naxes[0]);
                                    }
                                }
                            }
                            
                            // advance the pixel pointer a row
                            if (floatPix){
                                floatPix += naxes[0];
                            }
                            if (shortPix){
                                shortPix += naxes[0];
                            }
                        }
                    }
                }
                
                // metadata
                NSDictionary* metadata = [self readExposureMetadata:fptr];
                if (!metadata){
                                        
                    NSMutableDictionary* mmetadata = [NSMutableDictionary dictionaryWithCapacity:5];
                    if (floatPixels){
                        mmetadata[@"format"] = @(kCASCCDExposureFormatFloat);
                    }
                    if (shortPixels){
                        mmetadata[@"format"] = @(kCASCCDExposureFormatUInt16);
                    }
                    
                    NSMutableDictionary* deviceParams = [NSMutableDictionary dictionaryWithCapacity:5];
                    
                    int naxis;
                    long naxes[2];
                    fits_get_img_dim(fptr, &naxis, &status);
                    fits_get_img_size(fptr, 2, naxes, &status);
                    if (naxis != 2){
                        error = createFITSError(BAD_NAXIS,[NSString stringWithFormat:@"File doesn't contain a 2D image"]);
                    }
                    else{
                        
                        deviceParams[@"width"] = @(naxes[0]);
                        deviceParams[@"height"] = @(naxes[1]);
                        
                        int bps;
                        if (!fits_read_key(fptr,TINT,"BITPIX",(void*)&bps,NULL,&status)){
                            deviceParams[@"bitsPerPixel"] = @(bps);
                        }
                        
                        NSMutableDictionary* device = [NSMutableDictionary dictionaryWithCapacity:5];
                        
                        char name[128];
                        if (!fits_read_key(fptr,TSTRING,"INSTRUME",(void*)name,NULL,&status)){
                            device[@"name"] = [NSString stringWithUTF8String:name];
                        }
                        device[@"params"] = deviceParams;
                        
                        CASExposeParams params;
                        bzero(&params, sizeof(params));
                        
                        params.size = params.frame = CASSizeMake(naxes[0], naxes[1]);
                        params.bps = bps;

//                        long orx = 0;
//                        fits_update_key(fptr, TLONG, "XORGSUBF", (void*)&orx, "X origin of subframe", &status);
//                        long ory = 0;
//                        fits_update_key(fptr, TLONG, "YORGSUBF", (void*)&ory, "Y origin of subframe", &status);

                        int xbin, ybin;
                        if (!fits_read_key(fptr,TINT,"XBINNING",(void*)&xbin,NULL,&status) && !fits_read_key(fptr,TINT,"YBINNING",(void*)&ybin,NULL,&status)){
                            params.bin = CASSizeMake(xbin, ybin);
                        }
                        else {
                            params.bin = CASSizeMake(1, 1);
                        }

                        float ms;
                        if (!fits_read_key(fptr,TFLOAT,"EXPTIME",(void*)&ms,NULL,&status)){
                            params.ms = round(ms);
                        }
                        
                        char type[128];
                        if (!fits_read_key(fptr,TSTRING,"IMAGETYP",(void*)type,NULL,&status)){
                            NSString* nstype = [[NSString stringWithUTF8String:type] lowercaseString];
                            if ([nstype hasPrefix:@"light"]){
                                mmetadata[@"type"] = @(kCASCCDExposureLightType);
                            }
                            else if ([nstype hasPrefix:@"dark"]){
                                mmetadata[@"type"] = @(kCASCCDExposureDarkType);
                            }
                            else if ([nstype hasPrefix:@"bias"]){
                                mmetadata[@"type"] = @(kCASCCDExposureBiasType);
                            }
                            else if ([nstype hasPrefix:@"flat"]){
                                mmetadata[@"type"] = @(kCASCCDExposureFlatType);
                            }
                        }
                        device[@"params"] = deviceParams;

                        char uuid[128];
                        if (!fits_read_key(fptr,TSTRING,"CAS_UUID",(void*)uuid,NULL,&status)){
                            mmetadata[@"uuid"] = [NSString stringWithUTF8String:uuid];
                        }
                        
                        char dateObs[128];
                        if (!fits_read_key(fptr,TSTRING,"DATE-OBS",(void*)dateObs,NULL,&status)){
                            NSDate* date = [self.utcDateFormatter dateFromString:[NSString stringWithUTF8String:dateObs]];
                            if (date){
                                mmetadata[@"time"] = @([date timeIntervalSinceReferenceDate]);
                            }
                        }

                        mmetadata[@"device"] = device;
                        mmetadata[@"exposure"] = NSStringFromCASExposeParams(params);

                        metadata = [mmetadata copy];
                    }
                }
                
                if (shortPixels){
                    exposure.pixels = [NSData dataWithBytesNoCopy:shortPixels length:naxes[0]*naxes[1]*sizeof(UInt16) freeWhenDone:YES];
                }
                if (floatPixels){
                    exposure.floatPixels = [NSData dataWithBytesNoCopy:floatPixels length:naxes[0]*naxes[1]*sizeof(float) freeWhenDone:YES];
                }
                exposure.meta = metadata;
                exposure.params = CASExposeParamsFromNSString([metadata objectForKey:@"exposure"]);
            }
        }
        fits_close_file(fptr, &status);
    }
    
    if (errorPtr){
        *errorPtr = error;
    }

    return (error == nil);
}

- (BOOL)deleteExposure:(CASCCDExposure*)exposure error:(NSError**)errorPtr
{
    return [[NSFileManager defaultManager] removeItemAtURL:self.url error:errorPtr];
}

@end

#endif // CAS_ENABLE_FITS

@implementation CASCCDExposureIO

@synthesize url;

+ (NSString*)sanitizeExposurePath:(NSString*)path
{
    return path;
}

+ (CASCCDExposureIO*)exposureIOWithPath:(NSString*)path
{
    CASCCDExposureIO* exp = nil;
    
    NSString* pathExtension = [path pathExtension];
    if (![pathExtension length]){
        pathExtension = path;
    }
    
    if ([pathExtension isEqualToString:@"rawPixels"]){
        exp = [[CASCCDExposureIOv1 alloc] init];
        exp.url = [NSURL fileURLWithPath:[path stringByDeletingPathExtension]];
    }
    else if ([pathExtension isEqualToString:@"caExposure"]){
        exp = [[CASCCDExposureIOv2 alloc] init];
        exp.url = [NSURL fileURLWithPath:path];
    }
#if CAS_ENABLE_FITS
    else if ([pathExtension isEqualToString:@"fit"] || [pathExtension isEqualToString:@"fits"]){
        exp = [[CASCCDExposureFITS  alloc] init];
        exp.url = [NSURL fileURLWithPath:path];
    }
#endif

    return exp;
}

+ (CASCCDExposure*)exposureWithPath:(NSString*)path readPixels:(BOOL)readPixels error:(NSError**)error
{
    CASCCDExposureIO* io = [CASCCDExposureIO exposureIOWithPath:path];
    if (io){
        CASCCDExposure* exp = [CASCCDExposure new];
        if ([io readExposure:exp readPixels:readPixels error:error]){
            exp.io = io;
            return exp;
        }
    }
    return nil;
}

+ (BOOL)writeExposure:(CASCCDExposure*)exposure toPath:(NSString*)path error:(NSError**)error
{
    CASCCDExposureIO* io = [CASCCDExposureIO exposureIOWithPath:path];
    if (io){
        if ([io writeExposure:exposure writePixels:YES error:error]){
            exposure.io = io;
            return YES;
        }
    }
    return NO;
}

+ (NSString*)defaultFilenameForExposure:(CASCCDExposure*)exposure
{
    NSString* name = exposure.deviceID;
    if (![name length]){
        name = exposure.displayDeviceName;
    }
    if (![name length]){
        name = @"Unknown";
    }
    NSDateFormatter* formatter = [[NSDateFormatter alloc] init];
    formatter.dateFormat = @"LLL-dd-Y";
    name = [name stringByAppendingPathComponent:[formatter stringFromDate:exposure.date]];
    formatter.dateFormat = @"HH-mm-ss.SS";
    name = [name stringByAppendingPathComponent:[formatter stringFromDate:exposure.date]];
    return name;
}

- (NSURL*)derivedURL { return nil; }

- (NSImage*) thumbnail { return nil; }

- (BOOL)writeExposure:(CASCCDExposure*)exposure writePixels:(BOOL)writePixels error:(NSError**)error { return YES; }

- (BOOL)readExposure:(CASCCDExposure*)exposure readPixels:(BOOL)readPixels error:(NSError**)error { return YES; }

- (BOOL)deleteExposure:(CASCCDExposure*)exposure error:(NSError**)error { return YES; }

- (NSURL*)derivedDataURLForName:(NSString*)name { return nil; }

@end

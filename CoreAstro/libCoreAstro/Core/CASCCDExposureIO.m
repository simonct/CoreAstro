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
@end

@implementation CASCCDExposureFITS

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

- (BOOL)writeExposure:(CASCCDExposure*)exposure writePixels:(BOOL)writePixels error:(NSError**)errorPtr
{
    NSError* error = nil;
    
     // '(' & ')' are special characters so replace them with {}
    NSMutableString* s = [NSMutableString stringWithString:[self.url path]];
    [s replaceOccurrencesOfString:@"(" withString:@"{" options:NSLiteralSearch range:NSMakeRange(0, [s length])];
    [s replaceOccurrencesOfString:@")" withString:@"}" options:NSLiteralSearch range:NSMakeRange(0, [s length])];
    [s replaceOccurrencesOfString:@" " withString:@"_" options:NSLiteralSearch range:NSMakeRange(0, [s length])];
    [s replaceOccurrencesOfString:@"-" withString:@"_" options:NSLiteralSearch range:NSMakeRange(0, [s length])];

    NSString* directory = [s stringByDeletingLastPathComponent];
    if (![[NSFileManager defaultManager] createDirectoryAtURL:[NSURL fileURLWithPath:directory] withIntermediateDirectories:YES attributes:nil error:&error]){
        NSLog(@"Failed to create directory for fits file at %@",directory);
    }
    else {
        
        int status = 0;
        fitsfile *fptr;
        
        const char * path = [s fileSystemRepresentation];
        if (fits_create_file(&fptr, path, &status)) {
            error = createFITSError(status,[NSString stringWithFormat:@"Failed to create FITS file %d",status]);
        }
        else {
            
            int format = 0;
            int datatype = 0;
            float scale = 1;
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
                float zero = 0;
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
                        static NSDateFormatter* utcFormatter = nil;
                        static dispatch_once_t onceToken;
                        dispatch_once(&onceToken, ^{
                            utcFormatter = [[NSDateFormatter alloc] init];
                            utcFormatter.timeZone = [NSTimeZone timeZoneWithName:@"UTC"];
                            [utcFormatter setDateFormat:@"yyyy'.'M'.'dd'T'HH':'mm':'ss'.'SSS"];
                        });
                        NSString* dateStr = [utcFormatter stringFromDate:date];
                        if ([dateStr length]){
                            const char* s = [dateStr cStringUsingEncoding:NSASCIIStringEncoding];
                            if (s){
                                fits_update_key(fptr, TSTRING, "DATE-OBS", (void*)s, "acquisition date (UTC)", &status);                            }
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

                    // CCD-TEMP
                    // COLORCCD
                    
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
                    
                    NSData* metaData = [NSJSONSerialization dataWithJSONObject:exposure.meta options:0 error:&error]; // null terminated ???
                    if (!error){
                        const char* metaDataStr = [metaData bytes];
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
                                }
                                @catch (NSException *exception) {
                                    NSLog(@"Exception reading JSON: %@",exception);
                                }
                            }
                            free(data);
                        }
                    }
                }
            }
        }
    }
    
    if (status){
        NSLog(@"Status %d reading exposure metadata",status);
    }
    
    return result;
}

- (BOOL)readExposure:(CASCCDExposure*)exposure readPixels:(BOOL)readPixels error:(NSError**)errorPtr
{
    NSError* error = nil;
    
    NSString* path = [self.url path];
    
    int status = 0;
    fitsfile *fptr;
    int hdutype;
    
    if (fits_open_image(&fptr, [[self.url path] UTF8String], READONLY, &status)){
        error = createFITSError(status,[NSString stringWithFormat:@"Failed to open FITS file %d",status]);
    }
    else {
        
        if (fits_get_hdu_type(fptr, &hdutype, &status) || hdutype != IMAGE_HDU) {
            NSLog(@"CASCCDExposureFITS: FITS file isn't an image %@",path);
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
            NSLog(@"CASCCDExposureFITS: fits_get_img_type: %d",type);
            
            if (status || naxis != 2 || (type != FLOAT_IMG && type != USHORT_IMG && type != SHORT_IMG)) {
                NSLog(@"CASCCDExposureFITS: only 16-bit in or floating point 2D images supported %@",path);
            }
            else {
                
                // get the zero and scaling values
                float zero = 0;
                float scale = 1;
                fits_read_key(fptr,TFLOAT,"BSCALE",(void*)&scale,NULL,&status);
                fits_read_key(fptr,TFLOAT,"BZERO",(void*)&zero,NULL,&status);
                NSLog(@"CASCCDExposureFITS: BSCALE: %f, BZERO: %f",scale,zero);
                
                // create a buffer todo; round to 16 bytes ?
                float* pixels = calloc(naxes[0] * naxes[1],sizeof(float));
                
                if (!pixels){
                    NSLog(@"CASCCDExposureFITS: out of memory");
                    status = memFullErr;
                }
                else {
                    
                    long fpixel[2] = {1,0};
                    float* pix = pixels;
                    
                    for (fpixel[1] = 1; fpixel[1] <= naxes[1]; fpixel[1]++) {
                        
                        // read a row of pixels into the bitmap
                        if (fits_read_pix(fptr,TFLOAT,fpixel,naxes[0],0,pix,0,&status)){
                            NSLog(@"CASCCDExposureFITS: failed to read a row %d: %@",status,path);
                            break;
                        }
                        
                        // handle scale and offset as the contrast stretch code assumes a max value of 65535
                        if (zero != 0 || scale != 1){
                            vDSP_vsmsa(pix,1,&scale,&zero,pix,1,naxes[0]);
                        }
                        
                        // advance the pixel pointer a row
                        pix += (naxes[0]/sizeof(float));
                    }
                }
                
                // metadata
                NSDictionary* metadata = [self readExposureMetadata:fptr];
                if (!metadata){
                    // todo; construct as much metadata from the keys in the image header (remember, -readExposureMetadata: has moved the hdu pointer)
                    NSLog(@"CASCCDExposureFITS: no embedded CoreAstro exposure metadata");
                }
                else{
                    exposure.floatPixels = [NSData dataWithBytesNoCopy:pixels length:naxes[0]*naxes[1]*sizeof(float) freeWhenDone:YES];
                    exposure.meta = metadata;
                    exposure.params = CASExposeParamsFromNSString([metadata objectForKey:@"exposure"]);
                }
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

+ (CASCCDExposureIO*)exposureIOWithPath:(NSString*)path
{
    CASCCDExposureIO* exp = nil;
    
    NSString* const pathExtension = [path pathExtension];
    
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

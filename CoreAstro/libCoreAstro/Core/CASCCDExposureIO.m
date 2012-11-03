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
#import "fitsio.h"

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
        NSDictionary* dict = [NSDictionary dictionaryWithObjectsAndKeys:exposure.meta,@"exposure",[NSNumber numberWithInteger:1],@"version",nil];
        NSData* metaData = [NSJSONSerialization dataWithJSONObject:dict options:0 error:&error];
        if (metaData){
            if ([metaData writeToURL:[self.url URLByAppendingPathComponent:metaName] options:NSDataWritingAtomic error:&error] && writePixels) {
                [exposure.pixels writeToURL:[self.url URLByAppendingPathComponent:samplesName] options:NSDataWritingAtomic error:&error];
            }
        }
        
        // create a thumbnail (could use the QuickLook generator but that then introduces an unnecessary dependency)
        CASCCDImage* image = [exposure createImage];
        if (image){
            const CASSize size = image.size;
            const NSInteger thumbWidth = 256;
            const CASSize thumbSize = CASSizeMake(thumbWidth, thumbWidth * ((float)size.height/(float)size.width));
            CGImageRef thumb = [image createImageWithSize:thumbSize];
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
        
        if (!exposure.hasPixels){
            
            NSFileWrapper* samples = [[wrapper fileWrappers] objectForKey:[self pixelsKey]];
            if (samples){
                exposure.pixels = [NSData dataWithContentsOfURL:[self.url URLByAppendingPathComponent:samples.filename] options:/*NSDataReadingMappedIfSafe|*/NSDataReadingUncached error:&error]; // ** careful with mapping, esp. if editing in place **
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

- (BOOL)writeExposure:(CASCCDExposure*)exposure writePixels:(BOOL)writePixels error:(NSError**)errorPtr
{
    NSError* error = nil;
    
    NSError* (^createFITSError)(NSInteger,NSString*) = ^(NSInteger status,NSString* msg){
        if (status && !msg){
            msg = [NSString stringWithFormat:@"FITS error: %ld",status];
        }
        return [NSError errorWithDomain:@"CASCCDExposureFITS"
                                   code:status
                               userInfo:[NSDictionary dictionaryWithObject:msg forKey:NSLocalizedFailureReasonErrorKey]];
    };
    
     // '(' & ')' are special characters so replace them with {}
    NSMutableString* s = [NSMutableString stringWithString:[self.url path]];
    [s replaceOccurrencesOfString:@"(" withString:@"{" options:NSLiteralSearch range:NSMakeRange(0, [s length])];
    [s replaceOccurrencesOfString:@")" withString:@"}" options:NSLiteralSearch range:NSMakeRange(0, [s length])];
    [s replaceOccurrencesOfString:@" " withString:@"_" options:NSLiteralSearch range:NSMakeRange(0, [s length])];

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
            
            const CASSize size = exposure.actualSize;
            long naxes[2] = { size.width, size.height };
            if ( fits_create_img(fptr, USHORT_IMG, 2, naxes, &status) ){
                error = createFITSError(status,[NSString stringWithFormat:@"Failed to create FITS file %d",status]);
            }
            else {
                
                if ( fits_write_img(fptr, TUSHORT, 1, [exposure.pixels length]/sizeof(uint16_t), (void*)[exposure.pixels bytes], &status) ){
                    error = createFITSError(status,[NSString stringWithFormat:@"Failed to write FITS file %d",status]);
                }
                else {
                    
                    // add basic keywords (from http://heasarc.gsfc.nasa.gov/docs/fcg/standard_dict.html)
                    
                    if ( fits_write_date(fptr, &status) ) {
                        error = createFITSError(status,[NSString stringWithFormat:@"Failed to write FITS metadata %d",status]);
                    }

                    NSString* deviceID = exposure.deviceID;
                    if ([deviceID length]){
                        const char* s = [deviceID cStringUsingEncoding:NSASCIIStringEncoding];
                        if (s){
                            if ( fits_update_key(fptr, TSTRING, "INSTRUME", (void*)s, "acquisition instrument", &status) ) {
                                error = createFITSError(status,[NSString stringWithFormat:@"Failed to write FITS metadata %d",status]);
                            }
                        }
                    }
                    
                    const float exposureMS = exposure.params.ms;
                    if ( fits_update_key(fptr, TFLOAT, "EXPTIME", (void*)&exposureMS, "exposure time in milliseconds", &status) ) {
                        error = createFITSError(status,[NSString stringWithFormat:@"Failed to write FITS metadata %d",status]);
                    }

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
                                if ( fits_update_key(fptr, TSTRING, "DATE-OBS", (void*)s, "acquisition date (UTC)", &status) ) {
                                    error = createFITSError(status,[NSString stringWithFormat:@"Failed to write FITS metadata %d",status]);
                                }
                            }
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

- (BOOL)readExposure:(CASCCDExposure*)exposure readPixels:(BOOL)readPixels error:(NSError**)errorPtr
{
    NSError* error = nil;
    
    error = [NSError errorWithDomain:@"CASCCDExposureFITS"
                                code:unimpErr
                            userInfo:[NSDictionary dictionaryWithObject:@"Reading FITS files is not currently supported" forKey:NSLocalizedFailureReasonErrorKey]];
    
    return (error == nil);
}

- (BOOL)deleteExposure:(CASCCDExposure*)exposure error:(NSError**)errorPtr
{
    return [[NSFileManager defaultManager] removeItemAtURL:self.url error:errorPtr];
}

@end

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
    else if ([pathExtension isEqualToString:@"fit"] || [pathExtension isEqualToString:@"fits"]){
        exp = [[CASCCDExposureFITS  alloc] init];
        exp.url = [NSURL fileURLWithPath:path];
    }

    return exp;
}

+ (NSString*)defaultFilenameForExposure:(CASCCDExposure*)exposure
{
    NSString* name = exposure.deviceID;
    NSDateFormatter* formatter = [[NSDateFormatter alloc] init];
    formatter.dateFormat = @"LLL-d-Y";
    name = [name stringByAppendingPathComponent:[formatter stringFromDate:exposure.date]];
    formatter.dateFormat = @"H-m-ss.SS";
    name = [name stringByAppendingPathComponent:[formatter stringFromDate:exposure.date]];
    return name;
}

- (BOOL)writeExposure:(CASCCDExposure*)exposure writePixels:(BOOL)writePixels error:(NSError**)error { return YES; }

- (BOOL)readExposure:(CASCCDExposure*)exposure readPixels:(BOOL)readPixels error:(NSError**)error { return YES; }

- (BOOL)deleteExposure:(CASCCDExposure*)exposure error:(NSError**)error { return YES; }

@end

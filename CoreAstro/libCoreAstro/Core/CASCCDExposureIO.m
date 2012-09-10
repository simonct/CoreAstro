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

- (BOOL)writeExposure:(CASCCDExposure*)exposure writePixels:(BOOL)writePixels error:(NSError**)errorPtr
{
    NSError* error = nil;
    
    [[NSFileManager defaultManager] createDirectoryAtURL:self.url withIntermediateDirectories:YES attributes:nil error:&error];
    
    NSFileWrapper* wrapper = [[NSFileWrapper alloc] initWithURL:self.url options:0 error:&error];
    if (wrapper){
        
        NSString* metaName = nil;
        NSString* samplesName = nil;
        
        NSDictionary* wrappers = [wrapper fileWrappers];
        if ([wrappers count]){
            metaName = [[wrappers objectForKey:[self metaKey]] filename];
            samplesName = [[wrappers objectForKey:[self pixelsKey]] filename];
        }
        if (!metaName){
            metaName = [wrapper addRegularFileWithContents:nil preferredFilename:[self metaKey]];
        }
        if (!samplesName){
            samplesName = [wrapper addRegularFileWithContents:nil preferredFilename:[self pixelsKey]];
        }
        
        // thumbnail...
        
        NSDictionary* dict = [NSDictionary dictionaryWithObjectsAndKeys:exposure.meta,@"exposure",[NSNumber numberWithInteger:1],@"version",nil];
        NSData* metaData = [NSJSONSerialization dataWithJSONObject:dict options:0 error:&error];
        if (metaData){
            if ([metaData writeToURL:[self.url URLByAppendingPathComponent:metaName] options:NSDataWritingAtomic error:&error] && writePixels) {
                [exposure.pixels writeToURL:[self.url URLByAppendingPathComponent:samplesName] options:NSDataWritingAtomic error:&error];
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

@implementation CASCCDExposureIO

@synthesize url;

+ (CASCCDExposureIO*)exposureIOWithPath:(NSString*)path
{
    CASCCDExposureIO* exp = nil;
    
    if ([[path pathExtension] isEqualToString:@"rawPixels"]){
        exp = [[CASCCDExposureIOv1 alloc] init];
        exp.url = [NSURL fileURLWithPath:[path stringByDeletingPathExtension]];
    }
    else if ([[path pathExtension] isEqualToString:@"caExposure"]){
        exp = [[CASCCDExposureIOv2 alloc] init];
        exp.url = [NSURL fileURLWithPath:path];
    }
    
    return exp;
}

- (BOOL)writeExposure:(CASCCDExposure*)exposure writePixels:(BOOL)writePixels error:(NSError**)error { return YES; }

- (BOOL)readExposure:(CASCCDExposure*)exposure readPixels:(BOOL)readPixels error:(NSError**)error { return YES; }

- (BOOL)deleteExposure:(CASCCDExposure*)exposure error:(NSError**)error { return YES; }

@end
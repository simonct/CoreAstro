//
//  SXIOM25CFixupTool.m
//  SX IO
//
//  Created by Simon Taylor on 02/04/2016.
//  Copyright © 2016 Simon Taylor. All rights reserved.
//

#import "SXIOM25CFixupTool.h"
#import <CoreAstro/CoreAstro.h>

@interface SXIOM25CFixupTool ()
@property (copy) NSString* path;
@property (copy) NSString* saveFolder;
@end

@implementation SXIOM25CFixupTool

- (_Nonnull instancetype)initWithPath:( NSString* _Nonnull )path saveFolder:(NSString* _Nonnull)saveFolder
{
    self = [super init];
    if (self){
        self.path = path;
        self.saveFolder = saveFolder;
    }
    return self;
}

- (NSError*)errorWithCode:(NSInteger)code message:(NSString*)message
{
    return [NSError errorWithDomain:NSStringFromClass([self class])
                               code:code
                           userInfo:@{NSLocalizedFailureReasonErrorKey:message}];
}

- (BOOL)fixupWithError:(NSError**)error
{
    NSParameterAssert(error);
    
    // open fits
    CASCCDExposureIO* io = [CASCCDExposureIO exposureIOWithPath:self.path];
    if (!io){
        *error = [self errorWithCode:1 message:@"Failed to create I/O object for exposure"];
        return NO;
    }
    
    CASCCDExposure* exposure = [[CASCCDExposure alloc] init];
    if (![io readExposure:exposure readPixels:YES error:error]){
        return NO;
    }

    if (exposure.params.bin.width != 1 || exposure.params.bin.height != 1){
        *error = [self errorWithCode:1 message:@"Can only process unbinned images"];
        return NO;
    }
    
    const CASSize size = exposure.actualSize;
    if (size.width != 3032 || size.height != 2016){
        *error = [self errorWithCode:1 message:@"Can only process full frame exposures"];
        return NO;
    }
    
    NSMutableData* fixed = [NSMutableData dataWithLength:exposure.pixels.length];
    if (!fixed){
        *error = [self errorWithCode:1 message:@"Out of memory"];
        return NO;
    }
    
    memcpy(fixed.mutableBytes,exposure.pixels.bytes,fixed.length);

    // fixup pixels, flipping rows in alternate columns
    UInt16* fp = fixed.mutableBytes;
    for (int y = 0; y < size.height; y += 2){
        for (int x = 1; x < size.width; x += 2){
            const UInt16 tmp = fp[x + y * size.width];
            fp[x + y * size.width] = fp[x + (y+1) * size.width];
            fp[x + (y+1) * size.width] = tmp;
        }
    }
    
    memcpy((void*)exposure.pixels.bytes, fixed.mutableBytes, fixed.length);
    
    // save to a new file
    NSString* fixedPath = [[self.saveFolder stringByAppendingPathComponent:self.path.lastPathComponent] stringByAppendingPathExtension:@"fixed.fits"];
    io = [CASCCDExposureIO exposureIOWithPath:fixedPath];
    if (!io){
        *error = [self errorWithCode:1 message:@"Failed to create I/O object for fixed exposure"];
        return NO;
    }
    
    if (![io writeExposure:exposure writePixels:YES error:error]){
        return NO;
    }
    
    return YES;
}

@end

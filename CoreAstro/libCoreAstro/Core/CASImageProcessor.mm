//
//  CASImageProcessor.m
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
//  Basic image processing routines. With the exception of using GCD, completely
//  unoptimised and just begging for some SSE/AVX/OpenCL/vDSP improvements

#import "CoreAstro.h"
#import "CASImageProcessor.h"
#import "CASCCDExposure.h"
#import "CASUtilities.h"
#import <Accelerate/Accelerate.h>
#import <algorithm>

typedef float cas_pixel_t;

@implementation CASImageProcessor

+ (id<CASImageProcessor>)imageProcessorWithIdentifier:(NSString*)ident
{
    CASImageProcessor* result = nil;
    
    if (!ident){
        result = [[CASImageProcessor alloc] init];
    }
    else {
        // consult plugin manager for a plugin of the appropriate type and identifier
    }
    
    return result;
}

- (BOOL)preflightA:(CASCCDExposure*)expA b:(CASCCDExposure*)expB
{
    if (expA.params.size.width != expB.params.size.width ||
        expA.params.size.height != expB.params.size.height ||
        expA.params.bin.width != expB.params.bin.width ||
        expA.params.bin.height != expB.params.bin.height){
        NSLog(@"%@: exposures don't match",NSStringFromSelector(_cmd));
        return NO;
    }
    return YES;
}

- (NSInteger)standardGroupSize
{
    return 4;
}

- (vImage_Buffer)vImageBufferForExposure:(CASCCDExposure*)exposure
{
    const CASSize size = [exposure actualSize];
    vImage_Buffer buffer = {
        (void*)[exposure.floatPixels bytes],
        size.height,
        size.width,
        size.width * sizeof(cas_pixel_t)
    };
    return buffer;
}

- (void)equalise:(CASCCDExposure*)exposure
{
    const NSTimeInterval time = CASTimeBlock(^{

        vImage_Buffer buffer = [self vImageBufferForExposure:exposure];
        
        vImage_Error error = vImageEqualization_PlanarF(&buffer,&buffer,NULL,65536,0,1,kvImageNoFlags);
        if (error != kvImageNoError){
            NSLog(@"vImageEqualization_PlanarF: %ld",error);
        }
    });
    
    NSLog(@"%@: %fs",NSStringFromSelector(_cmd),time);
}

- (void)unsharpMask:(CASCCDExposure*)exposure
{
    NSLog(@"%@: not implemented",NSStringFromSelector(_cmd));
}

- (void)medianFilter:(CASCCDExposure*)exposure
{
    const NSTimeInterval start = [NSDate timeIntervalSinceReferenceDate];
    
    const CASSize size = [exposure actualSize];
    
    const NSInteger groupCount = [self standardGroupSize];
    const NSInteger rowsPerGroup = (size.height - 2) / groupCount;

    NSData* outputData = [NSMutableData dataWithLength:[exposure.floatPixels length]];
    cas_pixel_t* outputPixels = (cas_pixel_t*)[outputData bytes];
    if (!outputPixels){
        NSLog(@"%@: no working pixels",NSStringFromSelector(_cmd));
        return;
    }

    cas_pixel_t* exposurePixels = (cas_pixel_t*)[exposure.floatPixels bytes];

    dispatch_apply(groupCount, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^(size_t groupIndex) {
        
        // todo: AVX
        const NSInteger startRow = 1 + rowsPerGroup * groupIndex;
        const NSInteger rowsInThisGroup = (groupIndex == groupCount - 1) ? rowsPerGroup + (size.height - 2) % rowsPerGroup : rowsPerGroup;
        for (NSInteger y = startRow; y < startRow + rowsInThisGroup; ++y){
            
            for (NSInteger x = 1; x < size.width - 1; ++x){
                
                int i = 0;
                cas_pixel_t window[9];
                for (NSInteger y1 = y-1; y1 <= y+1; ++y1){
                    for (NSInteger x1 = x-1; x1 <= x+1; ++x1){
                        window[i++] = exposurePixels[x1 + y1 * size.width];
                    }
                }
                std::nth_element(window, window + 4, window + 9);
                outputPixels[x + y * size.width] = window[4];
            }
        }
    });
    
    exposure.floatPixels = outputData;
    
    NSLog(@"%@: %fs",NSStringFromSelector(_cmd),[NSDate timeIntervalSinceReferenceDate] - start);
}

- (void)invert:(CASCCDExposure*)exposure
{
    const NSTimeInterval time = CASTimeBlock(^{
        
        const CASSize size = [exposure actualSize];
        
        const NSInteger groupCount = [self standardGroupSize];
        const NSInteger pixelCount = size.width * size.height;
        const NSInteger pixelsPerGroup = pixelCount / groupCount;
        
        cas_pixel_t* exposurePixels = (cas_pixel_t*)[exposure.floatPixels bytes];
        
        dispatch_apply(groupCount, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^(size_t groupIndex) {
            
            // todo: AVX
            const NSInteger offset = pixelsPerGroup * groupIndex;
            const NSInteger pixelsInThisGroup = (groupIndex == groupCount - 1) ? pixelsPerGroup + pixelCount % pixelsPerGroup : pixelsPerGroup;
            for (NSInteger i = offset; i < pixelsInThisGroup + offset; ++i){
                const float pixel = exposurePixels[i];
                exposurePixels[i] = 1.0 - pixel;
            }
        });
    });
    
    NSLog(@"%@: %fs",NSStringFromSelector(_cmd),time);
}

// IC = (IR - IB)
- (void)subtractDark:(CASCCDExposure*)dark from:(CASCCDExposure*)exposure
{
    if (![self preflightA:dark b:exposure]){
        NSLog(@"%@: unsupported",NSStringFromSelector(_cmd));
        return;
    }
 
    const NSTimeInterval start = [NSDate timeIntervalSinceReferenceDate];

    const CASSize size = [exposure actualSize];

    const NSInteger groupCount = [self standardGroupSize];
    const NSInteger pixelCount = size.width * size.height;
    const NSInteger pixelsPerGroup = pixelCount / groupCount;
    
    cas_pixel_t* darkPixels = (cas_pixel_t*)[dark.floatPixels bytes];
    cas_pixel_t* exposurePixels = (cas_pixel_t*)[exposure.floatPixels bytes];
    
    __block NSInteger totalPixels = 0;
    
    dispatch_apply(groupCount, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^(size_t groupIndex) {
        
        // todo: AVX
        const NSInteger offset = pixelsPerGroup * groupIndex;
        const NSInteger pixelsInThisGroup = (groupIndex == groupCount - 1) ? pixelsPerGroup + pixelCount % pixelsPerGroup : pixelsPerGroup;
        for (NSInteger i = offset; i < pixelsInThisGroup + offset; ++i){
            const cas_pixel_t pixel = exposurePixels[i];
            const cas_pixel_t dark = darkPixels[i];
            exposurePixels[i] = pixel > dark ? pixel - dark : 0;
        }
        totalPixels += pixelsInThisGroup;
    });
    
    NSLog(@"%@: %fs, %ld/%ld pixels",NSStringFromSelector(_cmd),[NSDate timeIntervalSinceReferenceDate] - start,totalPixels,pixelCount);
}

// IC = [(IR - IB) * M] / (IF - IB)
- (void)divideFlat:(CASCCDExposure*)flat into:(CASCCDExposure*)exposure
{
    if (![self preflightA:flat b:exposure]){
        NSLog(@"%@: unsupported",NSStringFromSelector(_cmd));
        return;
    }
    
    const NSTimeInterval start = [NSDate timeIntervalSinceReferenceDate];
    
    const CASSize size = [exposure actualSize];

    const NSInteger groupCount = [self standardGroupSize];
    const NSInteger pixelCount = size.width * size.height;
    const NSInteger pixelsPerGroup = pixelCount / groupCount;
    
    cas_pixel_t* flatPixels = (cas_pixel_t*)[flat.floatPixels bytes];
    cas_pixel_t* exposurePixels = (cas_pixel_t*)[exposure.floatPixels bytes];

    __block double* totalPixelValues = (double*)malloc(sizeof(double) * groupCount);
    bzero(totalPixelValues, sizeof(double) * groupCount);
    
    dispatch_apply(groupCount, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^(size_t groupIndex) {
        
        // todo: AVX
        const NSInteger offset = pixelsPerGroup * groupIndex;
        const NSInteger pixelsInThisGroup = (groupIndex == groupCount - 1) ? pixelsPerGroup + pixelCount % pixelsPerGroup : pixelsPerGroup;
        for (NSInteger i = offset; i < pixelsInThisGroup + offset; ++i){
            const double flat = flatPixels[i];
            totalPixelValues[groupIndex] += flat;
        }
    });
    
    double averagePixelValue = 0;
    for (NSInteger i = 0; i < groupCount; ++i){
        averagePixelValue += totalPixelValues[i];
    }
    averagePixelValue /= pixelCount;
    
    free(totalPixelValues);

    dispatch_apply(groupCount, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^(size_t groupIndex) {
        
        // todo: AVX
        const NSInteger offset = pixelsPerGroup * groupIndex;
        const NSInteger pixelsInThisGroup = (groupIndex == groupCount - 1) ? pixelsPerGroup + pixelCount % pixelsPerGroup : pixelsPerGroup;
        for (NSInteger i = offset; i < pixelsInThisGroup + offset; ++i){
            const double pixel = exposurePixels[i];
            const double flat = flatPixels[i];
            const double correction = flat != 0 ? (averagePixelValue / flat) : 1;
            exposurePixels[i] = correction != 0 ? pixel / correction : pixel;
        }
    });

    NSLog(@"%@: %fs",NSStringFromSelector(_cmd),[NSDate timeIntervalSinceReferenceDate] - start);
}

- (CASCCDExposure*)medianSum:(NSArray*)exposures
{
    NSLog(@"%@: not implemented",NSStringFromSelector(_cmd));
    return nil;
}

- (CASCCDExposure*)averageSum:(NSArray*)exposures
{
    // check all the images are the same
    CASCCDExposure* firstExposure = nil;
    for (CASCCDExposure* exposure in exposures){
        if (!firstExposure){
            firstExposure = exposure;
        }
        else {
            if (![self preflightA:firstExposure b:exposure]){
                NSLog(@"%@: unsupported",NSStringFromSelector(_cmd));
                return nil;
            }
        }
    }
    
    const NSTimeInterval start = [NSDate timeIntervalSinceReferenceDate];
    
    // check firstExposure in case there's only one
    
    const CASSize size = [firstExposure actualSize];

    CASCCDExposure* result = [[CASCCDExposure alloc] init];
    
    result.floatPixels = [NSMutableData dataWithLength:size.width * size.height * sizeof(cas_pixel_t)];
    result.params = firstExposure.params;
    
    // check pixels allocated
    
    // what params to set ?
    
    // grab the pixel pointers
    NSInteger index = 0;
    cas_pixel_t** pixels = (cas_pixel_t**)malloc(sizeof(cas_pixel_t*) * [exposures count]);
    for (CASCCDExposure* exposure in exposures){
        pixels[index++] = (cas_pixel_t*)[exposure.floatPixels bytes];
    }
    
    const NSInteger count = [exposures count];
    const NSInteger groupCount = [self standardGroupSize];
    const NSInteger pixelCount = size.width * size.height;
    const NSInteger pixelsPerGroup = pixelCount / groupCount;
    
    cas_pixel_t* average = (cas_pixel_t*)[result.floatPixels bytes];
    
    dispatch_apply(groupCount, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^(size_t groupIndex) {
        
        // todo: AVX
        const NSInteger offset = pixelsPerGroup * groupIndex;
        const NSInteger pixelsInThisGroup = (groupIndex == groupCount - 1) ? pixelsPerGroup + pixelCount % pixelsPerGroup : pixelsPerGroup;
        for (NSInteger i = offset; i < pixelsInThisGroup + offset; ++i){
            
            CGFloat total = 0;
            for (NSInteger j = 0; j < index; ++j){
                total += pixels[j][i];
            }
            average[i] = (cas_pixel_t)(total/count);
        }
    });
    
    free(pixels);
    
    NSLog(@"%@: %fs",NSStringFromSelector(_cmd),[NSDate timeIntervalSinceReferenceDate] - start);
    
    return result;
}

- (NSArray*)histogram:(CASCCDExposure*)exposure
{
    __block NSMutableArray* result = nil;

    const NSTimeInterval time = CASTimeBlock(^{
        
        vImage_Buffer buffer = [self vImageBufferForExposure:exposure];
        
        const NSInteger count = 256;
        vImagePixelCount histogram[count];
        vImageHistogramCalculation_PlanarF(&buffer,histogram,count,0,1,0);
        
        result = [NSMutableArray arrayWithCapacity:count];
        for (NSInteger i = 0; i < count; ++i){
            [result addObject:[NSNumber numberWithUnsignedLong:histogram[i]]];
        }
    });
    
    NSLog(@"%@: %fs",NSStringFromSelector(_cmd),time);
    
    return [result copy];
}

@end

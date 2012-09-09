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
//  unoptimised and just begging for some SSE/AVX/OpenCL improvements

#import "CASImageProcessor.h"
#import "CASCCDExposure.h"
#import <Accelerate/Accelerate.h>
#import <algorithm>

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
        expA.params.bin.height != expB.params.bin.height ||
        expA.params.bps != expB.params.bps){
        NSLog(@"%@: exposures don't match",NSStringFromSelector(_cmd));
        return NO;
    }
    if (expA.params.bps != 16 || expB.params.bps != 16){
        NSLog(@"%@: only works with 16-bit images",NSStringFromSelector(_cmd));
        return NO;
    }
    return YES;
}

- (NSInteger)standardGroupSize
{
    return 4;
}

- (BOOL)_prepareIntBuffer:(vImage_Buffer*)_int16Buffer floatBuffer:(vImage_Buffer*)_floatBuffer fromExposure:(CASCCDExposure*)exposure
{
    _int16Buffer->data = (void*)[exposure.pixels bytes];
    if (!_int16Buffer->data){
        NSLog(@"%@: no source pixels",NSStringFromSelector(_cmd));
        return NO;
    }
    
    const NSInteger width = exposure.params.size.width / exposure.params.bin.width;
    const NSInteger height = exposure.params.size.height / exposure.params.bin.height;
    
    _int16Buffer->width = width;
    _int16Buffer->height = height;
    _int16Buffer->rowBytes = width * 2;
    
    _floatBuffer->data = malloc(width * height * sizeof(float));
    if (!_floatBuffer->data){
        NSLog(@"%@: no working pixels",NSStringFromSelector(_cmd));
        return NO;
    }
    
    _floatBuffer->width = width;
    _floatBuffer->height = height;
    _floatBuffer->rowBytes = width * sizeof(float);
    if (_floatBuffer->data){
        const vImage_Error error = vImageConvert_16UToF(_int16Buffer,_floatBuffer,0,1,kvImageNoFlags);
        if (error != 0){
            NSLog(@"Failed to convert image buffer: %ld",error);
            free(_floatBuffer->data);
            return NO;
        }
    }
    
    return YES;
}

- (void)equalise:(CASCCDExposure*)exposure
{
    if (exposure.params.bps != 16){
        NSLog(@"%@: only works with 16-bit images",NSStringFromSelector(_cmd));
        return;
    }

    const NSTimeInterval start = [NSDate timeIntervalSinceReferenceDate];

    vImage_Buffer _int16Buffer;
    vImage_Buffer _floatBuffer;

    if ([self _prepareIntBuffer:&_int16Buffer floatBuffer:&_floatBuffer fromExposure:exposure]){
        
        vImage_Error error = vImageEqualization_PlanarF(&_floatBuffer,&_floatBuffer,NULL,65536,0,65535,kvImageNoFlags);
        if (error == kvImageNoError){
            error = vImageConvert_FTo16U(&_floatBuffer,&_int16Buffer,0,1,kvImageNoFlags);
        }
    }
        
    NSLog(@"%@: %fs",NSStringFromSelector(_cmd),[NSDate timeIntervalSinceReferenceDate] - start);

    if (_floatBuffer.data){
        free(_floatBuffer.data);
    }
}

- (void)unsharpMask:(CASCCDExposure*)exposure
{
    NSLog(@"%@: not implemented",NSStringFromSelector(_cmd));
}

- (void)medianFilter:(CASCCDExposure*)exposure
{
    if (exposure.params.bps != 16){
        NSLog(@"%@: only works with 16-bit images",NSStringFromSelector(_cmd));
        return;
    }
    
    const NSTimeInterval start = [NSDate timeIntervalSinceReferenceDate];
    
    const CASSize size = [exposure actualSize];
    
    const NSInteger groupCount = [self standardGroupSize];
    const NSInteger rowsPerGroup = (size.height - 2) / groupCount;

    NSData* outputData = [NSMutableData dataWithLength:[exposure.pixels length]];
    uint16_t* outputPixels = (uint16_t*)[outputData bytes];
    if (!outputPixels){
        NSLog(@"%@: no working pixels",NSStringFromSelector(_cmd));
        return;
    }

    uint16_t* exposurePixels = (uint16_t*)[exposure.pixels bytes];

    dispatch_apply(groupCount, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^(size_t groupIndex) {
        
        // todo: AVX
        const NSInteger startRow = 1 + rowsPerGroup * groupIndex;
        const NSInteger rowsInThisGroup = (groupIndex == groupCount - 1) ? rowsPerGroup + (size.height - 2) % rowsPerGroup : rowsPerGroup;
        for (NSInteger y = startRow; y < startRow + rowsInThisGroup; ++y){
            
            for (NSInteger x = 1; x < size.width - 1; ++x){
                
                int i = 0;
                uint16_t window[9];
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
    
    exposure.pixels = outputData;
    
    NSLog(@"%@: %fs",NSStringFromSelector(_cmd),[NSDate timeIntervalSinceReferenceDate] - start);
}

- (void)invert:(CASCCDExposure*)exposure
{
    if (exposure.params.bps != 16){
        NSLog(@"%@: only works with 16-bit images",NSStringFromSelector(_cmd));
        return;
    }
    
    const NSTimeInterval start = [NSDate timeIntervalSinceReferenceDate];
    
    const CASSize size = [exposure actualSize];
    
    const NSInteger groupCount = [self standardGroupSize];
    const NSInteger pixelCount = size.width * size.height;
    const NSInteger pixelsPerGroup = pixelCount / groupCount;
    
    uint16_t* exposurePixels = (uint16_t*)[exposure.pixels bytes];
        
    dispatch_apply(groupCount, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^(size_t groupIndex) {
        
        // todo: AVX
        const NSInteger offset = pixelsPerGroup * groupIndex;
        const NSInteger pixelsInThisGroup = (groupIndex == groupCount - 1) ? pixelsPerGroup + pixelCount % pixelsPerGroup : pixelsPerGroup;
        for (NSInteger i = offset; i < pixelsInThisGroup + offset; ++i){
            const uint16_t pixel = exposurePixels[i];
            exposurePixels[i] = 65535 - pixel;
        }
    });
    
    NSLog(@"%@: %fs",NSStringFromSelector(_cmd),[NSDate timeIntervalSinceReferenceDate] - start);
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
    
    uint16_t* darkPixels = (uint16_t*)[dark.pixels bytes];
    uint16_t* exposurePixels = (uint16_t*)[exposure.pixels bytes];
    
    __block NSInteger totalPixels = 0;
    
    dispatch_apply(groupCount, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^(size_t groupIndex) {
        
        // todo: AVX
        const NSInteger offset = pixelsPerGroup * groupIndex;
        const NSInteger pixelsInThisGroup = (groupIndex == groupCount - 1) ? pixelsPerGroup + pixelCount % pixelsPerGroup : pixelsPerGroup;
        for (NSInteger i = offset; i < pixelsInThisGroup + offset; ++i){
            const uint16_t pixel = exposurePixels[i];
            const uint16_t dark = darkPixels[i];
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
    
    uint16_t* flatPixels = (uint16_t*)[flat.pixels bytes];
    uint16_t* exposurePixels = (uint16_t*)[exposure.pixels bytes];

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
    
    result.pixels = [NSMutableData dataWithLength:size.width * size.height * sizeof(uint16_t)];
    result.params = firstExposure.params;
    
    // check pixels allocated
    
    // what params to set ?
    
    // grab the pixel pointers
    NSInteger index = 0;
    uint16_t** pixels = (uint16_t**)malloc(sizeof(uint16_t*) * [exposures count]);
    for (CASCCDExposure* exposure in exposures){
        pixels[index++] = (uint16_t*)[exposure.pixels bytes];
    }
    
    const NSInteger count = [exposures count];
    const NSInteger groupCount = [self standardGroupSize];
    const NSInteger pixelCount = size.width * size.height;
    const NSInteger pixelsPerGroup = pixelCount / groupCount;
    
    uint16_t* average = (uint16_t*)[result.pixels bytes];
    
    dispatch_apply(groupCount, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^(size_t groupIndex) {
        
        // todo: AVX
        const NSInteger offset = pixelsPerGroup * groupIndex;
        const NSInteger pixelsInThisGroup = (groupIndex == groupCount - 1) ? pixelsPerGroup + pixelCount % pixelsPerGroup : pixelsPerGroup;
        for (NSInteger i = offset; i < pixelsInThisGroup + offset; ++i){
            
            CGFloat total = 0;
            for (NSInteger j = 0; j < index; ++j){
                total += pixels[j][i];
            }
            average[i] = (uint16_t)(total/count);
        }
    });
    
    free(pixels);
    
    NSLog(@"%@: %fs",NSStringFromSelector(_cmd),[NSDate timeIntervalSinceReferenceDate] - start);
    
    return result;
}

- (NSArray*)histogram:(CASCCDExposure*)exposure
{
    if (exposure.params.bps != 16){
        NSLog(@"%@: only works with 16-bit images",NSStringFromSelector(_cmd));
        return nil;
    }
    
    const NSTimeInterval start = [NSDate timeIntervalSinceReferenceDate];
    
    vImage_Buffer _int16Buffer;
    vImage_Buffer _floatBuffer;

    NSMutableArray* result = nil;
    
    if ([self _prepareIntBuffer:&_int16Buffer floatBuffer:&_floatBuffer fromExposure:exposure]){
        
        const NSInteger count = 256;
        vImagePixelCount histogram[count];
        vImageHistogramCalculation_PlanarF(&_floatBuffer,histogram,count,0,65535,0);
        
        result = [NSMutableArray arrayWithCapacity:count];
        for (NSInteger i = 0; i < count; ++i){
            [result addObject:[NSNumber numberWithUnsignedLong:histogram[i]]];
        }
    }
    
    NSLog(@"%@: %fs",NSStringFromSelector(_cmd),[NSDate timeIntervalSinceReferenceDate] - start);
    
    if (_floatBuffer.data){
        free(_floatBuffer.data);
    }
    
    return [result copy];
}

@end

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

#import "CASImageProcessor.h"
#import "CASCCDExposure.h"
#import "CASUtilities.h"
#import <Accelerate/Accelerate.h>
#import <algorithm>

typedef float cas_pixel_t;
typedef struct { float r,g,b,a; } cas_fpixel_t;

@implementation CASImageProcessor {
    void* _equalisationBuffer;
    size_t _equalisationBufferSize;
}

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

- (void)dealloc
{
    if (_equalisationBuffer){
        free(_equalisationBuffer);
    }
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
        exposure.rgba ? size.width * sizeof(float) * 4 : size.width * sizeof(cas_pixel_t)
    };
    return buffer;
}

- (void)allocateEqualisationBufferWithSize:(size_t)size
{
    if (!_equalisationBuffer || _equalisationBufferSize != size){
        if (!_equalisationBuffer){
            _equalisationBuffer = malloc(size);
        }
        else {
            _equalisationBuffer = realloc(_equalisationBuffer, size);
        }
        if (_equalisationBuffer){
            _equalisationBufferSize = size;
        }
        else {
            _equalisationBufferSize = 0;
        }
    }
}

- (CASCCDExposure*)equalise:(CASCCDExposure*)exposure_
{
    __block CASCCDExposure* result = nil;

    const NSInteger numberOfBins = 4096;
    
    const NSTimeInterval time = CASTimeBlock(^{

        result = [exposure_ copy]; // returns a floating point exposure
        if (!result){
            NSLog(@"%@: out of memory",NSStringFromSelector(_cmd));
        }
        else {
            
            vImage_Buffer buffer = [self vImageBufferForExposure:result];
            
            vImage_Error error = kvImageNoError;
            if (result.rgba){
                
                error = vImageEqualization_ARGBFFFF(&buffer,&buffer,nil,numberOfBins,0,1,kvImageGetTempBufferSize); // docs state that this still works even though the source data is RGBA not ARGB
                if (error > 0){
                    [self allocateEqualisationBufferWithSize:error];
                    if (!_equalisationBuffer){
                        error = memFullErr;
                    }
                    else {
                        error = vImageEqualization_ARGBFFFF(&buffer,&buffer,_equalisationBuffer,numberOfBins,0,1,kvImageNoFlags);
                    }
                }
                if (error != kvImageNoError){
                    NSLog(@"vImageEqualization_ARGBFFFF: %ld",error);
                }
            }
            else {
                
                error = vImageEqualization_PlanarF(&buffer,&buffer,NULL,numberOfBins,0,1,kvImageGetTempBufferSize);
                if (error > 0){
                    [self allocateEqualisationBufferWithSize:error];
                    if (!_equalisationBuffer){
                        error = memFullErr;
                    }
                    else {
                        error = vImageEqualization_PlanarF(&buffer,&buffer,_equalisationBuffer,numberOfBins,0,1,kvImageNoFlags);
                    }
                }
                if (error != kvImageNoError){
                    NSLog(@"vImageEqualization_PlanarF: %ld",error);
                }
            }
        }
    });
    
    NSLog(@"%@: %fs",NSStringFromSelector(_cmd),time);
    
    return result;
}

- (CASCCDExposure*)unsharpMask:(CASCCDExposure*)exposure
{
    NSLog(@"%@: not implemented",NSStringFromSelector(_cmd));
    return nil;
}

- (CASCCDExposure*)medianFilter:(CASCCDExposure*)exposure_
{
    const NSTimeInterval start = [NSDate timeIntervalSinceReferenceDate];
    
    const CASSize size = [exposure_ actualSize];
    
    const NSInteger groupCount = [self standardGroupSize];
    const NSInteger rowsPerGroup = (size.height - 2) / groupCount;

    __block CASCCDExposure* result = [exposure_ copy]; // returns a floating point exposure
    if (!result){
        NSLog(@"%@: out of memory",NSStringFromSelector(_cmd));
    }
    else{
        
        cas_pixel_t* exposurePixels = (cas_pixel_t*)[exposure_.floatPixels bytes];
        cas_pixel_t* outputPixels = (cas_pixel_t*)[result.floatPixels bytes];

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
    }
    
    NSLog(@"%@: %fs",NSStringFromSelector(_cmd),[NSDate timeIntervalSinceReferenceDate] - start);
    
    return result;
}

- (CASCCDExposure*)invert:(CASCCDExposure*)exposure_
{
    __block CASCCDExposure* result = [exposure_ copy]; // returns a floating point exposure
    if (!result){
        NSLog(@"%@: out of memory",NSStringFromSelector(_cmd));
    }
    else{
        
        const NSTimeInterval time = CASTimeBlock(^{
            
            const CASSize size = [result actualSize];
            
            const NSInteger groupCount = [self standardGroupSize];
            const NSInteger pixelCount = size.width * size.height;
            const NSInteger pixelsPerGroup = pixelCount / groupCount;
            
            if (result.rgba){
                
                cas_fpixel_t* exposurePixels = (cas_fpixel_t*)[result.floatPixels bytes];
                
                dispatch_apply(groupCount, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^(size_t groupIndex) {
                    
                    // todo: AVX
                    const NSInteger offset = pixelsPerGroup * groupIndex;
                    const NSInteger pixelsInThisGroup = (groupIndex == groupCount - 1) ? pixelsPerGroup + pixelCount % pixelsPerGroup : pixelsPerGroup;
                    for (NSInteger i = offset; i < pixelsInThisGroup + offset; ++i){
                        cas_fpixel_t pixel = exposurePixels[i];
                        pixel.r = 1.0 - pixel.r;
                        pixel.g = 1.0 - pixel.g;
                        pixel.b = 1.0 - pixel.b;
                        pixel.a = 1.0 - pixel.a;
                        exposurePixels[i] = pixel;
                    }
                });
            }
            else {
                cas_pixel_t* exposurePixels = (cas_pixel_t*)[result.floatPixels bytes];
                
                dispatch_apply(groupCount, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^(size_t groupIndex) {
                    
                    // todo: AVX
                    const NSInteger offset = pixelsPerGroup * groupIndex;
                    const NSInteger pixelsInThisGroup = (groupIndex == groupCount - 1) ? pixelsPerGroup + pixelCount % pixelsPerGroup : pixelsPerGroup;
                    for (NSInteger i = offset; i < pixelsInThisGroup + offset; ++i){
                        const float pixel = exposurePixels[i];
                        exposurePixels[i] = 1.0 - pixel;
                    }
                });
            }
        });

        NSLog(@"%@: %fs",NSStringFromSelector(_cmd),time);
    }
    
    return result;
}

- (CASCCDExposure*)normalise:(CASCCDExposure*)exposure
{
    __block CASCCDExposure* result = [exposure copy]; // returns a floating point exposure
    if (!result){
        NSLog(@"%@: out of memory",NSStringFromSelector(_cmd));
    }
    else{
        
        // get average flat value
        float average = 0;
        float* fbuf = (float*)[result.floatPixels bytes];
        vDSP_meamgv(fbuf,1,&average,[result.floatPixels length]/sizeof(float));
        
        if (average != 0){
            
            // divide by the average
            vDSP_vsdiv(fbuf,1,(float*)&average,fbuf,1,[result.floatPixels length]/sizeof(float));
        }
    }
    
    return result;
}

- (CASCCDExposure*)removeBayerMatrix:(CASCCDExposure*)exposure_
{
    __block CASCCDExposure* result = [exposure_ copy]; // returns a floating point exposure
    if (!result){
        NSLog(@"%@: out of memory",NSStringFromSelector(_cmd));
    }
    else{
        
        const NSTimeInterval time = CASTimeBlock(^{
            
            const CASSize size = [result actualSize];

            vImage_Buffer source = [self vImageBufferForExposure:result];
            
            vImage_Buffer destination = {
                (void*)malloc(size.height/2 * size.width/2 * sizeof(cas_pixel_t)),
                size.height/2,
                size.width/2,
                size.width/2 * sizeof(cas_pixel_t)
            };
            
            if (!source.data || !destination.data){
                NSLog(@"%@: out of memory",NSStringFromSelector(_cmd));
            }
            else {
                
                // scale down to half size
                vImageScale_PlanarF(&source,&destination,nil,kvImageHighQualityResampling);
                
                // scale back up to full size
                vImageScale_PlanarF(&destination,&source,nil,kvImageHighQualityResampling);
                
                // probably a better way of doing this with a convolution filter ?
                
                // cleanup
                free(destination.data);
            }
        });
        
        NSLog(@"%@: %fs",NSStringFromSelector(_cmd),time);
    }
    
    return result;
}

- (CASCCDExposure*)luminance:(CASCCDExposure*)exposure
{
    if (!exposure.rgba){
        return exposure;
    }
    
    __block CASCCDExposure* result = [exposure copy];
    if (!result){
        NSLog(@"%@: out of memory",NSStringFromSelector(_cmd));
    }
    else{
        
        typedef struct { float r,g,b,a; } rgba_pixel_t;
        
        const CASSize size = result.actualSize;
        const NSInteger count = size.width * size.height;
        
        result.floatPixels = [NSMutableData dataWithLength:count * sizeof(float)];
        result.format = kCASCCDExposureFormatFloat;
        
        float* fp = (float*)[result.floatPixels bytes];
        rgba_pixel_t* rgbp = (rgba_pixel_t*)[exposure.floatPixels bytes];
        if (fp && rgbp){
            
            dispatch_apply(size.height, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^(size_t row) {
                
                float* fp1 = fp + row * size.width;
                rgba_pixel_t* rgbp1 = rgbp + row * size.width;
                for (NSInteger i = 0; i < size.width; i++, fp1++, rgbp1++){
                    *fp1 = MIN(1.0,(0.2126*rgbp1->r) + (0.7152*rgbp1->g) + (0.0722*rgbp1->b));
                }
            });
        }
    }
    
    return result;
}

// IC = (IR - IB)
- (CASCCDExposure*)subtract:(CASCCDExposure*)darkOrBias from:(CASCCDExposure*)exposure
{
    if (![self preflightA:darkOrBias b:exposure]){
        NSLog(@"%@: unsupported",NSStringFromSelector(_cmd));
        return nil;
    }
 
    __block CASCCDExposure* result = [exposure copy]; // returns a floating point exposure
    if (!result){
        NSLog(@"%@: out of memory",NSStringFromSelector(_cmd));
    }
    else{

        float* fbuf = (float*)[result.floatPixels bytes];
        float* fdarkOrBias = (float*)[darkOrBias.floatPixels bytes];
        if (!fbuf || !fdarkOrBias){
            NSLog(@"%@: Out of memory",NSStringFromSelector(_cmd));
            result = nil;
        }
        else {
            vDSP_vsub(fdarkOrBias,1,fbuf,1,fbuf,1,[result.floatPixels length]/sizeof(float));
        }
    }
    
    return result;
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
            [result addObject:[NSNumber numberWithFloat:(float)histogram[i]]];
        }
    });
    
    NSLog(@"%@: %fs",NSStringFromSelector(_cmd),time);
    
    return [result copy];
}

- (CGFloat)medianPixelValue:(CASCCDExposure*)exposure
{
    float median = 0;
    
    if ([exposure.floatPixels length]){
        float* copy = (float*)malloc([exposure.floatPixels length]);
        if (copy){
            memcpy(copy, [exposure.floatPixels bytes], [exposure.floatPixels length]);
            const size_t count = [exposure.floatPixels length]/sizeof(float);
            vDSP_vsort(copy,count,1);
            median = copy[count/2]; // todo; average of two middle values if count is even
            free(copy);
        }
    }
    
    return median;
}

- (CGFloat)averagePixelValue:(CASCCDExposure*)exposure
{
    float average = 0;

    if (exposure.floatPixels){
        vDSP_meamgv((float*)[exposure.floatPixels bytes],1,&average,[exposure.floatPixels length]/sizeof(float));
    }

    return average;
}

- (CGFloat)minimumPixelValue:(CASCCDExposure*)exposure
{
    float min = 0;
    
    if (exposure.floatPixels){
        vDSP_minmgv((float*)[exposure.floatPixels bytes],1,&min,[exposure.floatPixels length]/sizeof(float));
    }
    
    return min;
}

- (CGFloat)maximumPixelValue:(CASCCDExposure*)exposure
{
    float max = 0;
    
    if (exposure.floatPixels){
        vDSP_maxmgv((float*)[exposure.floatPixels bytes],1,&max,[exposure.floatPixels length]/sizeof(float));
    }
    
    return max;
}

- (CGFloat)standardDeviationPixelValue:(CASCCDExposure*)exposure
{
    float stdev = 0;
    
    if (exposure.floatPixels){
        
        NSMutableData* working = [NSMutableData dataWithLength:[exposure.floatPixels length]];
        if (working){
            
            // calculate the average
            float average = 0;
            vDSP_meamgv((float*)[exposure.floatPixels bytes],1,&average,[exposure.floatPixels length]/sizeof(float));
                        
            // create a vector of signal - mean
            float minusAverage = -average;
            vDSP_vsadd((float*)[exposure.floatPixels bytes],1,&minusAverage,(float*)[working mutableBytes],1,[working length]/sizeof(float));
            
            // square all the values in the difference vector
            vDSP_vsq((float*)[working mutableBytes],1,(float*)[working mutableBytes],1,[working length]/sizeof(float));
            
            // calculate average
            vDSP_meamgv((float*)[working mutableBytes],1,&average,[working length]/sizeof(float));
            
            // take square root
            stdev = sqrtf(average);
        }
    }
    
    return stdev;
}

- (CASContrastStretchBounds)linearContrastStretchBoundsForExposure:(CASCCDExposure*)exposure
                                                        lowerLimit:(float)lowerLimit
                                                        upperLimit:(float)upperLimit
                                                     maxPixelValue:(float)maxPixelValue
{
    __block CASContrastStretchBounds result = {0,0,0};
    
    float* pixels = (float*)[exposure.floatPixels bytes];
    if (pixels){

        const NSTimeInterval time = CASTimeBlock(^{
            
            vImage_Buffer buffer = [self vImageBufferForExposure:exposure];
            
            const NSInteger binCount = 4096;
            vImagePixelCount* histogram = (vImagePixelCount*)malloc(sizeof(vImagePixelCount) * binCount);
            
            vImageHistogramCalculation_PlanarF(&buffer,histogram,binCount,0,maxPixelValue,kvImageNoFlags);
            
            if (0){
                NSMutableString* s = [NSMutableString new];
                for (int i = 0; i < binCount; ++i){
                    [s appendFormat:@"%lu ",histogram[i]];
                }
                NSLog(@"%@",s);
            }

            const CASSize actualSize = exposure.actualSize;
            const size_t pixelCount = actualSize.width*actualSize.height;
            
            const float lowerThreshold = pixelCount * lowerLimit;
            const float upperThreshold = pixelCount * upperLimit;
            const float pixelsPerBin = maxPixelValue / (float)binCount;
            
            NSUInteger total = 0;
            result.lower = -1;
            result.upper = -1;
            result.maxPixelValue = maxPixelValue;
            for (NSInteger bin = 0; bin < binCount; ++bin){
                
                total += histogram[bin];
                if (result.lower == -1 && total >= lowerThreshold){
                    result.lower = bin * pixelsPerBin;
                }
                if (result.upper == -1 && total >= upperThreshold){
                    result.upper = bin * pixelsPerBin;
                }
            }
            
            if (result.lower == -1){
                result.lower = 0;
            }
            if (result.upper == -1){
                result.upper = maxPixelValue;
            }
            
            //            NSLog(@"CASFITSPreviewer: lower %ld, upper %ld, pixelsPerBin: %ld",(unsigned long)lower,(unsigned long)upper,pixelsPerBin);
            
//            const float scaler = maxPixelValue/(upper - lower);
//            for (int i = 0; i < pixelCount; ++i){
//                const float p = pixels[i];
//                if (p < lower){
//                    pixels[i] = 0;
//                }
//                else if (p > upper){
//                    pixels[i] = maxPixelValue;
//                }
//                else {
//                    pixels[i] = (p - lower)*scaler;
//                }
//            }
            
            free(histogram);
        });
        
        NSLog(@"%@: %fs",NSStringFromSelector(_cmd),time);
    }
    
    return result;
}

- (CASCCDExposure*)rescaleExposure:(CASCCDExposure*)exposure linearContrastStretchBounds:(CASContrastStretchBounds)bounds
{
    __block CASCCDExposure* result = [exposure copy];
    if (!result){
        NSLog(@"%@: out of memory",NSStringFromSelector(_cmd));
    }
    else{
        
        const NSTimeInterval time = CASTimeBlock(^{
            
            float* pixels = (float*)[exposure.floatPixels bytes];
            if (pixels){
                
                const CASSize actualSize = exposure.actualSize;
                const size_t pixelCount = actualSize.width*actualSize.height;
                
                const float scaler = bounds.maxPixelValue/(bounds.upper - bounds.lower);
                for (int i = 0; i < pixelCount; ++i){
                    const float p = pixels[i];
                    if (p < bounds.lower){
                        pixels[i] = 0;
                    }
                    else if (p > bounds.upper){
                        pixels[i] = bounds.maxPixelValue;
                    }
                    else {
                        pixels[i] = (p - bounds.lower)*scaler;
                    }
                }
            }
        });
        
        NSLog(@"%@: %fs",NSStringFromSelector(_cmd),time);
    }
    
    return nil;
}

@end

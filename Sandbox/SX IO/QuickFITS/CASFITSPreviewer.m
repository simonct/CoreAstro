//
//  CASFITSPreviewer.m
//  QuickFITS
//
//  Created by Simon Taylor on 8/24/13.
//  Copyright (c) 2013 Simon Taylor. All rights reserved.
//

#import "CASFITSPreviewer.h"
#import "fitsio.h"
#import <Accelerate/Accelerate.h>

const float kMaxPixelValue = 65535.0;

@implementation CASFITSPreviewer

- (CGImageRef)imageFromURL:(NSURL*)url error:(NSError**)error
{
    int status = noErr;
    CGImageRef result = nil;
    
    int hdutype;
    fitsfile *fptr;
    NSString* path = [url path];
    
    // open the fits file
    if (fits_open_image(&fptr, [path UTF8String], READONLY, &status)) {
        return nil;
    }
    
    // get the data type, check it's an image
    if (fits_get_hdu_type(fptr, &hdutype, &status) || hdutype != IMAGE_HDU) {
        NSLog(@"CASFITSPreviewer: FITS file isn't an image %@",path);
    }
    else {
        
        // get the image dimensions
        int naxis;
        long naxes[2];
        fits_get_img_dim(fptr, &naxis, &status);
        fits_get_img_size(fptr, 2, naxes, &status);
        
        if (status || naxis != 2) {
            NSLog(@"CASFITSPreviewer: only 2D images supported %@",path);
        }
        else {
            
            // create a floating point image
            CGColorSpaceRef space = CGColorSpaceCreateWithName(kCGColorSpaceGenericGray);
            CGContextRef context = CGBitmapContextCreate(nil, naxes[0], naxes[1], 32, naxes[0] * sizeof(float), space, kCGImageAlphaNone|kCGBitmapFloatComponents|kCGBitmapByteOrder32Little);
            CFRelease(space);
            
            if (!context){
                NSLog(@"CASFITSPreviewer: out of memory");
                status = memFullErr;
            }
            else {
                
                long fpixel[2] = {1,0};
                float* pix = CGBitmapContextGetData(context);
                
                for (fpixel[1] = 1; fpixel[1] <= naxes[1]; fpixel[1]++) {
                    
                    // read a row of pixels into the bitmap
                    if (fits_read_pix(fptr,TFLOAT,fpixel,naxes[0],0,pix,0,&status)){
                        NSLog(@"CASFITSPreviewer: failed to read a row %d: %@",status,path);
                        break;
                    }
                    
                    // advance the pixel pointer a row
                    pix += (CGBitmapContextGetBytesPerRow(context)/sizeof(float));
                }
                
                // scale the pixels to 0->1 (use vDSP ?)
                [self contrastStretchPixels:context count:naxes[0] * naxes[1]];
                
                // create the image
                result = CGBitmapContextCreateImage(context);
                if (!result){
                    NSLog(@"CASFITSPreviewer: out of memory");
                    status = memFullErr;
                }
                
                CGContextRelease(context);
            }
        }
    }
    
    fits_close_file(fptr, &status);
    
    return result;
}

- (void)contrastStretchPixels:(CGContextRef)context count:(NSInteger)count
{
    float* pix = CGBitmapContextGetData(context);
    
    float average = 0, min = kMaxPixelValue, max = 0;
    for (NSInteger i = 0; i < count; i++) {
        average += pix[i];
        min = MIN(min, pix[i]);
        max = MAX(max, pix[i]);
    }
    average /= count;

    NSLog(@"CASFITSPreviewer (before stretch): average: %f, min: %f, max: %f",average,min,max);

    if (0){
        
        const float scaler = kMaxPixelValue/(max - min);
        for (int i = 0; i < count; ++i){
            pix[i] = (pix[i] - min) * scaler;
        }
    }
    else {
        
        vImage_Buffer buffer = {
            (void*)CGBitmapContextGetData(context),
            CGBitmapContextGetHeight(context),
            CGBitmapContextGetWidth(context),
            CGBitmapContextGetBytesPerRow(context)
        };
        
        const NSInteger count = 256;
        vImagePixelCount histogram[count];
        vImageHistogramCalculation_PlanarF(&buffer,histogram,count,0,kMaxPixelValue,kvImageNoFlags);
        
        const NSUInteger pixelCount = buffer.width * buffer.height;
        const NSInteger pixelsPerBin = round(kMaxPixelValue / (float)count);
        const float lowerThreshold = pixelCount * 0.05;
        const float upperThreshold = pixelCount * 0.95;
        
        NSUInteger total = 0;
        NSUInteger lower = -1;
        NSUInteger upper = -1;
        for (NSInteger bin = 0; bin < count; ++bin){
            
            total += histogram[bin];
            if (lower == -1 && total >= lowerThreshold){
                lower = bin * pixelsPerBin;
            }
            if (upper == -1 && total >= upperThreshold){
                upper = bin * pixelsPerBin;
            }
        }
        
        NSLog(@"CASFITSPreviewer: lower %ld, upper %ld, pixelsPerBin: %ld",(unsigned long)lower,(unsigned long)upper,pixelsPerBin);
        
        float* pix = CGBitmapContextGetData(context);
        const float scaler = kMaxPixelValue/(upper - lower);
        for (int i = 0; i < count; ++i){
            const float p = pix[i];
            if (p < lower){
                pix[i] = 0;
            }
            else if (p > upper){
                pix[i] = kMaxPixelValue;
            }
            else {
                pix[i] = (pix[i] - min)*scaler;
            }
        }
    }

    for (int i = 0; i < count; ++i){
        pix[i] /= kMaxPixelValue;
    }

    average = max = 0, min = kMaxPixelValue;
    for (int i = 0; i < count; ++i){
        average += pix[i];
        min = MIN(min, pix[i]);
        max = MAX(max, pix[i]);
    }
    average /= count;
    
    NSLog(@"CASFITSPreviewer (after stretch): average: %f, min: %f, max: %f",average,min,max);
}

@end

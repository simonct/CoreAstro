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

// from CASFITSUtilities - todo; link to CA framework instead
int cas_fits_open_image(fitsfile **fptr,const char* path,int mode,int* status)
{
    *status = fits_open_diskfile(fptr,path,mode,status);
    if (!*status){
        
        // from fits_open_image
        int hdutype;
        if (ffghdt(*fptr, &hdutype, status) <= 0) {
            if (hdutype != IMAGE_HDU)
                *status = NOT_IMAGE;
        }
    }
    return *status;
}

@implementation CASFITSPreviewer

- (CGImageRef)newImageFromURL:(NSURL*)url error:(NSError**)error
{
    int status = noErr;
    CGImageRef result = nil;
    
    int hdutype;
    fitsfile *fptr;
    NSString* path = [url path];
    
    // open the fits file
    if (cas_fits_open_image(&fptr, [path UTF8String], READONLY, &status)) {
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
        
        // get the pixel format
        int type;
        fits_get_img_type(fptr,&type,&status);
        NSLog(@"CASFITSPreviewer: fits_get_img_type: %d",type);

        if (status || naxis != 2 || (type != FLOAT_IMG && type != USHORT_IMG && type != SHORT_IMG)) {
            NSLog(@"CASFITSPreviewer: only 16-bit in or floating point 2D images supported %@",path);
        }
        else {
            
            // get the zero and scaling values
            float zero = 0;
            float scale = 1;
            fits_read_key(fptr,TFLOAT,"BSCALE",(void*)&scale,NULL,&status); status = 0;
            fits_read_key(fptr,TFLOAT,"BZERO",(void*)&zero,NULL,&status); status = 0;
            NSLog(@"CASFITSPreviewer: BSCALE: %f, BZERO: %f",scale,zero);

            // create a floating point bitmap context
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
                    
                    // handle scale and offset as the contrast stretch code assumes images with a range of 0-65535
                    if (zero == 0 && scale == 1){
                        zero = 0;
                        scale = 65535;
                        vDSP_vsmsa(pix,1,&scale,&zero,pix,1,naxes[0]);
                    }
                    else {
                        vDSP_vsmsa(pix,1,&scale,&zero,pix,1,naxes[0]);
                    }
                    
                    // advance the pixel pointer a row
                    pix += (CGBitmapContextGetBytesPerRow(context)/sizeof(float));
                }
                
                // scale the pixels to 0->1 (use vDSP ?)
                [self contrastStretchPixels:context];
                
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

- (void)contrastStretchPixels:(CGContextRef)context
{
    if (!context){
        return;
    }
    
    float* pix = CGBitmapContextGetData(context);
    if (!pix){
        return;
    }

    const size_t width = CGBitmapContextGetWidth(context);
    const size_t height = CGBitmapContextGetHeight(context);
    const size_t stride = CGBitmapContextGetBytesPerRow(context)/sizeof(float);
    const size_t pixelCount = width*height;
    
//    NSLog(@"width: %ld height: %ld stride: %ld count: %ld",width,height,stride,pixelCount);

    __block float average, min, max;

    void (^calcPixelStats)() = ^(){
        
        average = 0, min = kMaxPixelValue, max = 0;
        
        float* p = pix;
        for (int y = 0; y < height; ++y){
            for (int x = 0; x < width; ++x){
                const float pv = p[x];
                average += pv;
                min = MIN(min, pv);
                max = MAX(max, pv);
            }
            p += stride;
        }
        average /= pixelCount;
    };
    
    calcPixelStats();
//    NSLog(@"CASFITSPreviewer (before stretch): average: %f, min: %f, max: %f",average,min,max);

    if (0){
        
        const float scaler = kMaxPixelValue/(max - min);
        for (int i = 0; i < pixelCount; ++i){
            pix[i] = (pix[i] - min) * scaler;
        }
    }
    else {
        
        vImage_Buffer buffer = {
            pix,
            CGBitmapContextGetHeight(context),
            CGBitmapContextGetWidth(context),
            CGBitmapContextGetBytesPerRow(context)
        };

        const NSInteger binCount = 4096;
        vImagePixelCount* histogram = malloc(sizeof(vImagePixelCount) * binCount);
        if (!histogram){
            NSLog(@"CASFITSPreviewer: out of memory");
        }
        else{
        
            vImageHistogramCalculation_PlanarF(&buffer,histogram,binCount,0,kMaxPixelValue,kvImageNoFlags);
            
            const float lowerThreshold = pixelCount * 0.005;
            const float upperThreshold = pixelCount * 0.995;
            const NSInteger pixelsPerBin = round(kMaxPixelValue / (float)binCount);
            
            NSUInteger total = 0;
            NSUInteger lower = -1;
            NSUInteger upper = -1;
            for (NSInteger bin = 0; bin < binCount; ++bin){
                
                total += histogram[bin];
                if (lower == -1 && total >= lowerThreshold){
                    lower = bin * pixelsPerBin;
                }
                if (upper == -1 && total >= upperThreshold){
                    upper = bin * pixelsPerBin;
                }
            }
            
            if (lower == -1){
                lower = 0;
            }
            if (upper == -1){
                upper = kMaxPixelValue;
            }
                        
//            NSLog(@"CASFITSPreviewer: lower %ld, upper %ld, pixelsPerBin: %ld",(unsigned long)lower,(unsigned long)upper,pixelsPerBin);
            
            const float scaler = kMaxPixelValue/(upper - lower);
            for (int i = 0; i < pixelCount; ++i){
                const float p = pix[i];
                if (p < lower){
                    pix[i] = 0;
                }
                else if (p > upper){
                    pix[i] = kMaxPixelValue;
                }
                else {
                    pix[i] = (p - lower)*scaler;
                }
            }
            
            free(histogram);
        }
    }

    // scale to 0->1
    for (int i = 0; i < pixelCount; ++i){
        pix[i] /= kMaxPixelValue;
    }

//    calcPixelStats();
//    NSLog(@"CASFITSPreviewer (after stretch): average: %f, min: %f, max: %f",average,min,max);
}

@end

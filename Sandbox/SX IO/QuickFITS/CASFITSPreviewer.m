//
//  CASFITSPreviewer.m
//  QuickFITS
//
//  Created by Simon Taylor on 8/24/13.
//  Copyright (c) 2013 Simon Taylor. All rights reserved.
//

#import "CASFITSPreviewer.h"
#import "fitsio.h"

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
                float average = 0, max = 0;
                float* pix = CGBitmapContextGetData(context);
                
                for (fpixel[1] = 1; fpixel[1] <= naxes[1]; fpixel[1]++) {
                    
                    // read a row of pixels into the bitmap
                    if (fits_read_pix(fptr,TFLOAT,fpixel,naxes[0],0,pix,0,&status)){
                        NSLog(@"CASFITSPreviewer: failed to read a row %d: %@",status,path);
                        break;
                    }
                    
                    // get average and max pixel values (use vDSP ?)
                    for (int ii = 0; ii < naxes[0]; ii++) {
                        average += pix[ii];
                        max = MAX(max, pix[ii]);
                    }
                    
                    // advance the pixel pointer a row
                    pix += (CGBitmapContextGetBytesPerRow(context)/sizeof(float));
                }
                
                // log average and max
                average /= naxes[0] * naxes[1];
                NSLog(@"CASFITSPreviewer: average: %f, max: %f",average,max);
                
                // scale the image to 0->1 (use vDSP ?)
                if (average > 1){
                    
                    float* pix = CGBitmapContextGetData(context);
                    for (int i = 0; i < naxes[0] * naxes[1]; ++i){
                        pix[i] /= max;
                    }
                }
                
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

@end

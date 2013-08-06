#import <Foundation/Foundation.h>
#import <QuickLook/QuickLook.h>

#import "fitsio.h"

OSStatus GenerateThumbnailForURL(void *thisInterface, QLThumbnailRequestRef thumbnail, CFURLRef url, CFStringRef contentTypeUTI, CFDictionaryRef options, CGSize maxSize);
void CancelThumbnailGeneration(void *thisInterface, QLThumbnailRequestRef thumbnail);

/* -----------------------------------------------------------------------------
    Generate a thumbnail for file

   This function's job is to create thumbnail for designated file as fast as possible
   ----------------------------------------------------------------------------- */

OSStatus GenerateThumbnailForURL(void *thisInterface, QLThumbnailRequestRef thumbnail, CFURLRef url, CFStringRef contentTypeUTI, CFDictionaryRef options, CGSize maxSize)
{    
    NSLog(@"QLFITS: GenerateThumbnailForURL: %@, size=%@",url,NSStringFromSize(maxSize));
    
    int status = noErr;  /* CFITSIO status value MUST be initialized to zero! */

    @autoreleasepool {
        
        int hdutype;
        fitsfile *fptr;  /* FITS file pointer */
        
        NSString* path = [(__bridge NSURL *)(url) path];

        if (fits_open_image(&fptr, [path UTF8String], READONLY, &status)) {
            return status;
        }
        
        if (fits_get_hdu_type(fptr, &hdutype, &status) || hdutype != IMAGE_HDU) {
            NSLog(@"QLFITS: FITS file isn't an image %@",path);
        }
        else {
            
            int naxis;
            long naxes[2];
            fits_get_img_dim(fptr, &naxis, &status);
            fits_get_img_size(fptr, 2, naxes, &status);
            
            if (status || naxis != 2) {
                NSLog(@"QLFITS: only 2D images supported %@",path);
            }
            else {
                
                float* pix = (float *) malloc(naxes[0] * sizeof(float)); /* memory for 1 row */
                if (!pix){
                    NSLog(@"QLFITS: out of memory %@",path);
                    status = memFullErr;
                }
                else {
                    
                    long fpixel[2];
                    fpixel[0] = 1;  /* read starting with first pixel in each row */
                    
                    // create bitmap memory
                    
                    /* process image one row at a time; increment row # in each loop */
                    for (fpixel[1] = 1; fpixel[1] <= naxes[1]; fpixel[1]++)
                    {
                        /* give starting pixel coordinate and number of pixels to read */
                        if (fits_read_pix(fptr, TDOUBLE, fpixel, naxes[0],0, pix,0, &status))
                            break;   /* jump out of loop on error */
                        
                        for (int ii = 0; ii < naxes[0]; ii++) {
                        }
                    }
                    
                    free(pix);
                    
                    // create image
                }
            }
        }
        
        fits_close_file(fptr, &status);
        

#if 0
        const CGFloat aspectRatio = (CGFloat)CGImageGetWidth(ref)/(CGFloat)CGImageGetHeight(ref);
        const CGSize thumbnailSize = CGSizeMake(maxSize.width, floor(maxSize.width / aspectRatio));
        
        CGContextRef cgContext = QLThumbnailRequestCreateContext(thumbnail, *(CGSize *)&thumbnailSize,true,NULL);
        if (cgContext){
            
            NSLog(@"QLFITS: Created thumbnail context with size %@",NSStringFromSize(thumbnailSize));
            
            CGContextDrawImage(cgContext, CGRectMake(0, 0, thumbnailSize.width, thumbnailSize.height), ref);
            QLThumbnailRequestFlushContext(thumbnail, cgContext);
            CFRelease(cgContext);
        }
#endif
        
    }
    
    return status;
}

void CancelThumbnailGeneration(void *thisInterface, QLThumbnailRequestRef thumbnail)
{
    // Implement only if supported
}

#include <Foundation/Foundation.h>
#include <CoreServices/CoreServices.h>
#include <QuickLook/QuickLook.h>
#include "CASFITSPreviewer.h"

OSStatus GenerateThumbnailForURL(void *thisInterface, QLThumbnailRequestRef thumbnail, CFURLRef url, CFStringRef contentTypeUTI, CFDictionaryRef options, CGSize maxSize);
void CancelThumbnailGeneration(void *thisInterface, QLThumbnailRequestRef thumbnail);

/* -----------------------------------------------------------------------------
    Generate a thumbnail for file

   This function's job is to create thumbnail for designated file as fast as possible
   ----------------------------------------------------------------------------- */

OSStatus GenerateThumbnailForURL(void *thisInterface, QLThumbnailRequestRef thumbnail, CFURLRef url, CFStringRef contentTypeUTI, CFDictionaryRef options, CGSize maxSize)
{
    NSLog(@"QuickFITS: GenerateThumbnailForURL: %@, size=%@",url,NSStringFromSize(maxSize));
    
    int status = noErr; // todo; get from error object
    
    CASFITSPreviewer* previewer = [[CASFITSPreviewer alloc] init];
    CGImageRef image = [previewer imageFromURL:(__bridge NSURL *)(url) error:nil];
    if (!image){
        NSLog(@"QuickFITS: GenerateThumbnailForURL: failed to load image from url %@",url);
    }
    else{
    
        const CGFloat aspectRatio = (CGFloat)CGImageGetWidth(image)/(CGFloat)CGImageGetHeight(image);
        const CGSize thumbnailSize = CGSizeMake(maxSize.width, floor(maxSize.width / aspectRatio));
        
        CGContextRef cgContext = QLThumbnailRequestCreateContext(thumbnail, *(CGSize *)&thumbnailSize,true,NULL);
        if (!cgContext){
            NSLog(@"QuickFITS: GenerateThumbnailForURL: QLThumbnailRequestCreateContext returned nil");
        }
        else{
        
            CGContextDrawImage(cgContext, CGRectMake(0, 0, thumbnailSize.width, thumbnailSize.height), image);
            QLThumbnailRequestFlushContext(thumbnail, cgContext);
            CFRelease(cgContext);
        }
        
        CGImageRelease(image);
    }
    
    return status;
}

void CancelThumbnailGeneration(void *thisInterface, QLThumbnailRequestRef thumbnail)
{
    // Implement only if supported
}

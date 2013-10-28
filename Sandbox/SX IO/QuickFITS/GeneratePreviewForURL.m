#include <Foundation/Foundation.h>
#include <CoreServices/CoreServices.h>
#include <QuickLook/QuickLook.h>
#include "CASFITSPreviewer.h"

OSStatus GeneratePreviewForURL(void *thisInterface, QLPreviewRequestRef preview, CFURLRef url, CFStringRef contentTypeUTI, CFDictionaryRef options);
void CancelPreviewGeneration(void *thisInterface, QLPreviewRequestRef preview);

/* -----------------------------------------------------------------------------
   Generate a preview for file

   This function's job is to create preview for designated file
   ----------------------------------------------------------------------------- */

OSStatus GeneratePreviewForURL(void *thisInterface, QLPreviewRequestRef preview, CFURLRef url, CFStringRef contentTypeUTI, CFDictionaryRef options)
{
    NSLog(@"QuickFITS: GeneratePreviewForURL: %@",url);
    
    int status = noErr; // todo; get from error object
    
    CASFITSPreviewer* previewer = [[CASFITSPreviewer alloc] init];
    CGImageRef image = [previewer imageFromURL:(__bridge NSURL *)(url) error:nil];
    if (!image){
        NSLog(@"QuickFITS: GeneratePreviewForURL: failed to load image from url %@",url);
    }
    else{
        
        const CGSize previewSize = CGSizeMake(CGImageGetWidth(image), CGImageGetHeight(image));
        
        CGContextRef cgContext = QLPreviewRequestCreateContext(preview, *(CGSize *)&previewSize,true,NULL);
        if (!cgContext){
            NSLog(@"QuickFITS: GeneratePreviewForURL: QLPreviewRequestCreateContext returned nil");
        }
        else{
            
            CGContextDrawImage(cgContext, CGRectMake(0, 0, previewSize.width, previewSize.height), image);
            QLPreviewRequestFlushContext(preview, cgContext);
            CFRelease(cgContext);
        }
        
        CGImageRelease(image);
    }
    
    return status;
}

void CancelPreviewGeneration(void *thisInterface, QLPreviewRequestRef preview)
{
    // Implement only if supported
}

#import <Foundation/Foundation.h>
#import <QuickLook/QuickLook.h>
#import <CoreAstro/CoreAstro.h>

OSStatus GenerateThumbnailForURL(void *thisInterface, QLThumbnailRequestRef thumbnail, CFURLRef url, CFStringRef contentTypeUTI, CFDictionaryRef options, CGSize maxSize);
void CancelThumbnailGeneration(void *thisInterface, QLThumbnailRequestRef thumbnail);

/* -----------------------------------------------------------------------------
    Generate a thumbnail for file

   This function's job is to create thumbnail for designated file as fast as possible
   ----------------------------------------------------------------------------- */

OSStatus GenerateThumbnailForURL(void *thisInterface, QLThumbnailRequestRef thumbnail, CFURLRef url, CFStringRef contentTypeUTI, CFDictionaryRef options, CGSize maxSize)
{
    // To complete your generator please implement the function GenerateThumbnailForURL in GenerateThumbnailForURL.c
    
    NSLog(@"CoreAstro: GenerateThumbnailForURL: %@, size=%@",url,NSStringFromSize(maxSize));
    
    @autoreleasepool {
        
        NSString* path = [(__bridge NSURL *)(url) path];
        CASCCDExposureIO* io = [CASCCDExposureIO exposureIOWithPath:path];
        if (!io){
            NSLog(@"CoreAstro: Failed to create IO object for exposure");
        }
        else{
        
            NSString* thumbPath = [path stringByAppendingPathComponent:@"thumbnail.png"];
            NSData* thumbData = [NSData dataWithContentsOfFile:thumbPath];
            if (thumbData && maxSize.width <= 256){
                
                NSLog(@"CoreAstro: Using packaged thumbnail");

                QLThumbnailRequestSetImageWithData(thumbnail, (__bridge CFDataRef)(thumbData), (__bridge CFDictionaryRef)([NSDictionary dictionaryWithObjectsAndKeys:@"public.png",kCGImageSourceTypeIdentifierHint,nil]));
            }
            else {
                
                NSLog(@"CoreAstro: No suitable packaged thumbnail, will have to generate one");
                
                CASCCDExposure* exp = [[CASCCDExposure alloc] init];
                if ([io readExposure:exp readPixels:YES error:nil]){
                    
                    CASCCDImage* image = [exp newImage];
                    if (image){
                        
                        CGImageRef ref = image.CGImage;
                        if (ref){
                            
                            const CGFloat aspectRatio = (CGFloat)CGImageGetWidth(ref)/(CGFloat)CGImageGetHeight(ref);
                            const CGSize thumbnailSize = CGSizeMake(maxSize.width, floor(maxSize.width / aspectRatio));
                            
                            CGContextRef cgContext = QLThumbnailRequestCreateContext(thumbnail, *(CGSize *)&thumbnailSize,true,NULL);
                            if (cgContext){

                                NSLog(@"CoreAstro: Created thumbnail context with size %@",NSStringFromSize(thumbnailSize));

                                CGContextDrawImage(cgContext, CGRectMake(0, 0, thumbnailSize.width, thumbnailSize.height), ref);
                                QLThumbnailRequestFlushContext(thumbnail, cgContext);
                                CFRelease(cgContext);
                            }
                        }
                    }
                }
            }
        }
    }
    
    return noErr;
}

void CancelThumbnailGeneration(void *thisInterface, QLThumbnailRequestRef thumbnail)
{
    // Implement only if supported
}

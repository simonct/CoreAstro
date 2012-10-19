//
//  CASCCDImage.m
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

#import "CASCCDImage.h"
#import <Accelerate/Accelerate.h>

@interface CASCCDImage ()
@property (nonatomic,strong) NSData* pixels;
@end

@implementation CASCCDImage {
    CGImageRef _CGImage;
}

@synthesize size, bitsPerPixel, pixels;

- (void)dealloc
{
    if (_CGImage){
        CGImageRelease(_CGImage);
    }
}

- (CGContextRef)_copyContext
{
    if (self.bitsPerPixel != 16){
        NSLog(@"Unsupported bitsPerPixel of %ld",self.bitsPerPixel);
        return nil;
    }
    
    CGContextRef context = [[self class] createBitmapContextWithSize:CASSizeMake(self.size.width, self.size.height) bitsPerPixel:self.bitsPerPixel];
    if (context){
        
        uint16_t* pixelData = (uint16_t*)[pixels bytes];
        uint16_t* contextData = CGBitmapContextGetData(context);
        if (contextData){
            
            const NSUInteger count = CGBitmapContextGetWidth(context) * CGBitmapContextGetHeight(context);
            for (NSUInteger i = 0; i < count; ++i){
                
                *contextData++ = CFSwapInt16BigToHost(pixelData[i]);
            }
        }
    }
    
    return context;
}

- (CGImageRef)CGImage
{
    if (!_CGImage){
        CGContextRef context = [self _copyContext];
        if (context){
            _CGImage = CGBitmapContextCreateImage(context);
            CGContextRelease(context);
        }
    }
    return _CGImage;
}

- (void)clearImage
{
    if (_CGImage){
        CGImageRelease(_CGImage);
    }
    _CGImage = NULL;
}

- (void)reset
{
    [self clearImage];
    
    // need a reference to the underlying exposure to get the pixels from again ?
}

- (CGImageRef)createImageWithSize:(CASSize)imageSize
{
    CGImageRef result = nil;
    CGImageRef image = self.CGImage;
    if (image){
        if (imageSize.width == CGImageGetWidth(image) && imageSize.height == CGImageGetHeight(image)){
            result = image;
        }
        else {
            CGContextRef thumbContext = ([[self class] createBitmapContextWithSize:imageSize bitsPerPixel:self.bitsPerPixel]);
            if (thumbContext){
                CGContextDrawImage(thumbContext, CGRectMake(0, 0, imageSize.width, imageSize.height), image);
                result = CGBitmapContextCreateImage(thumbContext);
            }
        }
    }
    return result;
}

+ (CGContextRef)createBitmapContextWithSize:(CASSize)size bitsPerPixel:(NSInteger)bitsPerPixel
{
    if (bitsPerPixel != 16){
        NSLog(@"Unsupported bitsPerPixel of %ld",bitsPerPixel);
        return nil;
    }
    
    CGColorSpaceRef space = CGColorSpaceCreateWithName(kCGColorSpaceGenericGray);
    CGContextRef context = CGBitmapContextCreate(nil, size.width, size.height, 16, (size.width) * 2, space, kCGImageAlphaNone);
    CFRelease(space);
    
    return context;
}

+ (CASCCDImage*)createImageWithPixels:(NSData*)pixels size:(CASSize)size bitsPerPixel:(NSInteger)bitsPerPixel;
{
    CASCCDImage* image = [[CASCCDImage alloc] init];
    image.pixels = pixels ? pixels : [NSMutableData dataWithLength:size.width*size.height*bitsPerPixel/8];
    image.size = size;
    image.bitsPerPixel = bitsPerPixel;
    return image;
}

@end

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
@property (nonatomic) BOOL rgba;
@property (nonatomic) CASSize size;
@property (nonatomic,strong) NSData* floatPixels;
@end

@implementation CASCCDImage {
    CGImageRef _CGImage;
}

- (void)dealloc
{
    if (_CGImage){
        CGImageRelease(_CGImage);
    }
}

- (CGContextRef)_copyContext
{
    CGContextRef context = [self newContext];
    if (context){
        
        float* pixelData = (float*)[_floatPixels bytes];
        float* contextData = CGBitmapContextGetData(context);
        if (pixelData && contextData){
            memcpy(contextData, pixelData, [_floatPixels length]);
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

- (CGContextRef)newContext
{
    CGContextRef context = nil;
    if (self.rgba){
        context = [[self class] newRGBAFloatBitmapContextWithSize:CASSizeMake(self.size.width, self.size.height)];
    }
    else {
        context = [[self class] newFloatBitmapContextWithSize:CASSizeMake(self.size.width, self.size.height)];
    }
    return context;
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

- (CGImageRef)newImageWithSize:(CASSize)imageSize
{
    CGImageRef result = nil;
    CGImageRef image = self.CGImage;
    if (image){
        if (imageSize.width == CGImageGetWidth(image) && imageSize.height == CGImageGetHeight(image)){
            result = image;
        }
        else {
            CGContextRef thumbContext = ([[self class] newFloatBitmapContextWithSize:imageSize]);
            if (thumbContext){
                CGContextDrawImage(thumbContext, CGRectMake(0, 0, imageSize.width, imageSize.height), image);
                result = CGBitmapContextCreateImage(thumbContext);
                CGContextRelease(thumbContext);
            }
        }
    }
    return result;
}

+ (CGContextRef)newRGBBitmapContextWithSize:(CASSize)size
{
    CGColorSpaceRef space = CGColorSpaceCreateWithName(kCGColorSpaceGenericRGB);
    CGContextRef context = CGBitmapContextCreate(nil, size.width, size.height, 8, (size.width) * 4, space, kCGImageAlphaPremultipliedLast);
    CFRelease(space);
    
    return context;
}

+ (CGContextRef)newFloatBitmapContextWithSize:(CASSize)size
{
    CGColorSpaceRef space = CGColorSpaceCreateWithName(kCGColorSpaceGenericGray);
    CGContextRef context = CGBitmapContextCreate(nil, size.width, size.height, 32, size.width * sizeof(float), space, kCGImageAlphaNone|kCGBitmapFloatComponents|kCGBitmapByteOrder32Little);
    CFRelease(space);
    
    return context;
}

+ (CGContextRef)newRGBAFloatBitmapContextWithSize:(CASSize)size
{
    CGColorSpaceRef space = CGColorSpaceCreateWithName(kCGColorSpaceGenericRGB);
    CGContextRef context = CGBitmapContextCreate(nil, size.width, size.height, 32, (size.width) * 4 * 4, space, kCGImageAlphaNoneSkipLast|kCGBitmapFloatComponents|kCGBitmapByteOrder32Little);
    CFRelease(space);
    
    return context;
}

+ (CGContextRef)newBitmapContextWithSize:(CASSize)size bitsPerPixel:(NSInteger)bitsPerPixel
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

+ (CASCCDImage*)newImageWithPixels:(NSData*)pixels size:(CASSize)size rgba:(BOOL)rgba
{
    CASCCDImage* image = [[CASCCDImage alloc] init];
    image.floatPixels = pixels ? pixels : [NSMutableData dataWithLength:size.width*size.height*sizeof(float)];
    image.size = size;
    image.rgba = rgba;
    return image;
}

@end

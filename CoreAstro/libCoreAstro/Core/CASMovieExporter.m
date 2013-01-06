//
//  CASCCDExposureIO.m
//  CoreAstro
//
//  Copyright (c) 2013, Simon Taylor
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

#import "CASMovieExporter.h"
#import <AVFoundation/AVFoundation.h>

@implementation CASMovieExporter {
    NSURL* _url;
    AVAssetWriter* _writer;
    AVAssetWriterInput* _writerInput;
    AVAssetWriterInputPixelBufferAdaptor* _writerInputAdaptor;
    NSInteger _frame;
}

- (id)initWithURL:(NSURL*)url
{
    self = [super init];
    if (self) {
        _url = url;
    }
    return self;
}

- (CVPixelBufferRef)pixelBufferFromExposure:(CASCCDExposure*)exposure
{
    CVPixelBufferRef pixelBuffer = NULL;
    CGImageRef image = [exposure newImage].CGImage;
    if (image){
        
        // todo; kCVPixelFormatType_16Gray and CVPixelBufferCreateWithBytes for non-rgba images ?
        
        const CASSize size = exposure.actualSize;
        
        NSDictionary *options = @{(id)kCVPixelBufferCGImageCompatibilityKey:[NSNumber numberWithBool:YES],
                                  (id)kCVPixelBufferCGBitmapContextCompatibilityKey:[NSNumber numberWithBool:YES]};
        CVReturn status = CVPixelBufferCreate(kCFAllocatorDefault,size.width,size.height,kCVPixelFormatType_32ARGB,(__bridge CFDictionaryRef)(options),&pixelBuffer);
        if (status == kCVReturnSuccess){
            
            status = CVPixelBufferLockBaseAddress(pixelBuffer,0);
            if (status == kCVReturnSuccess){
                
                void *pixelData = CVPixelBufferGetBaseAddress(pixelBuffer);
                if (pixelData){
                    
                    CGColorSpaceRef rgb = CGColorSpaceCreateDeviceRGB();
                    if (rgb){
                        
                        CGContextRef context = CGBitmapContextCreate(pixelData,size.width,size.height,8,4*size.width,rgb,kCGImageAlphaPremultipliedFirst);
                        if (context){
                            
                            CGContextDrawImage(context,CGRectMake(0,0,size.width,size.height),image);
                            CGContextRelease(context);
                        }
                        CGColorSpaceRelease(rgb);
                    }
                }
                CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
            }
        }
    }
    
    return pixelBuffer;
}

- (BOOL)addExposure:(CASCCDExposure*)exposure error:(NSError**)errorPtr
{
    NSError* error = nil;
    
    if (!_writer){
        _writer = [AVAssetWriter assetWriterWithURL:_url fileType:AVFileTypeQuickTimeMovie error:&error];
    }
    
    if (!error){
        
        if (!_writerInput){
            
            _writerInput = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeVideo
                                                              outputSettings:@{AVVideoCodecKey:AVVideoCodecH264,
                                                             AVVideoWidthKey:[NSNumber numberWithInteger:exposure.actualSize.width],
                                                            AVVideoHeightKey:[NSNumber numberWithInteger:exposure.actualSize.height]}];
            [_writer addInput:_writerInput];
        }
        
        if (!_writerInputAdaptor){
            
            // todo; use kCVPixelFormatType_64ARGB ?
            
            _writerInputAdaptor = [AVAssetWriterInputPixelBufferAdaptor assetWriterInputPixelBufferAdaptorWithAssetWriterInput:_writerInput
                                                                                                   sourcePixelBufferAttributes:@{(id)kCVPixelBufferPixelFormatTypeKey:[NSNumber numberWithInt:kCVPixelFormatType_32ARGB]}];
            [_writer startWriting];
            [_writer startSessionAtSourceTime:kCMTimeZero];
        }
    }

    if (!error){
        
        CVPixelBufferRef buffer = (CVPixelBufferRef)[self pixelBufferFromExposure:exposure];
        if(![_writerInputAdaptor appendPixelBuffer:buffer withPresentationTime:CMTimeMake(++_frame,20)]){
            error = [_writer error];
        }
    }

    if (errorPtr){
        *errorPtr = error;
    }
    
    return (error == nil);
}

- (void)complete
{
    [_writerInput markAsFinished];
    [_writer finishWriting];
    _writerInput = nil;
    _writer = nil;
}

+ (CASMovieExporter*)exporterWithURL:(NSURL*)url
{
    return [[CASMovieExporter alloc] initWithURL:url];
}

@end

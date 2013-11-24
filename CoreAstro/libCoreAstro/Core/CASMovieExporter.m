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
#import "CASUtilities.h"
#import "CASCCDExposureIO.h"
#import <CoreVideo/CVPixelBuffer.h>

@interface CASMovieExporter ()
@property (nonatomic,strong) NSURL* url;
@property (nonatomic,strong) NSError* error;
@property (nonatomic,strong) AVAssetWriter* writer;
@property (nonatomic,strong) AVAssetWriterInput* writerInput;
@property (nonatomic,strong) AVAssetWriterInputPixelBufferAdaptor* writerInputAdaptor;
@property (nonatomic,strong) NSMutableArray* exposures;
@end

@interface CASMovieExporterQueueEntry : NSObject
@property (nonatomic,strong) CASCCDExposure* exposure;
@property (nonatomic,assign) CMTime time;
@end

@implementation CASMovieExporterQueueEntry
@end

static NSInteger count;

@implementation CASMovieExporter {
    NSInteger _frame;
    NSTimeInterval _startTime;
    dispatch_queue_t _queue;
    BOOL _complete;
}

- (id)initWithURL:(NSURL*)url
{
    self = [super init];
    if (self) {
        _url = url;
        count = 0;
    }
    return self;
}

- (void)dealloc
{
    if (_queue){
        dispatch_release(_queue);
    }
}

- (CVPixelBufferRef)pixelBufferFromExposure:(CASCCDExposure*)exposure
{
    CVPixelBufferRef pixelBuffer = NULL;
    CGImageRef image = [exposure newImage].CGImage;
    if (image){
        
        // todo; kCVPixelFormatType_16Gray and CVPixelBufferCreateWithBytes for non-rgba images ?
        
        const CASSize size = exposure.actualSize;
        
        NSDictionary *options = @{(id)kCVPixelBufferCGImageCompatibilityKey:@YES,
                                  (id)kCVPixelBufferCGBitmapContextCompatibilityKey:@YES};
        CVReturn status = CVPixelBufferCreate(kCFAllocatorDefault,size.width,size.height,kCVPixelFormatType_32ARGB,(__bridge CFDictionaryRef)(options),&pixelBuffer);
        if (status == kCVReturnSuccess){
            
            status = CVPixelBufferLockBaseAddress(pixelBuffer,0);
            if (status == kCVReturnSuccess){
                
                void *pixelData = CVPixelBufferGetBaseAddress(pixelBuffer);
                if (pixelData){
                    
                    CGColorSpaceRef rgb = CGColorSpaceCreateDeviceRGB();
                    if (rgb){
                        
                        CGContextRef context = CGBitmapContextCreate(pixelData,CVPixelBufferGetWidth(pixelBuffer),CVPixelBufferGetHeight(pixelBuffer),8,CVPixelBufferGetBytesPerRow(pixelBuffer),rgb,kCGImageAlphaPremultipliedFirst);
                        if (context){
                            
                            CGContextDrawImage(context,CGRectMake(0,0,size.width,size.height),image);
                            
                            NSMutableString* label = [NSMutableString stringWithCapacity:256];
                            
                            // draw timecode
                            if (self.showDateTime){
                                NSString* displayDate = exposure.displayDate;
                                if (displayDate) {
                                    [label appendString:displayDate];
                                }
                            }
                            
                            // draw filename
                            if (self.showFilename){
                                NSString* name = [exposure.io.url resourceValuesForKeys:@[NSURLNameKey] error:nil][NSURLNameKey];
                                if ([name length]){
                                    if ([label length]){
                                        [label appendString:@", "];
                                    }
                                    [label appendString:name];
                                }
                            }
                            
                            // draw custom
                            if (self.showCustom && [self.customAnnotation length]){
                                if ([label length]){
                                    [label appendString:@", "];
                                }
                                [label appendString:self.customAnnotation];
                            }
                            
                            if ([label length]){
                                const CGFloat fontSize = self.fontSize ? self.fontSize : (size.width < 1000 ? 24 : 36);
                                CGContextSelectFont(context, "Helvetica", fontSize, kCGEncodingMacRoman);
                                CGContextSetRGBFillColor(context, 1.0, 1.0, 1.0, 0.75);
                                CGContextSetTextDrawingMode(context, kCGTextFill);
                                CGContextShowTextAtPoint(context, 20, 20, [label UTF8String], [label length]);
                            }
                            
                            CGContextRelease(context);
                        }
                        CGColorSpaceRelease(rgb);
                    }
                }
                CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
            }
        }
    }
    
    [exposure reset];

    return pixelBuffer;
}

- (BOOL)_prepareWithExposure:(CASCCDExposure*)exposure error:(NSError**)errorPtr
{
    NSError* error = nil;
    
    if (!_writer){
        _writer = [AVAssetWriter assetWriterWithURL:_url fileType:AVFileTypeQuickTimeMovie error:&error];
        _writer.shouldOptimizeForNetworkUse = YES;
    }
    
    if (!error){
        
        if (!_writerInput){
            
            NSDictionary* settings;
            switch (self.compressionLevel) {
                case 0:
                    settings = @{AVVideoCodecKey:AVVideoCodecH264,
                                 // AVVideoAverageBitRateKey, AVVideoProfileLevelKey ?
                                 AVVideoWidthKey:@(exposure.actualSize.width),
                                 AVVideoHeightKey:@(exposure.actualSize.height)};
                    break;
                case 1:
                    settings = @{AVVideoCodecKey:AVVideoCodecAppleProRes422,
                                 // AVVideoAverageBitRateKey, AVVideoProfileLevelKey ?
                                 AVVideoWidthKey:@(exposure.actualSize.width),
                                 AVVideoHeightKey:@(exposure.actualSize.height)};
                    break;
                case 2:
                    settings = @{AVVideoCodecKey:AVVideoCodecAppleProRes4444,
                                 // AVVideoAverageBitRateKey, AVVideoProfileLevelKey ?
                                 AVVideoWidthKey:@(exposure.actualSize.width),
                                 AVVideoHeightKey:@(exposure.actualSize.height)};
                    break;
            }
            
            _writerInput = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeVideo
                                                              outputSettings:settings];
            [_writer addInput:_writerInput];
        }
        
        if (!_writerInputAdaptor){
            
            _writerInputAdaptor = [AVAssetWriterInputPixelBufferAdaptor assetWriterInputPixelBufferAdaptorWithAssetWriterInput:_writerInput
                                                                                                   sourcePixelBufferAttributes:@{(id)kCVPixelBufferPixelFormatTypeKey:@(kCVPixelFormatType_32ARGB)}];
            [_writer startWriting];
            [_writer startSessionAtSourceTime:kCMTimeZero];
            
            _startTime = [NSDate timeIntervalSinceReferenceDate];
            
            if (!_queue){
                _queue = dispatch_queue_create("org.coreastro.movie-export", DISPATCH_QUEUE_SERIAL);
            }
            
            if (!_exposures){
                _exposures = [NSMutableArray arrayWithCapacity:5];
            }
            
            [_writerInput requestMediaDataWhenReadyOnQueue:_queue usingBlock:^{
                
                @synchronized(self){
                    
                    while (!_complete && [_writerInput isReadyForMoreMediaData]) {
                        
                        @autoreleasepool {
                            
                            CMTime time;
                            CASCCDExposure* exposure = nil;
                            if (self.input){
                                self.input(&exposure,&time);
                            }
                            else {
                                [self _getLastExposure:&exposure time:&time];
                            }
                            if (!exposure){
                                break;
                            }
                            else{
                                
                                CVPixelBufferRef buffer = (CVPixelBufferRef)[self pixelBufferFromExposure:exposure];
                                if (!buffer){
                                    NSLog(@"%@: no pixel buffer",NSStringFromSelector(_cmd));
                                    break;
                                }
                                else{
                                    
                                    if(![_writerInputAdaptor appendPixelBuffer:buffer withPresentationTime:time]){
                                        self.error = [_writer error];
                                        NSLog(@"%@: -appendPixelBuffer:withPresentationTime: %@",NSStringFromSelector(_cmd),self.error);
                                        [self complete];
                                    }
                                    CVPixelBufferRelease(buffer);
                                }
                            }
                        }
                    }
                }
            }];
        }
    }
    
    if (errorPtr){
        *errorPtr = error;
    }
    
    return (error == nil);
}

- (void)_prependExposure:(CASCCDExposure*)exposure time:(CMTime)time
{
    NSParameterAssert(CMTIME_IS_VALID(time));
    @synchronized(self){
        CASMovieExporterQueueEntry* entry = [CASMovieExporterQueueEntry new];
        entry.exposure = exposure;
        entry.time = time;
        [_exposures insertObject:entry atIndex:0];
    }
}

- (void)_getLastExposure:(CASCCDExposure**)exposure time:(CMTime*)time
{
    @synchronized(self){
        if ([_exposures count]){
            CASMovieExporterQueueEntry* entry = [_exposures lastObject];
            if (exposure) *exposure = entry.exposure;
            if (time) *time = entry.time;
            [_exposures removeLastObject];
        }
    }
}

- (BOOL)addExposure:(CASCCDExposure*)exposure error:(NSError**)errorPtr
{
    NSError* error = nil;
    
    // enqueue the frame to the start of the write queue
    if ([self _prepareWithExposure:exposure error:&error]){
        [self _prependExposure:exposure time:CMTimeMake(++_frame,20)];
    }

    if (error){
        [self complete];
    }
    
    if (errorPtr){
        *errorPtr = error;
    }
    
    return (error == nil);
}

- (void)complete
{
    @synchronized(self){
        
        _complete = YES;
        
        // this will probably result in enqueued exposures being discarded...
        [_writerInput markAsFinished];
        [_writer finishWriting];
        _writerInputAdaptor = nil;
        _writerInput = nil;
        _writer = nil;
    }
}

- (BOOL)startWithExposure:(CASCCDExposure*)exposure  error:(NSError**)errorPtr
{
    NSParameterAssert(exposure);
    
    NSError* error = nil;

    [self _prepareWithExposure:exposure error:&error];

    if (errorPtr){
        *errorPtr = error;
    }
    
    return (error == nil);
}

+ (CASMovieExporter*)exporterWithURL:(NSURL*)url
{
    return [[CASMovieExporter alloc] initWithURL:url];
}

@end

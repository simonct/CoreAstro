//
//  CASImageProcessor.m
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
//  Very basic liner interpolation debayering.

#import "CASImageDebayer.h"
#import "CASUtilities.h"
#import <Accelerate/Accelerate.h>

typedef struct { float r,g,b,a; } fpixel_t;

@interface CASImageDebayer ()
- (CASCCDExposure*)debayer:(CASCCDExposure*)image;
@end

@implementation CASImageDebayer 

@synthesize mode = _mode;

+ (id<CASImageDebayer>)imageDebayerWithIdentifier:(NSString*)ident;
{
    return [[[self class] alloc] init];
}

- (CASCCDExposure*)debayer:(CASCCDExposure*)exposure adjustRed:(float)red green:(float)green blue:(float)blue all:(float)all
{
    if (exposure.rgba){
        NSLog(@"%@: passed an rgba image",NSStringFromSelector(_cmd));
        return exposure;
    }
    
    const CASSize size = exposure.actualSize;
    if (size.width < 4 || size.height < 4){
        NSLog(@"Debayer asked to process an exposure of %ldx%ld",size.width,size.height);
        return nil;
    }
    
    const NSInteger finalPixelsLength = (size.width * size.height * sizeof(fpixel_t));
    NSMutableData* finalPixels = [NSMutableData dataWithLength:finalPixelsLength];
    if (!finalPixels){
        NSLog(@"*** Out of memory");
        return nil;
    }
    
    float *gp = (float*)[exposure.floatPixels bytes];
    fpixel_t *cp = (fpixel_t*)[finalPixels mutableBytes];
        
    #define clip(x,lim) ((x) < 0 ? 0 : (x) >= (lim) ? (lim-1) : (x))
    #define clipx(x) clip(x,size.width)
    #define clipy(y) clip(y,size.height)
    #define source_pixel(x,y) (*(gp + clipx(x) + clipy(y) * size.width))
    #define destination_pixel(x,y) *(cp + clipx(x) + clipy(y) * size.width)
    #define make_rgba(rx,gx,bx,ax) { .r = rx, .g = gx, .b = bx, .a = ax };

    const NSTimeInterval time = CASTimeBlock(^{

        dispatch_apply(size.height/2, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH,0), ^(size_t row){
            
            const size_t y = 2*row;
            
            for (size_t x = 0; x < size.width; x += 2){
                
                const float a = 1.0;
                
                // RG|RG|RG|RG
                // GB|GB|GB|GB
                // RG|RG|RG|RG
                // GB|GB|GB|GB
                
                if (self.mode == kCASImageDebayerRGGB){
                    
                    size_t i = x, j = y;
                    
                    float r1 = source_pixel(i,j);
                    float g1 = (source_pixel(i-1,j) + source_pixel(i,j-1) + source_pixel(i,j+1) + source_pixel(i+1,j))/4;
                    float b1 = (source_pixel(i-1,j-1) + source_pixel(i+1,j-1) + source_pixel(i+1,j+1) + source_pixel(i-1,j+1))/4;
                    
                    r1 = all * red * r1;
                    g1 = all * green * g1;
                    b1 = all * blue * b1;
                    
                    destination_pixel(i,j) = make_rgba(r1,g1,b1,a);
                    
                    i = x + 1, j = y + 1;
                    
                    float r2 = (source_pixel(i-1,j-1) + source_pixel(i+1,j-1) + source_pixel(i+1,j+1) + source_pixel(i-1,j+1))/4;
                    float g2 = (source_pixel(i-1,j) + source_pixel(i,j-1) + source_pixel(i,j+1) + source_pixel(i+1,j))/4;
                    float b2 = source_pixel(i,j);
                    
                    r2 = all * red * r2;
                    g2 = all * green * g2;
                    b2 = all * blue * b2;
                    
                    destination_pixel(i,j) = make_rgba(r2,g2,b2,a);
                    
                    i = x + 1, j = y;
                    
                    float r3 = (source_pixel(i,j - 1) + source_pixel(i,j + 1))/2;
                    float g3 = source_pixel(i,j);
                    float b3 = (source_pixel(i - 1,j) + source_pixel(i + 1,j))/2;
                    
                    r3 = all * red * r3;
                    g3 = all * green * g3;
                    b3 = all * blue * b3;
                    
                    destination_pixel(i,j) = make_rgba(r3,g3,b3,a);
                    
                    i = x, j = y + 1;
                    
                    float r4 = (source_pixel(i - 1,j) + source_pixel(i + 1,j))/2;
                    float g4 = source_pixel(i,j);
                    float b4 = (source_pixel(i,j - 1) + source_pixel(i,j + 1))/2;
                    
                    r4 = all * red * r4;
                    g4 = all * green * g4;
                    b4 = all * blue * b4;
                    
                    destination_pixel(i,j) = make_rgba(r4,g4,b4,a);
                }
                
                // GR|GR|GR|GR
                // BG|BG|BG|BG
                // GR|GR|GR|GR
                // BG|BG|BG|BG
                
                if (self.mode == kCASImageDebayerGRBG){
                    
                    size_t i = x + 1, j = y;
                    
                    float r1 = source_pixel(i,j);
                    float g1 = (source_pixel(i-1,j) + source_pixel(i,j-1) + source_pixel(i,j+1) + source_pixel(i+1,j))/4;
                    float b1 = (source_pixel(i-1,j-1) + source_pixel(i+1,j-1) + source_pixel(i+1,j+1) + source_pixel(i-1,j+1))/4;
                    
                    r1 = all * red * r1;
                    g1 = all * green * g1;
                    b1 = all * blue * b1;
                    
                    destination_pixel(i,j) = make_rgba(r1,g1,b1,a);
                    
                    i = x, j = y + 1;
                    
                    float r2 = (source_pixel(i-1,j-1) + source_pixel(i+1,j-1) + source_pixel(i+1,j+1) + source_pixel(i-1,j+1))/4;
                    float g2 = (source_pixel(i-1,j) + source_pixel(i,j-1) + source_pixel(i,j+1) + source_pixel(i+1,j))/4;
                    float b2 = source_pixel(i,j);
                    
                    r2 = all * red * r2;
                    g2 = all * green * g2;
                    b2 = all * blue * b2;
                    
                    destination_pixel(i,j) = make_rgba(r2,g2,b2,a);
                    
                    i = x, j = y;
                    
                    float r3 = (source_pixel(i-1,j) + source_pixel(i+1,j))/2;
                    float g3 = source_pixel(i,j);
                    float b3 = (source_pixel(i,j-1) + source_pixel(i,j+1))/2;
                    
                    r3 = all * red * r3;
                    g3 = all * green * g3;
                    b3 = all * blue * b3;
                    
                    destination_pixel(i,j) = make_rgba(r3,g3,b3,a);
                    
                    i = x + 1, j = y + 1;
                    
                    float r4 = (source_pixel(i,j-1) + source_pixel(i,j+1))/2;
                    float g4 = source_pixel(i,j);
                    float b4 = (source_pixel(i-1,j) + source_pixel(i+1,j))/2;
                    
                    r4 = all * red * r4;
                    g4 = all * green * g4;
                    b4 = all * blue * b4;
                    
                    destination_pixel(i,j) = make_rgba(r4,g4,b4,a);
                }
                
                // BG|BG|BG|BG
                // GR|GR|GR|GR
                // BG|BG|BG|BG
                // GR|GR|GR|GR
                
                if (self.mode == kCASImageDebayerBGGR){
                    
                    size_t i = x + 1, j = y + 1;
                    
                    float r1 = source_pixel(i,j);
                    float g1 = (source_pixel(i-1,j) + source_pixel(i,j-1) + source_pixel(i,j+1) + source_pixel(i+1,j))/4;
                    float b1 = (source_pixel(i-1,j-1) + source_pixel(i+1,j-1) + source_pixel(i+1,j+1) + source_pixel(i-1,j+1))/4;
                    
                    r1 = all * red * r1;
                    g1 = all * green * g1;
                    b1 = all * blue * b1;
                    
                    destination_pixel(i,j) = make_rgba(r1,g1,b1,a);
                    
                    i = x, j = y;
                    
                    float r2 = (source_pixel(i-1,j-1) + source_pixel(i+1,j-1) + source_pixel(i+1,j+1) + source_pixel(i-1,j+1))/4;
                    float g2 = (source_pixel(i-1,j) + source_pixel(i,j-1) + source_pixel(i,j+1) + source_pixel(i+1,j))/4;
                    float b2 = source_pixel(i,j);
                    
                    r2 = all * red * r2;
                    g2 = all * green * g2;
                    b2 = all * blue * b2;
                    
                    destination_pixel(i,j) = make_rgba(r2,g2,b2,a);
                    
                    i = x + 1, j = y;
                    
                    float r3 = (source_pixel(i,j - 1) + source_pixel(i,j + 1))/2;
                    float g3 = source_pixel(i,j);
                    float b3 = (source_pixel(i - 1,j) + source_pixel(i + 1,j))/2;
                    
                    r3 = all * red * r3;
                    g3 = all * green * g3;
                    b3 = all * blue * b3;
                    
                    destination_pixel(i,j) = make_rgba(r3,g3,b3,a);
                    
                    i = x, j = y + 1;
                    
                    float r4 = (source_pixel(i - 1,j) + source_pixel(i + 1,j))/2;
                    float g4 = source_pixel(i,j);
                    float b4 = (source_pixel(i,j - 1) + source_pixel(i,j + 1))/2;
                    
                    r4 = all * red * r4;
                    g4 = all * green * g4;
                    b4 = all * blue * b4;
                    
                    destination_pixel(i,j) = make_rgba(r4,g4,b4,a);
                }
                
                // GB|GB|GB|GB
                // RG|RG|RG|RG
                // GB|GB|GB|GB
                // RG|RG|RG|RG
                
                if (self.mode == kCASImageDebayerGBRG){
                    
                    size_t i = x, j = y + 1;
                    
                    float r1 = source_pixel(i,j);
                    float g1 = (source_pixel(i-1,j) + source_pixel(i,j-1) + source_pixel(i,j+1) + source_pixel(i+1,j))/4;
                    float b1 = (source_pixel(i-1,j-1) + source_pixel(i+1,j-1) + source_pixel(i+1,j+1) + source_pixel(i-1,j+1))/4;
                    
                    r1 = all * red * r1;
                    g1 = all * green * g1;
                    b1 = all * blue * b1;
                    
                    destination_pixel(i,j) = make_rgba(r1,g1,b1,a);
                    
                    i = x + 1, j = y;
                    
                    float r2 = (source_pixel(i-1,j-1) + source_pixel(i+1,j-1) + source_pixel(i+1,j+1) + source_pixel(i-1,j+1))/4;
                    float g2 = (source_pixel(i-1,j) + source_pixel(i,j-1) + source_pixel(i,j+1) + source_pixel(i+1,j))/4;
                    float b2 = source_pixel(i,j);
                    
                    r2 = all * red * r2;
                    g2 = all * green * g2;
                    b2 = all * blue * b2;
                    
                    destination_pixel(i,j) = make_rgba(r2,g2,b2,a);
                    
                    i = x, j = y;
                    
                    float r3 = (source_pixel(i,j-1) + source_pixel(i,j+1))/2;
                    float g3 = source_pixel(i,j);
                    float b3 = (source_pixel(i-1,j) + source_pixel(i+1,j))/2;
                    
                    r3 = all * red * r3;
                    g3 = all * green * g3;
                    b3 = all * blue * b3;
                    
                    destination_pixel(i,j) = make_rgba(r3,g3,b3,a);
                    
                    i = x + 1, j = y + 1;
                    
                    float r4 = (source_pixel(i-1,j) + source_pixel(i+1,j))/2;
                    float g4 = source_pixel(i,j);
                    float b4 = (source_pixel(i,j-1) + source_pixel(i,j+1))/2;
                    
                    r4 = all * red * r4;
                    g4 = all * green * g4;
                    b4 = all * blue * b4;
                    
                    destination_pixel(i,j) = make_rgba(r4,g4,b4,a);
                }
            }
            
        });
        
        float low = 0, high = 1;
        vDSP_vclip((float*)cp,1,&low,&high,(float*)cp,1,finalPixelsLength/4);
    });
    
    // update params to indicate the original exposure
    CASCCDExposure* finalExposure = [CASCCDExposure exposureWithRGBAFloatPixels:finalPixels camera:/*exposure.camera*/nil params:exposure.params time:[NSDate date]];
    
    NSLog(@"debayer: %fs (r:%f, g:%f, b:%f, a:%f)",time,red,green,blue,all);
    
    return finalExposure;
}

- (CASCCDExposure*)debayer:(CASCCDExposure*)exposure
{
    return [self debayer:exposure adjustRed:1 green:1 blue:1 all:1];
}

@end

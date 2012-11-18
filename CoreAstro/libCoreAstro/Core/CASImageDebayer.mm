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

@interface CASImageDebayer ()
- (CGImageRef)debayer:(CASCCDImage*)image;
@end

@implementation CASImageDebayer 

@synthesize mode = _mode;

+ (id<CASImageDebayer>)imageDebayerWithIdentifier:(NSString*)ident;
{
    return [[[self class] alloc] init];
}

- (CGImageRef)debayer:(CASCCDImage*)image
{
    CGColorSpaceRef space = CGColorSpaceCreateWithName(kCGColorSpaceGenericRGB);
    CGContextRef context = CGBitmapContextCreate(nil, image.size.width, image.size.height, 8, (image.size.width) * 4, space, kCGImageAlphaPremultipliedLast); // RGBA
    CFRelease(space);
    
    float *gp = (float*)[image.floatPixels bytes];
    
    uint32_t *cp = (uint32_t*)CGBitmapContextGetData(context);
    bzero(cp, CGBitmapContextGetBytesPerRow(context) * CGBitmapContextGetHeight(context));
    
    const CASSize size = CASSizeMake(image.size.width, image.size.height);
    
    #define clip(x,lim) ((x) < 0 ? 0 : (x) >= (lim) ? (lim-1) : (x))
    #define clipx(x) clip(x,size.width)
    #define clipy(y) clip(y,size.height)
    #define source_pixel(x,y) (*(gp + clipx(x) + clipy(y) * size.width)*255.0)
    #define destination_pixel(x,y) *(cp + clipx(x) + clipy(y) * size.width)
    #define make_rgba(r,g,b,a) (r) | ((g) << 8) | ((b) << 16) | ((a) << 24);
    
    for (int y = 0; y < size.height; y += 2){
        
        for (int x = 0; x < size.width; x += 2){
            
            const uint8_t a = 0xff;
            
            // RG|RG|RG|RG
            // GB|GB|GB|GB
            // RG|RG|RG|RG
            // GB|GB|GB|GB
            
            if (self.mode == kCASImageDebayerRGGB){
                
                int i = x, j = y;
                
                uint8_t r1 = source_pixel(i,j);
                uint8_t g1 = (source_pixel(i-1,j) + source_pixel(i,j-1) + source_pixel(i,j+1) + source_pixel(i+1,j))/4;
                uint8_t b1 = (source_pixel(i-1,j-1) + source_pixel(i+1,j-1) + source_pixel(i+1,j+1) + source_pixel(i-1,j+1))/4;
                
                destination_pixel(i,j) = make_rgba(r1,g1,b1,a);
                
                i = x + 1, j = y + 1;
                
                uint8_t r2 = (source_pixel(i-1,j-1) + source_pixel(i+1,j-1) + source_pixel(i+1,j+1) + source_pixel(i-1,j+1))/4;
                uint8_t g2 = (source_pixel(i-1,j) + source_pixel(i,j-1) + source_pixel(i,j+1) + source_pixel(i+1,j))/4;
                uint8_t b2 = source_pixel(i,j);
                
                destination_pixel(i,j) = make_rgba(r2,g2,b2,a);
                
                i = x + 1, j = y;
                
                uint8_t r3 = (source_pixel(i,j - 1) + source_pixel(i,j + 1))/2;
                uint8_t g3 = source_pixel(i,j);
                uint8_t b3 = (source_pixel(i - 1,j) + source_pixel(i + 1,j))/2;
                
                destination_pixel(i,j) = make_rgba(r3,g3,b3,a);
                
                i = x, j = y + 1;
                
                uint8_t r4 = (source_pixel(i - 1,j) + source_pixel(i + 1,j))/2;
                uint8_t g4 = source_pixel(i,j);
                uint8_t b4 = (source_pixel(i,j - 1) + source_pixel(i,j + 1))/2;
                
                destination_pixel(i,j) = make_rgba(r4,g4,b4,a);
            }
            
            // GR|GR|GR|GR
            // BG|BG|BG|BG
            // GR|GR|GR|GR
            // BG|BG|BG|BG
            
            if (self.mode == kCASImageDebayerGRBG){
                
                int i = x + 1, j = y;
                
                uint8_t r1 = source_pixel(i,j);
                uint8_t g1 = (source_pixel(i-1,j) + source_pixel(i,j-1) + source_pixel(i,j+1) + source_pixel(i+1,j))/4;
                uint8_t b1 = (source_pixel(i-1,j-1) + source_pixel(i+1,j-1) + source_pixel(i+1,j+1) + source_pixel(i-1,j+1))/4;
                
                destination_pixel(i,j) = r1 | (g1 << 8) | (b1 << 16) | (a << 24);
                
                i = x, j = y + 1;
                
                uint8_t r2 = (source_pixel(i-1,j-1) + source_pixel(i+1,j-1) + source_pixel(i+1,j+1) + source_pixel(i-1,j+1))/4;
                uint8_t g2 = (source_pixel(i-1,j) + source_pixel(i,j-1) + source_pixel(i,j+1) + source_pixel(i+1,j))/4;
                uint8_t b2 = source_pixel(i,j);
                
                destination_pixel(i,j) = r2 | (g2 << 8) | (b2 << 16) | (a << 24);
                
                i = x, j = y;
                
                uint8_t r3 = (source_pixel(i-1,j) + source_pixel(i+1,j))/2;
                uint8_t g3 = source_pixel(i,j);
                uint8_t b3 = (source_pixel(i,j-1) + source_pixel(i,j+1))/2;
                
                destination_pixel(i,j) = r3 | (g3 << 8) | (b3 << 16) | (a << 24);
                
                i = x + 1, j = y + 1;
                
                uint8_t r4 = (source_pixel(i,j-1) + source_pixel(i,j+1))/2;
                uint8_t g4 = source_pixel(i,j);
                uint8_t b4 = (source_pixel(i-1,j) + source_pixel(i+1,j))/2;
                
                destination_pixel(i,j) = r4 | (g4 << 8) | (b4 << 16) | (a << 24);
            }
            
            // BG|BG|BG|BG
            // GR|GR|GR|GR
            // BG|BG|BG|BG
            // GR|GR|GR|GR
            
            if (self.mode == kCASImageDebayerBGGR){
                
                int i = x + 1, j = y + 1;
                
                uint8_t r1 = source_pixel(i,j);
                uint8_t g1 = (source_pixel(i-1,j) + source_pixel(i,j-1) + source_pixel(i,j+1) + source_pixel(i+1,j))/4;
                uint8_t b1 = (source_pixel(i-1,j-1) + source_pixel(i+1,j-1) + source_pixel(i+1,j+1) + source_pixel(i-1,j+1))/4;
                
                destination_pixel(i,j) = r1 | (g1 << 8) | (b1 << 16) | (a << 24);
                
                i = x, j = y;
                
                uint8_t r2 = (source_pixel(i-1,j-1) + source_pixel(i+1,j-1) + source_pixel(i+1,j+1) + source_pixel(i-1,j+1))/4;
                uint8_t g2 = (source_pixel(i-1,j) + source_pixel(i,j-1) + source_pixel(i,j+1) + source_pixel(i+1,j))/4;
                uint8_t b2 = source_pixel(i,j);
                
                destination_pixel(i,j) = r2 | (g2 << 8) | (b2 << 16) | (a << 24);
                
                i = x + 1, j = y;
                
                uint8_t r3 = (source_pixel(i,j - 1) + source_pixel(i,j + 1))/2;
                uint8_t g3 = source_pixel(i,j);
                uint8_t b3 = (source_pixel(i - 1,j) + source_pixel(i + 1,j))/2;
                
                destination_pixel(i,j) = r3 | (g3 << 8) | (b3 << 16) | (a << 24);
                
                i = x, j = y + 1;
                
                uint8_t r4 = (source_pixel(i - 1,j) + source_pixel(i + 1,j))/2;
                uint8_t g4 = source_pixel(i,j);
                uint8_t b4 = (source_pixel(i,j - 1) + source_pixel(i,j + 1))/2;
                
                destination_pixel(i,j) = r4 | (g4 << 8) | (b4 << 16) | (a << 24);
            }
            
            // GB|GB|GB|GB
            // RG|RG|RG|RG
            // GB|GB|GB|GB
            // RG|RG|RG|RG
            
            if (self.mode == kCASImageDebayerGBRG){
                
                int i = x, j = y + 1;
                
                uint8_t r1 = source_pixel(i,j);
                uint8_t g1 = (source_pixel(i-1,j) + source_pixel(i,j-1) + source_pixel(i,j+1) + source_pixel(i+1,j))/4;
                uint8_t b1 = (source_pixel(i-1,j-1) + source_pixel(i+1,j-1) + source_pixel(i+1,j+1) + source_pixel(i-1,j+1))/4;
                
                destination_pixel(i,j) = r1 | (g1 << 8) | (b1 << 16) | (a << 24);
                
                i = x + 1, j = y;
                
                uint8_t r2 = (source_pixel(i-1,j-1) + source_pixel(i+1,j-1) + source_pixel(i+1,j+1) + source_pixel(i-1,j+1))/4;
                uint8_t g2 = (source_pixel(i-1,j) + source_pixel(i,j-1) + source_pixel(i,j+1) + source_pixel(i+1,j))/4;
                uint8_t b2 = source_pixel(i,j);
                
                destination_pixel(i,j) = r2 | (g2 << 8) | (b2 << 16) | (a << 24);
                
                i = x, j = y;
                
                uint8_t r3 = (source_pixel(i,j-1) + source_pixel(i,j+1))/2;
                uint8_t g3 = source_pixel(i,j);
                uint8_t b3 = (source_pixel(i-1,j) + source_pixel(i+1,j))/2;
                
                destination_pixel(i,j) = r3 | (g3 << 8) | (b3 << 16) | (a << 24);
                
                i = x + 1, j = y + 1;
                
                uint8_t r4 = (source_pixel(i-1,j) + source_pixel(i+1,j))/2;
                uint8_t g4 = source_pixel(i,j);
                uint8_t b4 = (source_pixel(i,j-1) + source_pixel(i,j+1))/2;
                
                destination_pixel(i,j) = r4 | (g4 << 8) | (b4 << 16) | (a << 24);
            }
        }
    }
    
    return CGBitmapContextCreateImage(context);
}

@end

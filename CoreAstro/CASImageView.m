//
//  CASImageView.m
//  scrollview-test
//
//  Created by Simon Taylor on 10/28/12.
//  Copyright (c) 2012 Simon Taylor. All rights reserved.
//

#import "CASImageView.h"
#import "CASCenteringClipView.h"
#import <QuartzCore/QuartzCore.h>

@interface CASTiledLayer : CATiledLayer
@end

@implementation CASTiledLayer

+ (CFTimeInterval)fadeDuration
{
    return 0;
}

@end

@interface CASImageView ()
@property (nonatomic,strong) CIImage* CIImage;
@property (nonatomic,assign) BOOL sharpen;
@property (nonatomic,assign) BOOL invert;
@property (nonatomic,assign) BOOL reticle;
@property (nonatomic,strong) CALayer* overlayLayer;
@property (nonatomic,strong) CALayer* reticleLayer;
@end

@implementation CASImageView {
    CGImageRef _cgImage;
}

- (void)dealloc
{
    if (_cgImage){
        CGImageRelease(_cgImage);
    }
}

- (void)awakeFromNib
{
    [super awakeFromNib];
    
    if ([self.layer respondsToSelector:@selector(setDrawsAsynchronously:)]){
        self.layer.drawsAsynchronously = YES;
    }
    else {
        if (self.window.allowsConcurrentViewDrawing){
            self.canDrawConcurrently = YES;
        }
        else {
            NSLog(@"Window's allowsConcurrentViewDrawing is NO");
        }
    }
    
    // todo; might need to sync on self to protect CIImage instance
    
    // tracking area, mouse moved events, convertPoint:fromLayer
}

- (CALayer *)makeBackingLayer
{
    CASTiledLayer* layer = [[CASTiledLayer alloc] init];
    layer.tileSize = CGSizeMake(512, 512);
    return layer;
}

- (CGRect) unitFrame
{
    CIImage* image = self.CIImage;
    return image ? image.extent : [super unitFrame];
}

- (CIImage*)image
{
    return self.CIImage;
}

- (void)_setupImageLayer
{
    if (self.CIImage){
        
        CGFloat savedZoom = self.zoom;
        
        self.frame = self.CIImage.extent;
        self.bounds = self.CIImage.extent; // todo; set bounds to maintain zoom level ?
        
        self.layer.delegate = self;
        [self.layer setNeedsDisplay];
        
        self.zoom = savedZoom;
    }
}

- (void)setCIImage:(CIImage *)CIImage
{
    if (CIImage != _CIImage){
        _CIImage = CIImage;
        [self _setupImageLayer];
    }
}

- (CGImageRef) CGImage
{
    if (!_cgImage && self.image){
        _cgImage = [[NSBitmapImageRep alloc] initWithCIImage:self.image].CGImage;
    }
    return _cgImage;
}

- (void)setCGImage:(CGImageRef)CGImage
{
    if (_cgImage != CGImage){
        if (_cgImage){
           // CGImageRelease(_cgImage);
        }
        _cgImage = CGImage;
        if (_cgImage){
            self.CIImage = [[CIImage alloc] initWithCGImage:_cgImage];
        }
        else {
            self.CIImage = nil;
        }
    }
}

- (void)setUrl:(NSURL *)url
{
    if (url != _url){
        
        _url = url;
        
        CGImageSourceRef source = CGImageSourceCreateWithURL((__bridge CFURLRef)url,nil);
        self.CIImage = [CIImage imageWithCGImage:CGImageSourceCreateImageAtIndex(source,0,nil)];
        CFRelease(source);
        
        [self _setupImageLayer];
    }
}

//- (void)drawRect:(NSRect)dirtyRect
//{
//    [[NSColor redColor] set];
//    NSRectFill(dirtyRect);
//}

// draws concurrently mode

- (void)drawLayer:(CALayer *)layer inContext:(CGContextRef)context
{
    CIImage* image = self.CIImage;
    if (!image){
        return;
    }
        
    if (self.invert){
        CIFilter* invert = [CIFilter filterWithName:@"CIColorInvert"];
        [invert setDefaults];
        [invert setValue:image forKey:@"inputImage"];
        image = [invert valueForKey:@"outputImage"];
    }

    if (self.sharpen){
        CIFilter* invert = [CIFilter filterWithName:@"CIUnsharpMask"];
        [invert setDefaults];
        [invert setValue:image forKey:@"inputImage"];
        [invert setValue:[NSNumber numberWithInt:100] forKey:@"inputRadius"];
        [invert setValue:[NSNumber numberWithInt:1] forKey:@"inputIntensity"];
        image = [invert valueForKey:@"outputImage"];
    }
    
    CIContext* ciContext = [CIContext contextWithCGContext:context options:nil];

    [ciContext drawImage:image inRect:layer.bounds fromRect:self.CIImage.extent];
}

- (void)setInvert:(BOOL)invert
{
    if (_invert != invert){
        _invert = invert;
        [self.layer setNeedsDisplay];
    }
}

- (void)setSharpen:(BOOL)sharpen
{
    if (_sharpen != sharpen){
        _sharpen = sharpen;
        [self.layer setNeedsDisplay];
    }
}

- (CAShapeLayer*)createReticleLayer
{
    CAShapeLayer* reticleLayer = [CAShapeLayer layer];
    
    CGMutablePathRef path = CGPathCreateMutable();
    
    const CGFloat width = 1.5;
    CGPathAddRect(path, nil, CGRectMake(0, self.CIImage.extent.size.height/2.0, self.CIImage.extent.size.width, width));
    CGPathAddRect(path, nil, CGRectMake(self.CIImage.extent.size.width/2.0, 0, width, self.CIImage.extent.size.height));
    
//    CGPathAddRect(path, nil, CGRectMake(0,0,self.CIImage.extent.size.width,self.CIImage.extent.size.height));
    CGPathAddEllipseInRect(path, nil, CGRectMake(self.CIImage.extent.size.width/2.0 - 50,self.CIImage.extent.size.height/2.0 - 50,100,100));
    
    reticleLayer.path = path;
    reticleLayer.strokeColor = CGColorCreateGenericRGB(1,0,0,1);
    reticleLayer.fillColor = CGColorGetConstantColor(kCGColorClear);
    reticleLayer.borderWidth = width;
    
    return reticleLayer;
}

- (void)setReticle:(BOOL)reticle
{
    if (_reticle != reticle){
        _reticle = reticle;
        if (_reticleLayer){
            [_reticleLayer removeFromSuperlayer];
            _reticleLayer = nil;
        }
        if (_reticle){
            _reticleLayer = [self createReticleLayer];
        }
        if (_reticleLayer){
            [self.overlayLayer addSublayer:_reticleLayer];
            // autoresize mask
        }
    }
}

- (CALayer*)overlayLayer
{
    if (!_overlayLayer){
        _overlayLayer = [CALayer layer];
        [self.layer addSublayer:_overlayLayer];
    }
    return _overlayLayer;
}

@end

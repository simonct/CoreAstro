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
@property (nonatomic,assign) BOOL reticle;
@property (nonatomic,strong) CALayer* overlayLayer;
@property (nonatomic,strong) CALayer* reticleLayer;
@end

@implementation CASImageView {
    CGImageRef _cgImage;
    BOOL _invert, _medianFilter, _contrastStretch;
    float _stretchMin, _stretchMax, _stretchGamma;
}

+ (void)initialize
{
    if (self == [CASImageView class]){

        NSURL* url = [[[NSBundle mainBundle] builtInPlugInsURL] URLByAppendingPathComponent:@"ContrastStretch.plugin"];
        [CIPlugIn loadPlugIn:url allowExecutableCode:YES];
    }
}

- (id)initWithFrame:(NSRect)frameRect
{
    self = [super initWithFrame:frameRect];
    if (self){
        _stretchMin = 0;
        _stretchMax = 1;
        _stretchGamma = 1;
    }
    return self;
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
    
    _stretchMin = 0;
    _stretchMax = 1;
    _stretchGamma = 1;
    _contrastStretch = 1;

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
        
        self.zoom = savedZoom;
    }
    
    self.layer.delegate = self;
    [self.layer setNeedsDisplay];
    [self setNeedsDisplay:YES];
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
        if (source){
            self.CIImage = [CIImage imageWithCGImage:CGImageSourceCreateImageAtIndex(source,0,nil)];
            CFRelease(source);
        }
        
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

    if (self.medianFilter){
        CIFilter* median = [CIFilter filterWithName:@"CIMedianFilter"];
        [median setDefaults];
        [median setValue:image forKey:@"inputImage"];
        image = [median valueForKey:@"outputImage"];
    }
    
    if (self.contrastStretch){
        CIFilter* stretch = [CIFilter filterWithName:@"CASContrastStretchFilter"];
        if (stretch){
            [stretch setDefaults];
            [stretch setValue:image forKey:@"inputImage"];
            [stretch setValue:@(self.stretchMin) forKey:@"inputMin"];
            [stretch setValue:@(self.stretchMax) forKey:@"inputMax"];
            [stretch setValue:@(self.stretchGamma) forKey:@"gamma"];
            image = [stretch valueForKey:@"outputImage"];
        }
    }

    const CGRect clip = CGContextGetClipBoundingBox(context);
    [[CIContext contextWithCGContext:context options:nil] drawImage:image inRect:clip fromRect:clip];
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

@implementation CASImageView (CASImageProcessing)

- (BOOL)invert
{
    return _invert;
}

- (void)setInvert:(BOOL)invert
{
    if (_invert != invert){
        _invert = invert;
        [self.layer setNeedsDisplay];
    }
}

- (BOOL)medianFilter
{
    return _medianFilter;
}

- (void)setMedianFilter:(BOOL)medianFilter
{
    if (medianFilter != _medianFilter){
        _medianFilter = medianFilter;
        [self.layer setNeedsDisplay];
    }
}

- (BOOL)contrastStretch
{
    return _contrastStretch;
}

- (void)setContrastStretch:(BOOL)contrastStretch
{
    if (contrastStretch != _contrastStretch){
        _contrastStretch = contrastStretch;
        [self.layer setNeedsDisplay];
    }
}

- (float)stretchMin
{
    return _stretchMin;
}

- (void)setStretchMin:(float)stretchMin
{
    if (stretchMin < 0 || stretchMin > 1){
        return;
    }
    stretchMin = MIN(stretchMin, _stretchMax);
    if (_stretchMin != stretchMin){
        _stretchMin = stretchMin;
        [self.layer setNeedsDisplay];
    }
}

- (float)stretchMax
{
    return _stretchMax;
}

- (void)setStretchMax:(float)stretchMax
{
    if (stretchMax < 0 || stretchMax > 1){
        return;
    }
    stretchMax = MAX(stretchMax, _stretchMin);
    if (_stretchMax != stretchMax){
        _stretchMax = stretchMax;
        [self.layer setNeedsDisplay];
    }
}

- (float)stretchGamma
{
    return _stretchGamma;
}

- (void)setStretchGamma:(float)stretchGamma
{
    if (_stretchGamma != stretchGamma){
        _stretchGamma = stretchGamma;
        [self.layer setNeedsDisplay];
    }
}

@end

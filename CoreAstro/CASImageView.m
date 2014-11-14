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
// atomic map of filters
@end

@implementation CASImageView {
    CGImageRef _cgImage;
    BOOL _invert, _medianFilter, _contrastStretch, _debayer;
    float _stretchMin, _stretchMax, _stretchGamma;
    CASVector _debayerOffset;
    CIImage* _filteredCIImage;
    NSMutableDictionary* _filterCache;
    CGRect _extent;
    BOOL _flipVertical, _flipHorizontal;
}

+ (void)loadCIPluginWithName:(NSString*)name
{
    [CIPlugIn loadPlugIn:[[[NSBundle mainBundle] builtInPlugInsURL] URLByAppendingPathComponent:name] allowExecutableCode:YES];
}

+ (void)initialize
{
    if (self == [CASImageView class]){
        [self loadCIPluginWithName:@"Debayer.plugin"];
        [self loadCIPluginWithName:@"ContrastStretch.plugin"];
    }
}

+ (BOOL)createLayerInMakeBackingLayer
{
    return [self instancesRespondToSelector:@selector(canDrawSubviewsIntoLayer)]; // using this as a proxy for 10.9+
}

+ (CALayer*)createBackingLayer
{
    CASTiledLayer* layer = [[CASTiledLayer alloc] init];
    layer.tileSize = CGSizeMake(1024, 1024); // todo; this value really needs to come from OpenGL
    return layer;
}

- (id)initWithFrame:(NSRect)frameRect
{
    self = [super initWithFrame:frameRect];
    if (self){
        _stretchMin = 0;
        _stretchMax = 1;
        _stretchGamma = 1;
        _extent = CGRectNull;
        
        // set a custom backing layer (could vary the tile size depending on the image size ?)
        if (![[self class] createLayerInMakeBackingLayer]){
            [self setLayer:[[self class] createBackingLayer]];
        }
        self.wantsLayer = YES;
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
    _contrastStretch = 0;
    _extent = CGRectNull;

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

- (CALayer*)makeBackingLayer
{
    if ([[self class] createLayerInMakeBackingLayer]){
        return [[self class] createBackingLayer];
    }
    else {
        return [super makeBackingLayer];
    }
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

- (CIFilter*)filterWithName:(NSString*)name
{
    CIFilter* result; // arc nils it
    @synchronized(self){
        if (!_filterCache){
            _filterCache = [NSMutableDictionary dictionaryWithCapacity:5];
        }
        result = _filterCache[name];
        if (!result){
            result = [CIFilter filterWithName:name];
            if (result){
                _filterCache[name] = result;
            }
        }
    }
    return result;
}

- (CIImage*)filterImage:(CIImage*)image // note; this is called from -drawLayer:inContext
{
    if (!image){
        return nil;
    }
    
    if (!CGRectIsNull(_extent)){
        // set roi on filters - does this mean I have to sublcass all the filters ?
        // or at least have a wrapper than composites with the underlying filter ?
    }
    
    // todo; allow filter order to be set externally ?
    // todo; set roi to the area of the subframe using CIFilterShape
    
    if (self.flipVertical || self.flipHorizontal){
        
        CIFilter* flip = [self filterWithName:@"CIAffineTransform"];
        [flip setDefaults];
        [flip setValue:image forKey:@"inputImage"];
        
        NSAffineTransform* transform = [NSAffineTransform transform];
        if (self.flipVertical){
            [transform scaleXBy:1.0 yBy:-1.0];
            [transform translateXBy:0 yBy:-image.extent.size.height];
        }
        if (self.flipHorizontal){
            [transform scaleXBy:-1.0 yBy:1.0];
            [transform translateXBy:-image.extent.size.width yBy:0];
        }
        [flip setValue:transform forKey:@"inputTransform"];
        
        image = [flip valueForKey:@"outputImage"];
    }

    if (self.debayer){
        CIFilter* debayer = [self filterWithName:@"CASDebayerFilter"];
        if (debayer){
            [debayer setDefaults];
            [debayer setValue:image forKey:@"inputImage"];
            [debayer setValue:[CIVector vectorWithX:self.debayerOffset.x Y:self.debayerOffset.y] forKey:@"inputOffset"];
            image = [debayer valueForKey:@"outputImage"];
        }
    }
    
    if (self.medianFilter){
        CIFilter* median = [self filterWithName:@"CIMedianFilter"];
        [median setDefaults];
        [median setValue:image forKey:@"inputImage"];
        image = [median valueForKey:@"outputImage"];
    }
    
    if (self.contrastStretch){
        CIFilter* stretch = [self filterWithName:@"CASContrastStretchFilter"];
        if (stretch){
            [stretch setDefaults];
            [stretch setValue:image forKey:@"inputImage"];
            [stretch setValue:@(self.stretchMin) forKey:@"inputMin"];
            [stretch setValue:@(self.stretchMax) forKey:@"inputMax"];
            [stretch setValue:@(self.stretchGamma) forKey:@"inputGamma"];
            image = [stretch valueForKey:@"outputImage"];
        }
    }
    
    if (self.invert){
        CIFilter* invert = [self filterWithName:@"CIColorInvert"];
        [invert setDefaults];
        [invert setValue:image forKey:@"inputImage"];
        image = [invert valueForKey:@"outputImage"];
    }
    
    return [image imageByCroppingToRect:self.image.extent]; // this seems to be required to prevent the filtered image from having infinite extent
}

- (void)setupImageLayer
{
    if (self.CIImage){
        
        CGFloat savedZoom = self.zoom;
        
        self.frame = self.CIImage.extent;
        self.bounds = self.CIImage.extent; // todo; set bounds to maintain zoom level ?
        
        self.zoom = savedZoom;
    }
    
    self.layer.delegate = self;
    [self.layer setNeedsDisplay];
//    [self setNeedsDisplay:YES];
}

- (void)setCIImage:(CIImage *)CIImage
{
    [self setCIImage:CIImage resetDisplay:YES];
}

- (void)setCIImage:(CIImage*)CIImage resetDisplay:(BOOL)resetDisplay
{
    if (CIImage != _CIImage){
        _CIImage = CIImage;
        @synchronized(self){
            _filteredCIImage = nil;
        }
        if (resetDisplay){
            [self setupImageLayer];
        }
        else {
            [self.layer setNeedsDisplay];
        }
        
        // todo: setNeedsDisplayInRect: with subframe
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
    [self setCGImage:CGImage resetDisplay:YES];
}

- (void)setCGImage:(CGImageRef)CGImage resetDisplay:(BOOL)resetDisplay
{
    if (_cgImage != CGImage){
        if (_cgImage){
            // CGImageRelease(_cgImage);
        }
        _cgImage = CGImage;
        if (_cgImage){
            [self setCIImage:[CIImage imageWithCGImage:_cgImage options:@{kCIImageColorSpace:[NSNull null]}] resetDisplay:resetDisplay];
        }
        else {
            self.CIImage = nil;
        }
    }
}

- (CIImage*)filteredCIImage
{
    @synchronized(self){
        if (!_filteredCIImage){
            _filteredCIImage = [self filterImage:self.CIImage];
        }
    }
    return _filteredCIImage;
}

- (void)setUrl:(NSURL *)url
{
    if (url != _url){
        
        _url = url;
        
        CGImageSourceRef source = CGImageSourceCreateWithURL((__bridge CFURLRef)url,nil);
        if (source){
            CGImageRef cgImage = CGImageSourceCreateImageAtIndex(source,0,nil);
            if (cgImage){
                self.CIImage = [CIImage imageWithCGImage:cgImage options:@{kCIImageColorSpace:[NSNull null]}];
                CFRelease(cgImage);
            }
            CFRelease(source);
        }
        
        [self setupImageLayer];
    }
}

- (void)drawLayer:(CALayer *)layer inContext:(CGContextRef)context
{
    [self filteredCIImage];
    if (_filteredCIImage){
        const CGRect clip = CGContextGetClipBoundingBox(context);
        [[CIContext contextWithCGContext:context options:nil] drawImage:_filteredCIImage inRect:clip fromRect:clip];
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
    
    CGColorRef red = CGColorCreateGenericRGB(1,0,0,1);
    
    reticleLayer.path = path;
    reticleLayer.strokeColor = red;
    reticleLayer.fillColor = CGColorGetConstantColor(kCGColorClear);
    reticleLayer.borderWidth = width;
    
    CFRelease(red);
    CFRelease(path);
    
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

- (void)resetFilteredImage
{
    @synchronized(self){
        _filteredCIImage = nil; // crude, we should be able to update filters in the chain
    }
    [self.layer setNeedsDisplay];
}

- (BOOL)invert
{
    return _invert;
}

- (void)setInvert:(BOOL)invert
{
    if (_invert != invert){
        _invert = invert;
        [self resetFilteredImage];
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
        [self resetFilteredImage];
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
        [self resetFilteredImage];
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
        if (self.contrastStretch){
            [self resetFilteredImage];
        }
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
        if (self.contrastStretch){
            [self resetFilteredImage];
        }
    }
}

- (BOOL)debayer
{
    return _debayer;
}

- (void)setDebayer:(BOOL)debayer
{
    if (debayer != _debayer){
        _debayer = debayer;
        [self resetFilteredImage];
    }
}

- (CASVector)debayerOffset
{
    return _debayerOffset;
}

- (void)setDebayerOffset:(CASVector)debayerOffset
{
    debayerOffset.x = round(fmin(fmax(debayerOffset.x, 0), 1));
    debayerOffset.y = round(fmin(fmax(debayerOffset.y, 0), 1));
    if (debayerOffset.x != _debayerOffset.x || debayerOffset.y != _debayerOffset.y){
        _debayerOffset = debayerOffset;
        if (self.debayer){
            [self resetFilteredImage];
        }
    }
}

- (CGRect)extent
{
    return _extent;
}

- (void)setExtent:(CGRect)extent
{
    if (!CGRectEqualToRect(_extent, extent)){
        _extent = extent;
        [self resetFilteredImage];
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
        [self resetFilteredImage];
    }
}

- (BOOL)flipVertical
{
    return _flipVertical;
}

- (void)setFlipVertical:(BOOL)flipVertical
{
    if (flipVertical != _flipVertical){
        _flipVertical = flipVertical;
        [self resetFilteredImage];
    }
}

- (BOOL)flipHorizontal
{
    return _flipHorizontal;
}

- (void)setFlipHorizontal:(BOOL)flipHorizontal
{
    if (flipHorizontal != _flipHorizontal){
        _flipHorizontal = flipHorizontal;
        [self resetFilteredImage];
    }
}

@end

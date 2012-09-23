//
//  MKOAppDelegate.m
//  guide-test
//
//  Created by Simon Taylor on 9/23/12.
//  Copyright (c) 2012 Simon Taylor. All rights reserved.
//

#import "MKOAppDelegate.h"
#import "CASCCDImage.h"
#import "CASAutoGuider.h"
#import "CASCCDExposure.h"
#import <QuartzCore/QuartzCore.h>

@interface GuideImageView : NSImageView
@property (nonatomic,strong) NSArray* stars;
@end

@implementation GuideImageView

- (void)setStars:(NSArray*)stars {
    _stars = stars;
    [self setNeedsDisplay];
}

// convert from image to view co-ords
- (NSPoint)convertImagePoint:(NSPoint)imagePoint {
    
    NSAssert(self.imageAlignment == NSImageAlignCenter, @"imageAlignment == NSImageAlignCenter");
    NSAssert(self.imageScaling == NSImageScaleNone, @"self.imageScaling == NSImageScaleNone");
    
    const NSSize size = self.image.size;
    const NSPoint origin = NSMakePoint(self.bounds.size.width/2 - size.width/2, self.bounds.size.height/2 - size.height/2);
    return NSMakePoint(imagePoint.x + origin.x,size.height - imagePoint.y + origin.y);
}

// convert from view co-ords to image point
- (NSPoint)convertViewPoint:(NSPoint)imagePoint {
    
    NSAssert(self.imageAlignment == NSImageAlignCenter, @"imageAlignment == NSImageAlignCenter");
    NSAssert(self.imageScaling == NSImageScaleNone, @"self.imageScaling == NSImageScaleNone");
    
    // todo
    
    return imagePoint;
}

- (void)drawRect:(NSRect)dirtyRect {
    [super drawRect:dirtyRect];
    for (NSValue* v in self.stars){
        const NSPoint p = [self convertImagePoint:[v pointValue]];
        NSBezierPath* path = [NSBezierPath bezierPathWithRoundedRect:NSMakeRect(p.x-10, p.y-10, 20, 20) xRadius:10 yRadius:10];
        [[NSColor yellowColor] set];
        path.lineWidth = 1.5;
        [path stroke];
    }
}

@end

@interface MKOAppDelegate ()
@property (nonatomic,assign) CGFloat radius, starX, starY;
@property (nonatomic,strong) CASGuideAlgorithm* algorithm;
@end

@implementation MKOAppDelegate {
    CASSize _size;
    CGContextRef _bitmap;
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    self.algorithm = [CASGuideAlgorithm guideAlgorithmWithIdentifier:nil];
    self.algorithm.imageProcessor = [CASImageProcessor imageProcessorWithIdentifier:nil];
    
    _size = CASSizeMake(500, 500);
    self.starX = _size.width/2, self.starY = _size.height/2;
    _bitmap = [CASCCDImage createBitmapContextWithSize:_size bitsPerPixel:16];
    if (_bitmap){
        self.radius = 0;
    }
}

- (void)setRadius:(CGFloat)radius
{
    _radius = radius;
    [self drawStar];
}

- (void)setStarX:(CGFloat)starX
{
    _starX = starX;
    [self drawStar];
}

- (void)setStarY:(CGFloat)starY
{
    _starY = starY;
    [self drawStar];
}

- (void)drawStar
{
    // clear the background
    CGContextSetRGBFillColor(_bitmap,0,0,0,1);
    CGContextFillRect(_bitmap,CGRectMake(0, 0, _size.width, _size.height));

    // draw a star
    CGContextSetRGBFillColor(_bitmap,1,1,1,1);
    CGContextFillEllipseInRect(_bitmap, CGRectMake(_starX, _starY, 5, 5));
    
    // blur it
    CIFilter* filter = [CIFilter filterWithName:@"CIGaussianBlur"];
    [filter setDefaults];
    
    CIImage* inputImage = [CIImage imageWithCGImage:CGBitmapContextCreateImage(_bitmap)];
    [filter setValue:inputImage forKey:@"inputImage"];
    [filter setValue:[NSNumber numberWithFloat:_radius] forKey:@"inputRadius"];

    CIImage* outputImage = [filter valueForKey:@"outputImage"];
    CIContext* context = [CIContext contextWithCGContext:_bitmap options:nil];
    [context drawImage:outputImage inRect:CGRectMake(0, 0, _size.width, _size.height) fromRect:CGRectMake(0, 0, _size.width, _size.height)];

    // build an exposure
    NSData* pixels = [NSData dataWithBytesNoCopy:CGBitmapContextGetData(_bitmap) length:_size.width * _size.height * 2 freeWhenDone:NO];
    CASExposeParams params = CASExposeParamsMake(_size.width, _size.height, 0, 0, _size.width, _size.height, 1, 1, 16, 1);
    CASCCDExposure* exposure = [CASCCDExposure exposureWithPixels:pixels camera:nil params:params time:nil];
    
    // process it
    self.imageView.stars = [self.algorithm locateStars:exposure];

    // display it
    self.imageView.image = [[NSImage alloc] initWithCGImage:CGBitmapContextCreateImage(_bitmap) size:NSMakeSize(_size.width, _size.height)];
}

@end

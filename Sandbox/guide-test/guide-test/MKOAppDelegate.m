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

static CGFloat kCASStarRadius = 2.5;
static NSInteger kCASImageSize = 500;
static NSInteger kCASStarMarkerRadius = 5;
static CGFloat kCASPixelsPerSecond = 5/0.750;

@interface GuideImageView : NSImageView
@property (nonatomic,strong) NSArray* stars;
@property (nonatomic,assign) CGPoint lock;
@property (nonatomic,assign) CGFloat radius;
@property (nonatomic,copy) NSString* status;
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
        NSBezierPath* path = [NSBezierPath bezierPathWithRoundedRect:NSMakeRect(p.x-kCASStarMarkerRadius, p.y-kCASStarMarkerRadius, 2*kCASStarMarkerRadius, 2*kCASStarMarkerRadius) xRadius:kCASStarMarkerRadius yRadius:kCASStarMarkerRadius];
        [[NSColor yellowColor] set];
        path.lineWidth = 1.5;
        [path stroke];
    }
    
    const NSPoint p = [self convertImagePoint:self.lock];
    NSBezierPath* path = [NSBezierPath bezierPathWithRoundedRect:NSMakeRect(p.x-self.radius, p.y-self.radius, self.radius*2, self.radius*2) xRadius:self.radius yRadius:self.radius];
    [[NSColor redColor] set];
    path.lineWidth = 1.5;
    [path stroke];
    
    [self.status drawAtPoint:[self convertImagePoint:NSMakePoint(10, 40)] withAttributes:[NSDictionary dictionaryWithObjectsAndKeys:[NSColor whiteColor],NSForegroundColorAttributeName,[NSFont boldSystemFontOfSize:18],NSFontAttributeName, nil]];
}

@end

@interface MKOAppDelegate ()
@property (nonatomic,assign) CGFloat radius, starX, starY;
@property (nonatomic,assign) NSInteger direction;
@property (nonatomic,strong) CASGuideAlgorithm* algorithm;
@end

@implementation MKOAppDelegate {
    CASSize _size;
    CGContextRef _bitmap;
    BOOL _guiding;
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    self.algorithm = [CASGuideAlgorithm guideAlgorithmWithIdentifier:nil];
    self.algorithm.imageProcessor = [CASImageProcessor imageProcessorWithIdentifier:nil];
    
    _size = CASSizeMake(kCASImageSize, kCASImageSize);
    self.starX = _size.width/2, self.starY = _size.height/2;
    _bitmap = [CASCCDImage newBitmapContextWithSize:_size bitsPerPixel:16];
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
    if (!_bitmap){
        return;
    }
    
    // clear the background
    CGContextSetRGBFillColor(_bitmap,0,0,0,1);
    CGContextFillRect(_bitmap,CGRectMake(0, 0, _size.width, _size.height));

    // draw a star
    CGContextSetRGBFillColor(_bitmap,1,1,1,1);
    CGContextFillEllipseInRect(_bitmap, CGRectMake(_starX, _starY, kCASStarRadius, kCASStarRadius));
    
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
    
    if (_guiding){
        
        // update guide state
        [self.algorithm updateWithExposure:exposure guideCallback:^(NSError *error, CASGuiderDirection direction, NSInteger duration) {
            
            NSLog(@"pulse: %d duration: %ld",direction,duration);
            
            const CGFloat delta = kCASPixelsPerSecond * duration/1000.0;
            
            [self willChangeValueForKey:@"starX"];
            [self willChangeValueForKey:@"starY"];
            
            switch (direction) {
                case kCASGuiderDirection_RAPlus:
                    _starX -= delta;
                    break;
                case kCASGuiderDirection_RAMinus:
                    _starX += delta;
                    break;
                case kCASGuiderDirection_DecPlus:
                    _starY += delta;
                    break;
                case kCASGuiderDirection_DecMinus:
                    _starY -= delta;
                    break;
                default:
                    break;
            }
            
            NSLog(@"_starX: %f, _starY: %f",_starX,_starY);
            
            // update UI
            [self didChangeValueForKey:@"starX"];
            [self didChangeValueForKey:@"starY"];
            
            // draw the star and feed the image back into the guide algorithm next time round the run loop
            int64_t delayInSeconds = 1.0;
            dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, delayInSeconds * NSEC_PER_SEC);
            dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
                [self drawStar];
            });
        }];
        self.imageView.lock = self.algorithm.lockLocation;
        self.imageView.radius = self.algorithm.searchRadius;
        self.imageView.status = self.algorithm.status;
    }
    else {
        // locate any stars
        self.imageView.stars = [self.algorithm locateStars:exposure];
    }

    // display it
    self.imageView.image = [[NSImage alloc] initWithCGImage:CGBitmapContextCreateImage(_bitmap) size:NSMakeSize(_size.width, _size.height)];
}

- (IBAction)reset:(id)sender {
    self.starX = _size.width/2, self.starY = _size.height/2;
    [self.algorithm resetStarLocation:CGPointMake(self.starX, self.starY)];
    [self drawStar];
}

- (IBAction)start:(NSButton*)sender {
    _guiding = !_guiding;
    if (_guiding){
        sender.title = @"Stop";
    }
    else {
        sender.title = @"Start";
    }
    if (_guiding){
        // reset
        if ([self.imageView.stars count]){
            [self.algorithm resetStarLocation:[self.imageView.stars[0] pointValue]];
        }
    }
    [self drawStar];
}

- (IBAction)pulse:(id)sender {
    
    if (_guiding){
        
        [self willChangeValueForKey:@"starX"];
        [self willChangeValueForKey:@"starY"];

        switch (self.direction) {
            case kCASGuiderDirection_RAPlus:
                _starX -= 1;
                break;
            case kCASGuiderDirection_RAMinus:
                _starX += 1;
                break;
            case kCASGuiderDirection_DecPlus:
                _starY += 1;
                break;
            case kCASGuiderDirection_DecMinus:
                _starY -= 1;
                break;
            default:
                break;
        }
        
        [self didChangeValueForKey:@"starX"];
        [self didChangeValueForKey:@"starY"];
        
        dispatch_async(dispatch_get_current_queue(), ^{
            [self drawStar];
        });
    }
}

@end

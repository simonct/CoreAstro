//
//  AppDelegate.m
//  debayer
//
//  Created by Simon Taylor on 04/09/2012.
//  Copyright (c) 2012 Simon Taylor. All rights reserved.
//

#import "AppDelegate.h"
#import "CASCCDExposureIO.h"
#import <QuartzCore/QuartzCore.h>

@interface AppDelegate ()<CIFilterConstructor>
@property (nonatomic,assign) BOOL debayer;
@property (nonatomic,assign) BOOL scalesToFit;
@property (nonatomic,assign) BOOL debayerCoreImage;
@property (nonatomic,assign) NSInteger mode;
@property (nonatomic,assign) NSInteger offsetX, offsetY;
@property (nonatomic,strong) CASCCDImage* image;
@property (nonatomic,strong) CASCCDExposure* exposure;
@property (nonatomic,strong) NSBundle* filterBundle;
@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    [CIFilter registerFilterName:@"Debayer" constructor:self classAttributes:nil];

    self.debayer = NO;
    self.scalesToFit = YES;
    self.mode = 0;
}

- (CIFilter *)filterWithName:(NSString *)name;
{
    if (!self.filterBundle){
        self.filterBundle = [NSBundle bundleWithPath:[[NSBundle mainBundle] pathForResource:@"debayer-cifilter" ofType:@"plugin"]];
        NSError* error = nil;
        [self.filterBundle loadAndReturnError:&error];
        if (error) {
            NSLog(@"error: %@",error);
        }
    }
    return [[NSClassFromString(@"debayer_cifilterFilter") alloc] init];
}

- (void)openDocument:sender
{
    NSOpenPanel* open = [NSOpenPanel openPanel];
    
    open.allowedFileTypes = @[@"caExposure"]; // get from CASCCDExposureIO
    open.allowsMultipleSelection = NO;
    
    [open beginSheetModalForWindow:self.window completionHandler:^(NSInteger result) {
        
        if (result == NSFileHandlingPanelOKButton){
            
            CASCCDExposureIO* io = [CASCCDExposureIO exposureIOWithPath:open.URL.path];

            self.exposure = [[CASCCDExposure alloc] init];
            self.exposure.io = io;
            
            if (![self.exposure.io readExposure:self.exposure readPixels:YES error:nil]){
                NSLog(@"Failed to read image");
            }
            else {
                self.image = [self.exposure newImage];
            }
        }
    }];
}

- (void)updateImage
{
    if (!self.image){
        self.imageView.image = nil;
    }
    else {
        
        CGImageRef cgimage = nil;
        
        if (self.debayer){
            if (self.debayerCoreImage){
                cgimage = [self debayerCI:self.image];
            }
            else {
                cgimage = [self debayer:self.image];
            }
        }
        else {
            cgimage = self.image.CGImage;
        }
        
        self.imageView.image = [[NSImage alloc] initWithCGImage:cgimage size:NSMakeSize(CGImageGetWidth(cgimage), CGImageGetHeight(cgimage))];
    }
}

- (void)setDebayer:(BOOL)debayer
{
    _debayer = debayer;

    [self updateImage];
}

- (void)setDebayerCoreImage:(BOOL)debayerCoreImage
{
    _debayerCoreImage = debayerCoreImage;
    
    [self updateImage];
}

- (void)setOffsetX:(NSInteger)offsetX
{
    _offsetX = offsetX;
    
    [self updateImage];
}

- (void)setOffsetY:(NSInteger)offsetY
{
    _offsetY = offsetY;
    
    [self updateImage];
}

- (void)setNilValueForKey:(NSString*)key
{    
}

- (void)setScalesToFit:(BOOL)scalesToFit
{
    if (self.image){
        
        if (scalesToFit){
            self.imageView.imageScaling = NSImageScaleProportionallyUpOrDown;
        }
        else {
            self.imageView.imageScaling = NSImageScaleNone;
        }
    }
    
    _scalesToFit = scalesToFit;
}

- (void)setMode:(NSInteger)mode
{
    _mode = mode;
    
    [self updateImage];
}

- (void)setImage:(CASCCDImage *)image
{
    _image = image;
    
    [self updateImage];
}

- (CGImageRef)debayer:(CASCCDImage*)image
{
    CGColorSpaceRef space = CGColorSpaceCreateWithName(kCGColorSpaceGenericRGB);
    CGContextRef context = CGBitmapContextCreate(nil, image.size.width, image.size.height, 8, (image.size.width) * 4, space, kCGImageAlphaPremultipliedLast); // RGBA
    CFRelease(space);
    
    uint16_t *gp = (uint16_t*)[self.exposure.pixels bytes];
    
    uint32_t *cp = CGBitmapContextGetData(context);
    bzero(cp, CGBitmapContextGetBytesPerRow(context) * CGBitmapContextGetHeight(context));
    
    const CASSize size = CASSizeMake(image.size.width, image.size.height);

    #define clip(x,lim) ((x) < 0 ? 0 : (x) >= (lim) ? (lim-1) : (x))
    #define clipx(x) clip(x,size.width)
    #define clipy(y) clip(y,size.height)
    #define source_pixel(x,y) (*(gp + clipx(x) + clipy(y) * size.width)/257)
    #define destination_pixel(x,y) *(cp + clipx(x) + clipy(y) * size.width)
    #define make_rgba(r,g,b,a) (r) | ((g) << 8) | ((b) << 16) | ((a) << 24);
    
    for (int y = 0; y < size.height; y += 2){
        
        for (int x = 0; x < size.width; x += 2){
        
            const uint8_t a = 0xff;

            // RG|RG|RG|RG
            // GB|GB|GB|GB
            // RG|RG|RG|RG
            // GB|GB|GB|GB

            if (self.mode == 0){

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

            if (self.mode == 1){
                
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
            
            if (self.mode == 2){
                
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
            
            if (self.mode == 3){
                
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

- (CGImageRef)debayerCI:(CASCCDImage*)image
{
    CIImage* inputImage = [CIImage imageWithCGImage:image.CGImage];
    
    CIFilter* filter = [CIFilter filterWithName:@"Debayer"];

    [filter setDefaults];
    [filter setValue:inputImage forKey:@"inputImage"];
    [filter setValue:[CIVector vectorWithX:self.offsetX Y:self.offsetY] forKey:@"inputOffset"];
    
    CIImage* outputImage = [filter valueForKey:@"outputImage"];

    CGColorSpaceRef space = CGColorSpaceCreateWithName(kCGColorSpaceGenericRGB);
    CGContextRef context = CGBitmapContextCreate(nil, image.size.width, image.size.height, 8, (image.size.width) * 4, space, kCGImageAlphaPremultipliedLast); // RGBA
    CIContext* ctx = [CIContext contextWithCGContext:context options:nil];
    [ctx drawImage:outputImage atPoint:CGPointZero fromRect:CGRectMake(0, 0, image.size.width, image.size.height)];
    CFRelease(space);

    return CGBitmapContextCreateImage(context);
}

@end

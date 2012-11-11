//
//  MKOAppDelegate.m
//  segmentation-test
//
//  Created by Simon Taylor on 11/11/12.
//  Copyright (c) 2012 Simon Taylor. All rights reserved.
//

#import "MKOAppDelegate.h"
#import "CASCCDExposureIO.h"
#import "CASRegionGrowerSegmenter.h"

@interface MKOAppDelegate ()
@property (nonatomic,assign) BOOL segmenting;
@property (nonatomic,assign) NSInteger maxNumRegions, minNumPixelsInRegion, thresholdingMode, customThreshold;
@property (nonatomic,strong) CASCCDExposure* exposure;
@end

@implementation MKOAppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    self.maxNumRegions = 20;
    self.minNumPixelsInRegion = 5;
    self.thresholdingMode = kThresholdingModeUseAverage;
}

- (NSImage*)createExposureImage
{
    if (!self.exposure){
        return nil;
    }
    CGImageRef image = [self.exposure createImage].CGImage;
    return [[NSImage alloc] initWithCGImage:image size:NSMakeSize(CGImageGetWidth(image), CGImageGetHeight(image))];
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
                self.imageView.image = [self createExposureImage];
            }
        }
    }];
}

- (void)setSegmenting:(BOOL)segmenting
{
    _segmenting = segmenting;

    if (_segmenting){
        [self.spinner startAnimation:nil];
    }
    else {
        [self.spinner stopAnimation:nil];
    }
}

- (IBAction)segment:(id)sender {

    if (!self.exposure || self.segmenting){
        return;
    }
    
    self.segmenting = YES;
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        
        NSDictionary* dataD = [NSDictionary dictionaryWithObjectsAndKeys: self.exposure, keyExposure,
                               [NSNumber numberWithInteger: self.thresholdingMode], keyThresholdingMode,
                               [NSNumber numberWithUnsignedShort: self.customThreshold], keyThreshold,
                               [NSNumber numberWithInteger: self.maxNumRegions], keyMaxNumRegions,
                               [NSNumber numberWithInteger: self.minNumPixelsInRegion], keyMinNumPixelsInRegion,
                               nil];
        
        CASAlgorithm* alg = [[CASRegionGrowerSegmenter alloc] init];
        [alg executeWithDictionary: dataD
                   completionAsync: NO
                   completionQueue: dispatch_get_current_queue()
                   completionBlock: ^(NSDictionary* resultsD) {
                       
                       self.segmenting = NO;
                       
                       NSLog(@"%@ :: resultsD:\r%@", [alg class], resultsD);
                       
                       NSImage* image = [self createExposureImage];
                       NSImage* annotatedImage = [[NSImage alloc] initWithSize:image.size];
                       [annotatedImage lockFocus];
                       [[self createExposureImage] drawAtPoint:NSZeroPoint fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:1];
                       [[NSColor yellowColor] set];
                       for (CASRegion* region in [resultsD objectForKey:@"regions"]){
                           const CASRect frame = region.frame;
                           NSFrameRect(NSMakeRect(frame.origin.x, frame.origin.y, frame.size.width, frame.size.height));
                       }
                       [annotatedImage unlockFocus];
                       self.imageView.image = annotatedImage;
                   }];
    });
}

@end

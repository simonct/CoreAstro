//
//  SXIOFocuserWindowController.m
//  SX IO
//
//  Created by Simon Taylor on 5/31/15.
//  Copyright (c) 2015 Simon Taylor. All rights reserved.
//

#import "SXIOFocuserWindowController.h"
#import "SXIOAppDelegate.h"
#import "CASSimpleGraphView.h"
#import <Accelerate/Accelerate.h>

@interface MyImageView : NSImageView
@property (nonatomic) CGFloat yLine;
@property (nonatomic) CALayer* line;
@end

@implementation MyImageView

- (void)setYLine:(CGFloat)yLine
{
    if (self.line){
        [self.line removeFromSuperlayer];
    }
    self.line = [CALayer layer];
    self.line.frame = CGRectMake(0, yLine, self.bounds.size.width, 1);
    self.line.backgroundColor = [NSColor yellowColor].CGColor;
    [self.layer addSublayer:self.line];
}

@end

@interface SXIOFocuserWindowController ()
@property (weak) IBOutlet MyImageView *imageView;
@property (weak) IBOutlet NSTextField *metricLabel;
@property (weak) IBOutlet CASSimpleGraphView *graphView;
@property (strong) id<CASFocuser> focuser;
@end

@implementation SXIOFocuserWindowController {
    NSInteger _i;
    id<CASCameraControllerSink> _savedSink;
}

- (void)windowDidLoad
{
    [super windowDidLoad];
    
#if defined(SXIO)
    [[SXIOAppDelegate sharedInstance] addWindowToWindowMenu:self];
#endif

    NSButton* close = [self.window standardWindowButton:NSWindowCloseButton];
    [close setTarget:self];
    [close setAction:@selector(closeWindow:)];

    _i = 1;
    
//    [self showTestExposure];
}

- (void)showTestExposure
{
    if (_i > 5){
        _i = 1;
    }
    NSString* path = [[NSString stringWithFormat:@"~/Desktop/Star Images/focus%ld.fits",(long)_i] stringByExpandingTildeInPath];
    CASCCDExposure* exposure = [CASCCDExposure new];
    CASCCDExposureIO* io = [CASCCDExposureIO exposureIOWithPath:path];
    NSError* error;
    [io readExposure:exposure readPixels:YES error:&error];
    [self assessExposure:exposure];
    self.imageView.image = [[NSImage alloc] initWithCGImage:[exposure newImage].CGImage size:NSZeroSize];
    ++_i;
    [self performSelector:_cmd withObject:nil afterDelay:1];
}

- (void)dealloc
{
    [self stopCapturing];
}

- (void)closeWindow:sender
{
#if defined(SXIO)
    [[SXIOAppDelegate sharedInstance] removeWindowFromWindowMenu:self];
#endif
    
    if (!self.cameraController.sink){
        self.cameraController.sink = _savedSink;
    }
    
    self.cameraController = nil;

    [self close];
}

- (void)setCameraController:(CASCameraController *)cameraController
{
    if (cameraController != _cameraController){
        _cameraController = cameraController;
        if (!_cameraController){
            [self stopCapturing];
        }
        else {
            [self startCapturing];
        }
    }
}

- (void)stopCapturing
{
    [self.cameraController cancelCapture];
    [NSObject cancelPreviousPerformRequestsWithTarget:self];
}

- (void)startCapturing
{
    [self.cameraController cancelCapture];

    // turn off the controller's sink (this is only to stop it getting saved to file)
    _savedSink = self.cameraController.sink;
    self.cameraController.sink = nil;
    
    // grab an exposure
    [self.cameraController captureWithBlock:^(NSError* error, CASCCDExposure* exposure) {
        
        self.cameraController.sink = _savedSink;

        if (error){
            // report
        }
        else if (!self.cameraController.cancelled) {
            
            // display image
            self.imageView.image = [[NSImage alloc] initWithCGImage:[exposure newImage].CGImage size:NSZeroSize];
            
            // calc and display metric
            [self assessExposure:exposure];
            
            // inform delegate
            
            // repeat
            [self performSelector:_cmd withObject:nil afterDelay:1];
        }
    }];
}

- (NSInteger)_lineWithMaxValue:(CASCCDExposure*)exposure
{
    float maxSum = 0;
    NSInteger maxY = NSNotFound;
    
    float* floatPixels = (float*)[exposure.floatPixels bytes];
    if (floatPixels){
        
        const CASSize size = exposure.actualSize;
        
        for (NSInteger y = 0; y < size.height; ++y){
            
            float sum = 0;
            vDSP_sve(floatPixels,1,&sum,size.width);
            if (sum > maxSum && sum < size.width/4){
                maxSum = sum;
                maxY = y;
            }
            floatPixels += size.width;
        }
    }
    
    return maxY;
}

- (void)assessExposure:(CASCCDExposure*)exposure
{
    // grab the row of pixels closest to the y posn of the star
    float* pixels = (float*)[[exposure floatPixels] bytes];
    NSMutableData* pixelData = [NSMutableData dataWithLength:exposure.actualSize.width * sizeof(float)];
    if (pixelData){
        
        const NSInteger yLine = [self _lineWithMaxValue:exposure];
        if (yLine == NSNotFound){
            self.metricLabel.stringValue = @"No star";
            self.graphView.samples = nil;
        }
        else {
            
            const float scale = self.imageView.bounds.size.height/exposure.actualSize.height;
            self.imageView.yLine = self.imageView.bounds.size.height - (yLine * scale);
            
            pixels = pixels + (exposure.actualSize.width * yLine);
            memcpy([pixelData mutableBytes], pixels, exposure.actualSize.width * sizeof(float));
            self.graphView.samples = pixelData;
            self.graphView.showLimits = YES;
            
            float maxValue = 0;
            float left = -1, right = -1;
            {
                float* floatPixels = (float*)[exposure.floatPixels bytes];
                if (floatPixels){
                    
                    floatPixels += (exposure.actualSize.width * yLine);
                    
                    const CASSize size = exposure.actualSize;
                    vDSP_maxmgv(floatPixels,1,&maxValue,size.width);
                    
                    // if max == 1, adjust exposure to get < 1 (hot pixels?)
                    
                    const float halfMax = maxValue/2.0;
                    for (int i = 0; i < exposure.actualSize.width; ++i){
                        if (floatPixels[i] >= halfMax && left == -1){
                            const float slope = (floatPixels[i+1] - floatPixels[i]);
                            left = i + (slope * (halfMax - floatPixels[i]));
                        }
                        if (left != -1 && right == -1 && pixels[i] <= halfMax && i > 0){
                            const float slope = (floatPixels[i] - floatPixels[i-1]);
                            right = i + (slope * (halfMax - floatPixels[i]));
                        }
                    }
                }
            }
            
            NSLog(@"left %f, right: %f",left,right);
            if (left != -1 && right != -1){
                const float fwhm = right - left;
                self.metricLabel.stringValue = [NSString stringWithFormat:@"FWHM %0.1f",fwhm];
            }
            else {
                self.metricLabel.stringValue = @"No FWHM";
            }
        }
    }
}

@end

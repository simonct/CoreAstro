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

@interface SXIOFocuserWindowController ()
@property (weak) IBOutlet NSImageView *imageView;
@property (weak) IBOutlet NSTextField *metricLabel;
@property (weak) IBOutlet CASSimpleGraphView *graphView;
@property (strong) id<CASFocuser> focuser;
//@property (strong) CASGuideAlgorithm* guideAlgorithm;
@end

@implementation SXIOFocuserWindowController

- (void)windowDidLoad
{
    [super windowDidLoad];
    
#if defined(SXIO)
    [[SXIOAppDelegate sharedInstance] addWindowToWindowMenu:self];
#endif

    NSButton* close = [self.window standardWindowButton:NSWindowCloseButton];
    [close setTarget:self];
    [close setAction:@selector(closeWindow:)];
    
//    self.guideAlgorithm = [CASGuideAlgorithm guideAlgorithmWithIdentifier:nil];
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
    id<CASCameraControllerSink> savedSink = self.cameraController.sink;
    self.cameraController.sink = nil;
    
    // grab an exposure
    [self.cameraController captureWithBlock:^(NSError* error, CASCCDExposure* exposure) {
        
        self.cameraController.sink = savedSink;

        if (error){
            // report
        }
        else if (!self.cameraController.cancelled) {
            
            // display image
            self.imageView.image = [[NSImage alloc] initWithCGImage:[exposure newImage].CGImage size:NSZeroSize];
            
            // calc and display metric
//            NSValue* pointValue = [self.guideAlgorithm locateStars:exposure].firstObject;
//            if (pointValue){
//                const NSPoint point = [pointValue pointValue];
//                self.metricLabel.stringValue = NSStringFromPoint(point);
//            }
//            else {
//                self.metricLabel.stringValue = @"No star";
//            }
            [self assessExposure:exposure];
            
            // inform delegate
            
            // repeat
            [self performSelector:_cmd withObject:nil afterDelay:1];
        }
    }];
}

- (NSInteger)_lineWithMaxValue:(CASCCDExposure*)exposure
{
    NSInteger maxY = NSNotFound;
    
    float* floatPixels = (float*)[exposure.floatPixels bytes];
    if (floatPixels){
        
        const CASSize size = exposure.actualSize;
        
        float max = 0;
        for (NSInteger y = 0; y < size.height; ++y){
            
            float m = 0;
            vDSP_maxmgv(floatPixels,1,&m,size.width);
            if (m > max){
                max = m;
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
        
        // find the max line (could just search around height/2)
        const NSInteger y = [self _lineWithMaxValue:exposure];
        if (y == NSNotFound){
            self.metricLabel.stringValue = @"No star";
            self.graphView.samples = nil;
        }
        else{
            self.metricLabel.stringValue = [NSString stringWithFormat:@"Line %ld",(long)y];
            pixels = pixels + exposure.actualSize.width * y;
            memcpy([pixelData mutableBytes], pixels, exposure.actualSize.width * sizeof(float));
            self.graphView.samples = pixelData;
            self.graphView.showLimits = YES;
        }
    }
}

@end

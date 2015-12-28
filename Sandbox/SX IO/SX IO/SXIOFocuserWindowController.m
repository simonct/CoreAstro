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

@interface CASSimpleXYGraphView : CASSimpleGraphView
@property CGFloat maxX;
// centre x offset
@end

@implementation CASSimpleXYGraphView

- (void)drawSamples:(NSData*)samples
{
    CGPoint* points = (CGPoint*)[self.samples bytes];
    const NSInteger count = [self.samples length]/sizeof(CGPoint);
    if (count > 0 && self.max != 0 && self.maxX != 0){
        
        for (NSInteger i = 0; i < count; ++i){
            
            const CGPoint sample = points[i];
            const CGFloat width = self.bounds.size.width;
            const CGFloat height = self.bounds.size.height;
            const NSPoint p = NSMakePoint(width*sample.x/self.maxX, height*sample.y/self.max);

            NSBezierPath* path = [NSBezierPath bezierPathWithOvalInRect:NSMakeRect(p.x-3, p.y-3, 6, 6)];
            [[NSColor orangeColor] set];
            [path setLineWidth:1];
            [path stroke];
        }
    }
}

@end

@interface Measurement : NSObject
@property NSTimeInterval time;
@property float fwhm;
@property float position;
@end

@implementation Measurement
@end

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
@property (strong) NSMutableArray* measurements;
@property (weak) IBOutlet CASSimpleXYGraphView *plotView;
@end

@implementation SXIOFocuserWindowController {
    NSInteger _i;
    float _position;
    NSTimeInterval _duration;
    CASFocuserDirection _direction;
    BOOL _goneThroughFocusPoint;
    id<CASCameraControllerSink> _savedSink;
}

- (void)windowDidLoad
{
    [super windowDidLoad];
    
#if defined(SXIO) || defined(CCDIO)
    [[SXIOAppDelegate sharedInstance] addWindowToWindowMenu:self];
#endif

    NSButton* close = [self.window standardWindowButton:NSWindowCloseButton];
    [close setTarget:self];
    [close setAction:@selector(closeWindow:)];

    _i = 1;

    _duration = 0.1;
    _direction = CASFocuserForward;
    _goneThroughFocusPoint = NO;

    NSPredicate* predicate = [NSPredicate predicateWithBlock:^BOOL(id evaluatedObject, NSDictionary *bindings) {
        return [evaluatedObject conformsToProtocol:@protocol(CASFocuser)];
    }];
    NSArray* focusers = [[[CASDeviceManager sharedManager] devices] filteredArrayUsingPredicate:predicate];
    self.focuser = focusers.firstObject;
    
    [self startCapturing];

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
#if defined(SXIO) || defined(CCDIO)
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
//            [self startCapturing];
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
    __block BOOL done = NO;
    
    [self.cameraController cancelCapture];
    
    // turn off the controller's sink (this is only to stop it getting saved to file)
    _savedSink = self.cameraController.sink;
    self.cameraController.sink = nil;
    
    // grab an exposure
    [self.cameraController captureWithBlock:^(NSError* error, CASCCDExposure* exposure) {
        
        //    NSString* path = [[NSString stringWithFormat:@"~/Desktop/Star Images/focus%ld.fits",(long)_i++] stringByExpandingTildeInPath];
        //    CASCCDExposure* exposure = [CASCCDExposure new];
        //    CASCCDExposureIO* io = [CASCCDExposureIO exposureIOWithPath:path];
        //    NSError* error;
        //    [io readExposure:exposure readPixels:YES error:&error];
        
        self.cameraController.sink = _savedSink;
        
        if (error){
            // report
        }
        else if (/*!self.cameraController.cancelled*/1) {
            
            // display image
            self.imageView.image = [[NSImage alloc] initWithCGImage:[exposure newImage].CGImage size:NSZeroSize];
            
            // calc and display metric
            const float fwhm = [self assessExposure:exposure];
            if (fwhm == 0){
                NSLog(@"No fwhm, skipping this one");
            }
            else {
                
                // log the measurement
                Measurement* m = [Measurement new];
                m.time = [NSDate timeIntervalSinceReferenceDate];
                m.fwhm = fwhm;
                m.position = _position; // from focuser if stepper
                if (!self.measurements){
                    self.measurements = [NSMutableArray arrayWithCapacity:20];
                }
                [self.measurements addObject:m];
                
                // if we've got multiple measurements we can compare them
                if (self.measurements.count > 1) {
                    
                    // detect minimum
                    
                    NSArray* sortedByFWHM = [self.measurements sortedArrayUsingComparator:^(Measurement* obj1, Measurement* obj2) {
                        return [@(obj1.fwhm) compare:@(obj2.fwhm)];
                    }];
                    
                    Measurement* minFWHM = sortedByFWHM.firstObject;
                    if (minFWHM == self.measurements.firstObject || minFWHM == self.measurements.lastObject){
                        // minimum is one of the end ones so we haven't hit the focus point and gone out the other side yet so keep going
                        NSLog(@"Min FWHM is at one end of the measurements array, looks like we haven't gone through focus yet");
                    }
                    else {
                        
                        NSArray* sortedByPosition = [self.measurements sortedArrayUsingComparator:^(Measurement* obj1, Measurement* obj2) {
                            return [@(obj1.position) compare:@(obj2.position)];
                        }];
                        
                        self.plotView.max = ((Measurement*)sortedByFWHM.lastObject).fwhm;
                        self.plotView.maxX = 1; // ((Measurement*)sortedByPosition.lastObject).position - ((Measurement*)sortedByPosition.firstObject).position;
                        
                        CGPoint samples[self.measurements.count];
                        for (NSInteger i = 0; i < self.measurements.count; ++i){
                            Measurement* m = (Measurement*)sortedByPosition[i];
                            samples[i].x = m.position;
                            samples[i].y = m.fwhm;
                        }
                        self.plotView.samples = [NSData dataWithBytes:samples length:sizeof(samples)];
                        
                        // looks like the min fwhm is in the middle of the measurements, calc line fit of the two halves, this should give us
                        // an approx focus min and we can stop when we get within some tolerance of that
                        NSLog(@"Looks like we might have gone through focus");
                        _goneThroughFocusPoint = YES;
                    }
                    
                    const float firstFWHM = [(Measurement*)self.measurements.firstObject fwhm];
                    const float lastFWHM =  [(Measurement*)self.measurements[self.measurements.count-2] fwhm]; // last but one measurement
                    if (fwhm < lastFWHM){
                        NSLog(@"FWHM getting smaller, keep going");
                    }
                    else if (fwhm > lastFWHM) {
                        
                        if (fwhm < firstFWHM && _goneThroughFocusPoint){
                            NSLog(@"Heading past focus point to initial FWHM");
                        }
                        else {
                            if (_goneThroughFocusPoint){
                                NSLog(@"done ?");
                                done = YES;
                            }
                            else {
                                _direction = !_direction;
                                _goneThroughFocusPoint = NO;
                                NSLog(@"FWHM getting larger, reversing direction");
                            }
                        }
                    }
                    else {
                        
                        _duration *= 2;
                        NSLog(@"FWHM the same, doubling duration");
                    }
                }
                
                if (!done){
                    
                    // pulse focuser
                    NSLog(@"Pulsing focuser for %.2f in %lu direction",_duration,(unsigned long)_direction);
                    [self.focuser pulse:_direction duration:_duration block:^(NSError* error) {
                        if (error){
                            NSLog(@"Pulse failed %@",error);
                            // call delegate, stop
                        }
                        else {
                            
                            NSLog(@"Focus pulse complete");
                            
                            if (_direction == CASFocuserForward){
                                _position += _duration;
                            }
                            else {
                                _position -= _duration;
                            }
                            // inform delegate
                            
                            // capture another frame
                            [self performSelector:_cmd withObject:nil afterDelay:0.5]; // average out n frames ?
                        }
                    }];
                }
            }
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

- (float)assessExposure:(CASCCDExposure*)exposure
{
    float fwhm = 0;
    
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
                fwhm = right - left;
                self.metricLabel.stringValue = [NSString stringWithFormat:@"FWHM %0.1f",fwhm];
            }
            else {
                self.metricLabel.stringValue = @"No FWHM";
            }
        }
    }
    
    return fwhm;
}

@end

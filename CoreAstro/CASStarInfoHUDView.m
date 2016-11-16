//
//  CASStarInfoHUDView.m
//  CoreAstro
//
//  Created by Simon Taylor on 12/18/12.
//  Copyright (c) 2012 Mako Technology Ltd. All rights reserved.
//

#import "CASStarInfoHUDView.h"
#import "CASSimpleGraphView.h"
#import "CASExposureView.h" // for kCASImageViewInvalidStarLocation
#import <CoreAstro/CoreAstro.h>
#import <Accelerate/Accelerate.h>

@interface CASStarInfoHUDView ()
@property (weak) IBOutlet CASSimpleGraphView *graphView;
@property (weak) IBOutlet NSTextField *coordsLabel;
@end

@implementation CASStarInfoHUDView

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

- (void)setExposure:(CASCCDExposure*)exposure starPosition:(NSPoint)position
{
    void (^nostar)() = ^(){
        self.graphView.samples = nil;
        self.coordsLabel.stringValue = @"No Star";
    };
    
    if (!exposure){
        self.graphView.samples = nil;
        self.coordsLabel.stringValue = @"";
    }
    else{
        
        if (CGPointEqualToPoint(kCASImageViewInvalidStarLocation, position)){
            nostar();
        }
        else {
            
            // assuming exposure is full frame and that position is in global co-ordinates
            self.coordsLabel.stringValue = [NSString stringWithFormat:@"%.1fx%.1f",position.x,position.y];

            const NSInteger width = 100 * exposure.params.bin.width;
            const NSInteger height = 100 * exposure.params.bin.height;
            const NSInteger xpos = roundf(position.x * exposure.params.bin.width);
            const NSInteger ypos = roundf(position.y * exposure.params.bin.height);
            
            // grab a subframe around the star point; we'll scan downwards and find the row with the brightest pixel and assume that's the
            // star's centre
            CASCCDExposure* subframe = [exposure subframeWithRect:CASRectMake(CASPointMake(xpos - width/2, ypos - height/2), CASSizeMake(width, height))];
            if (!subframe){
                nostar();
            }
            else{
            
                // grab the row of pixels closest to the y posn of the star
                float* pixels = (float*)[[subframe floatPixels] bytes];
                NSMutableData* pixelData = [NSMutableData dataWithLength:subframe.actualSize.width * sizeof(float)];
                if (pixelData){
                    
                    // find the max line (could just search around height/2)
                    const NSInteger y = [self _lineWithMaxValue:subframe];
                    if (y == NSNotFound){
                        nostar();
                    }
                    else{
                        pixels = pixels + subframe.actualSize.width * y;
                        memcpy([pixelData mutableBytes], pixels, subframe.actualSize.width * sizeof(float));
                        self.graphView.samples = @[pixelData];
                        self.graphView.showLimits = YES;
                        
                        // hfd
#if 0
                        CASImageMetrics* metrics = [CASImageMetrics imageMetricsWithIdentifier:nil];
                        if (metrics){
                            
                            __block double fastHFD, accurateHFD;
                            __block CGPoint fastCentre, accurateCentre;
                            
                            const NSTimeInterval fastTime = CASTimeBlock(^{
                                fastHFD = [metrics hfdForExposure:subframe centroid:&fastCentre mode:CASImageMetricsHFDModeFast];
                            });
                            NSLog(@"fastHFD: %f@%@ in %fs",fastHFD,NSStringFromCGPoint(fastCentre),fastTime);
                            
                            const NSTimeInterval accurateTime = CASTimeBlock(^{
                                accurateHFD = [metrics hfdForExposure:subframe centroid:&accurateCentre mode:CASImageMetricsHFDModeAccurate];
                            });
                            NSLog(@"accurateHFD: %f@%@ in %fs",accurateHFD,NSStringFromCGPoint(accurateCentre),accurateTime);
                            
                            self.coordsLabel.stringValue = [NSString stringWithFormat:@"%f / %f",fastHFD,accurateHFD];
                        }
#endif
                    }
                }
            }
        }
    }
}

@end

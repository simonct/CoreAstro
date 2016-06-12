//
//  CADHistogramHUDView.m
//  CoreAstro
//
//  Created by Simon Taylor on 12/18/12.
//  Copyright (c) 2012 Mako Technology Ltd. All rights reserved.
//

#import "CASHistogramHUDView.h"
#import "CASSimpleGraphView.h"
#import <CoreAstro/CoreAstro.h>

@interface CASHistogramHUDView ()
@property (nonatomic,strong) IBOutlet CASSimpleGraphView* graphView;
@end

@implementation CASHistogramHUDView

- (id)initWithFrame:(NSRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        NSLog(@"");
    }
    return self;
}

- (void)setExposure:(CASCCDExposure *)exposure
{
    if (exposure != _exposure){
        
        _exposure = exposure;
        if (_exposure){
            
            if (_exposure.rgba) {
                __block CGFloat max = -1;
                NSArray* histograms = [self.imageProcessor rgbHistogram:_exposure];
                NSMutableArray* samplesArray = [NSMutableArray arrayWithCapacity:histograms.count];
                [histograms enumerateObjectsUsingBlock:^(NSArray* histogram, NSUInteger idx, BOOL * _Nonnull stop) {
                    NSMutableData* data = [NSMutableData dataWithLength:[histogram count] * sizeof(float)];
                    float* fp = (float*)[data mutableBytes];
                    for (NSNumber* n in histogram){
                        const float f = [n floatValue];
                        max = MAX(max,f);
                        *fp++ = f;
                    }
                    [samplesArray addObject:data];
                }];
                self.graphView.max = max;
                self.graphView.colours = @[[NSColor redColor],[NSColor greenColor],[NSColor blueColor]];
                self.graphView.samples = [samplesArray copy];
            }
            else {
                CGFloat max = 0;
                NSArray* histogram = [self.imageProcessor histogram:_exposure];
                NSMutableData* data = [NSMutableData dataWithLength:[histogram count] * sizeof(float)];
                float* fp = (float*)[data mutableBytes];
                for (NSNumber* n in histogram){
                    const float f = [n floatValue];
                    max = MAX(max,f);
                    *fp++ = f;
                }
                self.graphView.max = max;
                self.graphView.colours = nil;
                self.graphView.samples = @[data];
            }
        }
        else {
            self.graphView.samples = nil;
        }
    }
}

@end

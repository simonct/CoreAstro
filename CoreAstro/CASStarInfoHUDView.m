//
//  CASStarInfoHUDView.m
//  CoreAstro
//
//  Created by Simon Taylor on 12/18/12.
//  Copyright (c) 2012 Mako Technology Ltd. All rights reserved.
//

#import "CASStarInfoHUDView.h"
#import "CASCCDExposure.h"
#import "CASSimpleGraphView.h"

@interface CASStarInfoHUDView ()
@property (weak) IBOutlet CASSimpleGraphView *graphView;
@property (weak) IBOutlet NSTextField *coordsLabel;
@end

@implementation CASStarInfoHUDView

- (void)setExposure:(CASCCDExposure*)exposure starPosition:(NSPoint)position
{
    self.coordsLabel.stringValue = [NSString stringWithFormat:@"%.1fx%.1f",position.x,position.y];
    
    if (exposure){
        
        const NSInteger width = 100;
        const NSInteger height = 10;
        const NSInteger xpos = roundf(position.x);
        const NSInteger ypos = roundf(position.y);
        
        // grab a subframe around the star point
        CASCCDExposure* subframe = [exposure subframeWithRect:CASRectMake(CASPointMake(xpos - width/2, ypos - height/2), CASSizeMake(width, height))];
        if (subframe){
            
            // grab the line of pixels closest to the y posn of the star (round)
            float* pixels = (float*)[[subframe floatPixels] bytes];
            NSMutableData* pixelData = [NSMutableData dataWithLength:width * sizeof(float)];
            if (pixelData){
                
                pixels = pixels + width * height/2;
                memcpy([pixelData mutableBytes], pixels, width * sizeof(float));
                self.graphView.samples = pixelData;
            }
        }
    }
}

@end

//
//  main.m
//  hfd-debug
//
//  Created by Simon Taylor on 7/13/14.
//  Copyright (c) 2014 Simon Taylor. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreAstro/CoreAstro.h>

int main(int argc, const char * argv[])
{
    if (argc < 2){
        return 1;
    }
    @autoreleasepool {
        
        CASCCDExposureIO* io = [CASCCDExposureIO exposureIOWithPath:[NSString stringWithUTF8String:argv[1]]];
        CASCCDExposure* exp = [CASCCDExposure new];
        NSError* error;
        [io readExposure:exp readPixels:YES error:&error];
        if (error){
            NSLog(@"%@",error);
        }
        else {
            
            CASImageMetrics* metrics = [CASImageMetrics imageMetricsWithIdentifier:nil];
            
            double accurateHFD;
            CGPoint accurateCentre;
            
            accurateHFD = [metrics hfdForExposure:exp centroid:&accurateCentre mode:CASImageMetricsHFDModeAccurate];
            
            NSLog(@"accurateHFD: %f, accurateCentre.x: %f, accurateCentre.y: %f",accurateHFD,accurateCentre.x,accurateCentre.y);
        }
    }
    return 0;
}


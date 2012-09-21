//
//  main.m
//  CoreAstroCustomSegmentationAlg
//
//  Created by Wagner Truppel on 21/09/2012.
//  Copyright (c) 2012 Wagner Truppel. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "CASCCDParams.h"
#import "CASCCDExposure.h"

#import "CASCustomAutoGuider.h"


int main(int argc, const char * argv[])
{

    @autoreleasepool {

        // WLT-QQQ: How do I get an exposure from a pre-existing file?
        // WLT-QQQ: How do I keep the command line tool running until the alg has finished processing the image?

        CASExposeParams params;
        CASCCDExposure* exposure = [CASCCDExposure exposureWithPixels: nil camera: nil params: params time: nil];
        
        CASAutoGuider* guider = [CASCustomAutoGuider autoGuiderWithIdentifier: @"CustomSegmAlg"];
        [guider locateStars: exposure]; // ignoring the result because the implementation of
                                        // -locateStars will return nil immediately and run
                                        // itself in a background thread.

    }

    return 0;
}


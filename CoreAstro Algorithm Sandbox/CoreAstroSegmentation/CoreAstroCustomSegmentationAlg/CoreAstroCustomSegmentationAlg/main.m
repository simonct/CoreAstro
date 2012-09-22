//
//  main.m
//  CoreAstroCustomSegmentationAlg
//
//  Created by Wagner Truppel on 21/09/2012.
//  Copyright (c) 2012 Wagner Truppel. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "CASCCDExposure.h"
#import "CASCCDExposureIO.h"

#import "CASCustomAutoGuider.h"


int main(int argc, const char * argv[])
{
    @autoreleasepool {

        // WLT-QQQ: How do I keep the command line tool running until the alg has finished processing the image?

        if (argc != 2)
        {
            NSLog(@"This command line tool requires a single argument, a path to an exposure.");
            return -1;
        }
        NSString* path = [NSString stringWithCString: argv[1] encoding: NSASCIIStringEncoding];
        NSLog(@"Loading exposure at path:\r'%@'", path);

        CASCCDExposureIO* expIO = [CASCCDExposureIO exposureIOWithPath: path];
        NSError* error = nil;

        CASCCDExposure* exposure = [[CASCCDExposure alloc] init];
        BOOL readSuccess = [expIO readExposure: exposure readPixels: YES error: &error];

        if (!readSuccess || error)
        {
            NSLog(@"Unable to load exposure at path:\n'%@'", path);
            return -1;
        }

        CASAutoGuider* guider = [CASCustomAutoGuider autoGuiderWithIdentifier: @"CustomSegmAlg"];
        [guider locateStars: exposure]; // ignoring the result because the implementation of
                                        // -locateStars will return nil immediately and run
                                        // itself in a background thread.
    }

    return 0;
}

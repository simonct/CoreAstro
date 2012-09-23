//
//  main.m
//  CoreAstroCustomSegmentationAlg
//
//  Copyright (c) 2012, Wagner Truppel
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is furnished
//  to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
//  THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
//  FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
//  IN THE SOFTWARE.
//


#import <Foundation/Foundation.h>

#import "CASCCDExposure.h"
#import "CASCCDExposureIO.h"

#import "CASCustomAutoGuider.h"


int main(int argc, const char * argv[])
{
    @autoreleasepool {

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
            NSLog(@"Unable to load exposure at path:\r'%@'", path);
            NSLog(@"Error: %@", error);
            return -1;
        }

        CASAutoGuider* guider = [CASCustomAutoGuider autoGuiderWithIdentifier: nil];
        NSArray* stars = [guider locateStars: exposure];

        NSLog(@"   exposure:\r%@", exposure);
        NSLog(@"%@ :: stars:\r%@", [guider class], stars);
    }

    return 0;
}

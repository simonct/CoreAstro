//
//  main.m
//  CASFocuser
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
// #import "CASFocuser.h"
#import "CASHalfFluxDiameter.h"


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

        NSDictionary* dataD = [NSDictionary dictionaryWithObjectsAndKeys: exposure, keyExposure,
                               [NSNumber numberWithDouble: 4.539062], keyPixelW,
                               [NSNumber numberWithDouble: 4.539062], keyPixelH,
                               nil];

//        CASAlgorithm* alg = [[CASFocuser alloc] init];
//        [alg executeWithDictionary: dataD
//                   completionAsync: NO
//                   completionQueue: dispatch_get_current_queue()
//                   completionBlock: ^(NSDictionary* resultsD) {
//
//                       NSLog(@"%@ :: resultsD:\r%@", [alg class], resultsD);
//                       
//                   }];

        NSLog(@"----------------------------------------------------------");

        CASAlgorithm* alg = [[CASHalfFluxDiameter alloc] init];
        [alg executeWithDictionary: dataD
                   completionAsync: NO
                   completionQueue: dispatch_get_current_queue()
                   completionBlock: ^(NSDictionary* resultsD) {

                       NSLog(@"%@ :: resultsD:\r%@", [alg class], resultsD);
                       
                   }];

        NSLog(@"----------------------------------------------------------");

        CASHalfFluxDiameter* hfdAlg = (CASHalfFluxDiameter*) alg;
        NSUInteger numRows = exposure.actualSize.height;
        NSUInteger numCols = exposure.actualSize.width;
        NSUInteger numPixels = numRows * numCols;

        CGPoint centroid = CGPointZero;
        double roughHFD = [hfdAlg roughHfdForExposureArray: (uint16_t*) [exposure.pixels bytes]
                                                  ofLength: numPixels
                                                   numRows: numRows
                                                   numCols: numCols
                                                    pixelW: 4.539062
                                                    pixelH: 4.539062
                                        brightnessCentroid: &centroid];

        NSLog(@"roughHFD (spiral) = %f", roughHFD);

        NSLog(@"----------------------------------------------------------");
        
        NSDictionary* resD = [hfdAlg gaussianExposureWithDecayRate: 1.0e-3
                                                     angularFactor: 0.0
                                                        centeredAt: CGPointMake(200.0, 200.0)
                                                           numRows: 100
                                                           numCols: 100
                                                            pixelW: 4.0
                                                            pixelH: 4.0];
        NSLog(@"gaussian test exposure: %@", resD);
    }

    return 0;
}

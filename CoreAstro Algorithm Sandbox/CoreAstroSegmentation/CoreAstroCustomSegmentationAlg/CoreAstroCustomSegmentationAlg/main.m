//
//  main.m
//  CoreAstroCustomSegmentationAlg
//
//  Created by Wagner Truppel on 21/09/2012.
//  Copyright (c) 2012 Wagner Truppel. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "CASCustomSegmentationAlg.h"

int main(int argc, const char * argv[])
{

    @autoreleasepool {

        CASAlgorithm* alg = [[CASCustomSegmentationAlg alloc] init];
        [alg executeWithDictionary: nil completionBlock: nil]; // WLT-XXX
        
    }
    return 0;
}


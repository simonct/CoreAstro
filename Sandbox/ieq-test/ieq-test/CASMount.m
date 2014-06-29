//
//  CASMount.m
//  ieq-test
//
//  Created by Simon Taylor on 1/26/14.
//  Copyright (c) 2014 Simon Taylor. All rights reserved.
//

#import "CASMount.h"

@implementation CASMount

- (BOOL) connected {
    return NO;
}

- (BOOL) slewing {
    return NO;
}

- (CASMountMode) mode {
    return CASMountModeEQ;
}

- (NSNumber*) ra {
    return nil;
}

- (NSNumber*) dec {
    return nil;
}

- (NSNumber*) alt{
    return nil;
}

- (NSNumber*) az {
    return nil;
}

- (void)startSlewToRA:(double)ra dec:(double)dec completion:(void (^)(CASMountSlewError))completion {
    NSAssert(NO, @"Not implemented");
}

- (void)halt {
    NSAssert(NO, @"Not implemented");
}

- (void)syncToRA:(double)ra dec:(double)dec completion:(void (^)(CASMountSlewError))completion {
    NSAssert(NO, @"Not implemented");
}

@end

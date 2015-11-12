//
//  CASMount.m
//  ieq-test
//
//  Created by Simon Taylor on 1/26/14.
//  Copyright (c) 2014 Simon Taylor. All rights reserved.
//

#import "CASMount.h"
#import "CASNova.h"

NSString* const CASMountSlewingNotification = @"CASMountSlewingNotification";
NSString* const CASMountFlippedNotification = @"CASMountFlippedNotification";

@interface CASMount ()
@property (strong) CASNova* nova;
@end

@implementation CASMount

- (void)connectWithCompletion:(void(^)(NSError*))completion {
    if (completion){
        completion([NSError errorWithDomain:@"CASMount" code:1 userInfo:@{NSLocalizedDescriptionKey:@"Not implemented"}]);
    }
}

- (void)disconnect {
    
}

- (BOOL) connected {
    return NO;
}

- (BOOL) slewing {
    return NO;
}

- (BOOL) tracking {
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

- (NSNumber*) targetRa {
    return nil;
}

- (NSNumber*) targetDec {
    return nil;
}

- (NSNumber*) alt{
    return nil;
}

- (NSNumber*) az {
    return nil;
}

- (NSArray<NSString*>*)movingRateValues {
    return nil;
}

- (NSNumber*) secondsUntilTransit {
    
    NSNumber* result;
    
    NSNumber* ra = self.ra;
    NSNumber* dec = self.dec;    
    if (ra && dec){
        
        if (!self.nova){
            NSNumber* latitude = [[NSUserDefaults standardUserDefaults] objectForKey:@"SXIOSiteLatitude"]; // todo; using SXIO namespace defaults...
            NSNumber* longitude = [[NSUserDefaults standardUserDefaults] objectForKey:@"SXIOSiteLongitude"];
            if (latitude && longitude){
                self.nova = [[CASNova alloc] initWithObserverLatitude:latitude.doubleValue longitude:longitude.doubleValue];
            }
        }
        
        if (self.nova){
            const CASRST rst = [self.nova rstForObjectRA:ra.doubleValue dec:dec.doubleValue jd:[CASNova today]];
            if (rst.visibility == 0){
                const double diffJD = rst.transit - [CASNova now];
                const double diffSeconds = diffJD * 86400;
                result = @(diffSeconds);
            }
        }
    }

    return result;
}

+ (NSSet*)keyPathsForValuesAffectingSecondsUntilTransit {
    return [NSSet setWithArray:@[@"ra",@"dec"]];
}

- (void)startSlewToRA:(double)ra dec:(double)dec completion:(void (^)(CASMountSlewError))completion {
    NSAssert(NO, @"Not implemented");
}

- (void)park {
    NSAssert(NO, @"Not implemented");
}

- (void)unpark {
    NSAssert(NO, @"Not implemented");
}

- (void)gotoHomePosition {
    NSAssert(NO, @"Not implemented");
}

- (CASMountPierSide) pierSide {
    return 0;
}

- (void)halt {
    NSAssert(NO, @"Not implemented");
}

- (void)syncToRA:(double)ra dec:(double)dec completion:(void (^)(CASMountSlewError))completion {
    NSAssert(NO, @"Not implemented");
}

@end

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
@property (strong,nonatomic) CASNova* nova;
@end

@implementation CASMount {
    NSInteger _mountID;
}

static NSInteger gMountID = 0;

- (instancetype)init
{
    self = [super init];
    if (self) {
        _mountID = gMountID++;
    }
    return self;
}

- (void)connect:(void(^)(NSError*))completion {
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

- (BOOL) weightsHigh {
    if (!self.az){
        return NO;
    }
    return (self.az.floatValue > 180.0 && self.pierSide == CASMountPierSideWest) || (self.az.floatValue < 180.0 && self.pierSide == CASMountPierSideEast);
}

+ (NSSet*)keyPathsForValuesAffectingWeightsHigh {
    return [NSSet setWithArray:@[@"az",@"pierSide"]];
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

- (NSNumber*) ha {
    return nil;
}

- (NSArray<NSString*>*)movingRateValues {
    return nil;
}

- (CASNova*) nova {
    if (!_nova){
        NSNumber* latitude = [[NSUserDefaults standardUserDefaults] objectForKey:@"SXIOSiteLatitude"]; // todo; using SXIO namespace defaults...
        NSNumber* longitude = [[NSUserDefaults standardUserDefaults] objectForKey:@"SXIOSiteLongitude"];
        if (latitude && longitude){
            _nova = [[CASNova alloc] initWithObserverLatitude:latitude.doubleValue longitude:longitude.doubleValue];
        }
    }
    return _nova;
}
- (NSNumber*) secondsUntilTransit {
    
    NSNumber* result;
    
    NSNumber* ra = self.ra;
    NSNumber* dec = self.dec;    
    if (ra && dec){
        
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

- (BOOL)horizonCheckRA:(double)ra dec:(double)dec
{
    if (!self.nova){
        return false;
    }
    const CASAltAz altaz = [self.nova objectAltAzFromRA:ra dec:dec];
    return (altaz.alt > 0);
}

- (void)startSlewToRA:(double)ra dec:(double)dec completion:(void (^)(CASMountSlewError,CASMountSlewObserver*))completion {
    
    NSParameterAssert(completion);
    
    if (![self horizonCheckRA:ra dec:dec]){
        NSLog(@"Target ra: %f dec %f is below the local horizon",ra,dec);
        completion(CASMountSlewErrorInvalidLocation,nil);
        return;
    }
    
    __weak __typeof__(self) weakSelf = self;
    
    // set commanded ra and dec then issue slew command
    [self setTargetRA:ra dec:dec completion:^(CASMountSlewError error) {
        if (error){
            completion(error,nil);
        }
        else {
            weakSelf.targetRa = @(ra);
            weakSelf.targetDec = @(dec);
            [weakSelf startSlewToTarget:completion];
        }
    }];
}

- (void)startSlewToTarget:(void (^)(CASMountSlewError,CASMountSlewObserver*))completion {
    NSAssert(NO, @"Not implemented");
}

- (void)park {
    NSAssert(NO, @"Not implemented");
}

- (void)unpark {
    NSAssert(NO, @"Not implemented");
}

- (void)gotoHomePosition:(void (^)(CASMountSlewError,CASMountSlewObserver*))completion {
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

- (void)fullSyncToRA:(double)ra dec:(double)dec completion:(void (^)(CASMountSlewError))completion {
    [self syncToRA:ra dec:dec completion:completion];
}

- (CASDeviceType)type {
    return kCASDeviceTypeMount;
}

- (NSString*)uniqueID {
    return [NSString stringWithFormat:@"%@.%ld",self.deviceName,_mountID];
}

@end

@interface CASMountSlewObserver ()
@property (strong) CASMount* mount;
@end

@implementation CASMountSlewObserver {
    BOOL _observing:1;
}

static void* kvoContext;

+ (instancetype)observerWithMount:(CASMount*)mount
{
    CASMountSlewObserver* observer = [[CASMountSlewObserver alloc] init];
    observer.mount = mount;
    return observer;
}

- (void)dealloc
{
    if (_observing){
        _observing = NO;
        [self.mount removeObserver:self forKeyPath:@"slewing" context:&kvoContext];
    }
}

- (void)setCompletion:(void (^)(NSError *))completion
{
    _completion = [completion copy];
    if (_completion && !_observing){
        [self.mount addObserver:self forKeyPath:@"slewing" options:NSKeyValueObservingOptionInitial context:&kvoContext];
        _observing = YES; // set this *after* this call returns otherwise calls to -removeObserver: throws
    }
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if (context == &kvoContext) {
        if ([@"slewing" isEqualToString:keyPath] && object == self.mount){
            if (!self.mount.slewing){
                if (_observing){
                    _observing = NO;
                    [self.mount removeObserver:self forKeyPath:@"slewing" context:&kvoContext];
                }
                if (self.completion){
                    self.completion(nil);
                    self.completion = nil;
                }
            }
        }
    }
}

@end

//
//  CASMount.h
//  ieq-test
//
//  Created by Simon Taylor on 1/26/14.
//  Copyright (c) 2014 Simon Taylor. All rights reserved.
//

#import "CASDevice.h"

@class CASMount;

@interface CASMountSlewObserver : NSObject
@property (copy,nonatomic) void (^completion)(NSError*);
+ (instancetype)observerWithMount:(CASMount*)mount;
@end

@protocol CASMount // <CASDevice>

- (void)connect:(void(^)(NSError*))completion;
- (void)disconnect;

@property (nonatomic,readonly) BOOL connected;
@property (nonatomic,readonly) BOOL slewing;
@property (nonatomic,readonly) BOOL tracking;
@property (nonatomic,readonly) BOOL weightsHigh;

@property (nonatomic,strong,readonly) NSNumber* ra;
@property (nonatomic,strong,readonly) NSNumber* dec;
@property (nonatomic,strong,readonly) NSNumber* targetRa;
@property (nonatomic,strong,readonly) NSNumber* targetDec;
@property (nonatomic,strong,readonly) NSNumber* alt;
@property (nonatomic,strong,readonly) NSNumber* az;
@property (nonatomic,strong,readonly) NSNumber* ha;

@property (nonatomic,readonly) NSNumber* secondsUntilTransit;

typedef NS_ENUM(NSInteger, CASMountMode) {
    CASMountModeEQ,
    CASMountModeAltAz
};
@property (nonatomic,readonly) CASMountMode mode;

typedef NS_ENUM(NSInteger, CASMountSlewError) {
    CASMountSlewErrorNone,
    CASMountSlewErrorInvalidRA,
    CASMountSlewErrorInvalidDec,
    CASMountSlewErrorInvalidLocation,
    CASMountSlewErrorInvalidState
};
- (BOOL)horizonCheckRA:(double)ra dec:(double)dec;
- (void)startSlewToRA:(double)ra dec:(double)dec completion:(void (^)(CASMountSlewError,CASMountSlewObserver*))completion;
- (void)startSlewToTarget:(void (^)(CASMountSlewError,CASMountSlewObserver*))completion; // for subclasses
- (void)halt;

typedef NS_ENUM(NSInteger, CASMountDirection) {
    CASMountDirectionNone,
    CASMountDirectionNorth,
    CASMountDirectionEast,
    CASMountDirectionSouth,
    CASMountDirectionWest
};

@property (nonatomic,readonly) CASMountDirection direction;
- (void)startMoving:(CASMountDirection)direction;
- (void)stopMoving;
- (void)stopTracking;
- (void)stopSlewing;
- (BOOL)pulseInDirection:(CASMountDirection)direction ms:(NSInteger)ms;

- (void)syncToRA:(double)ra dec:(double)dec completion:(void (^)(CASMountSlewError))completion; // -> calibrate
- (void)fullSyncToRA:(double)ra dec:(double)dec completion:(void (^)(CASMountSlewError))completion; // -> sync

- (void)setTargetRA:(double)ra dec:(double)dec completion:(void(^)(CASMountSlewError))completion;

- (void)park:(void (^)(CASMountSlewError,CASMountSlewObserver*))completion;
- (void)unpark;
- (void)gotoHomePosition:(void (^)(CASMountSlewError,CASMountSlewObserver*))completion;

typedef NS_ENUM(NSInteger, CASMountPierSide) {
    CASMountPierSideEast = 1,
    CASMountPierSideWest = 2
};
@property (nonatomic,readonly) CASMountPierSide pierSide;

@optional

- (BOOL)parkToPosition:(NSInteger)parkPosition completion:(void (^)(CASMountSlewError,CASMountSlewObserver*))completion;

@end

@interface CASMount : CASDevice<CASMount>

@property (nonatomic,strong) NSNumber* targetRa;
@property (nonatomic,strong) NSNumber* targetDec;

@end

extern NSString* const CASMountSlewingNotification;
extern NSString* const CASMountFlippedNotification;

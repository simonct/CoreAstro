//
//  CASMount.h
//  ieq-test
//
//  Created by Simon Taylor on 1/26/14.
//  Copyright (c) 2014 Simon Taylor. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol CASMount

- (void)connectWithCompletion:(void(^)(NSError*))completion;
- (void)disconnect;

@property (nonatomic,readonly) BOOL connected;
@property (nonatomic,readonly) BOOL slewing;

@property (nonatomic,strong,readonly) NSNumber* ra;
@property (nonatomic,strong,readonly) NSNumber* dec;
@property (nonatomic,strong,readonly) NSNumber* targetRa;
@property (nonatomic,strong,readonly) NSNumber* targetDec;
@property (nonatomic,strong,readonly) NSNumber* alt;
@property (nonatomic,strong,readonly) NSNumber* az;

typedef NS_ENUM(NSInteger, CASMountMode) {
    CASMountModeEQ,
    CASMountModeAltAz
};
@property (nonatomic,readonly) CASMountMode mode;

typedef NS_ENUM(NSInteger, CASMountSlewError) {
    CASMountSlewErrorNone,
    CASMountSlewErrorInvalidRA,
    CASMountSlewErrorInvalidDec,
    CASMountSlewErrorInvalidLocation
};
- (void)startSlewToRA:(double)ra dec:(double)dec completion:(void (^)(CASMountSlewError))completion;
- (void)halt;

typedef NS_ENUM(NSInteger, CASMountDirection) {
    CASMountDirectionNone,
    CASMountDirectionNorth,
    CASMountDirectionEast,
    CASMountDirectionSouth,
    CASMountDirectionWest
};

@optional

@property (nonatomic,readonly) CASMountDirection direction;
- (void)startMoving:(CASMountDirection)direction;
- (void)stopMoving;
- (void)pulseInDirection:(CASMountDirection)direction ms:(NSInteger)ms;

- (void)syncToRA:(double)ra dec:(double)dec completion:(void (^)(CASMountSlewError))completion;

- (void)setTargetRA:(double)ra dec:(double)dec completion:(void(^)(CASMountSlewError))completion;

- (void)park;
- (void)unpark;
- (void)gotoHomePosition;

@end

@interface CASMount : NSObject<CASMount> // todo CASDevice subclass
@end

// CASMount < CASLX200Mount (defines command set + serial connection) < CASIEQMount (defines command variations)
// or mount is simply a composite of transport and command set ?
// or is this just over-abstracting ? although things like slewing look pretty common
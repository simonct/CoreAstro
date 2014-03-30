//
//  iEQMount.h
//  ieq-test
//
//  Created by Simon Taylor on 1/26/14.
//  Copyright (c) 2014 Simon Taylor. All rights reserved.
//

#import "CASMount.h"
#import "ORSSerialPort.h"

@interface iEQMount : CASMount

@property (nonatomic,readonly) BOOL connected;
@property (nonatomic,readonly) BOOL slewing;

// todo; expose the actual values, display formatting is a differet job
@property (nonatomic,strong,readonly) NSNumber* ra;
@property (nonatomic,strong,readonly) NSNumber* dec;
@property (nonatomic,strong,readonly) NSNumber* alt;
@property (nonatomic,strong,readonly) NSNumber* az;

@property (nonatomic,copy,readonly) NSString* name;

- (id)initWithSerialPort:(ORSSerialPort*)port;

- (void)connectWithCompletion:(void(^)(void))completion;
- (void)disconnect;

typedef NS_ENUM(NSInteger, iEQMountSlewError) {
    iEQMountSlewErrorNone,
    iEQMountSlewErrorInvalidRA,
    iEQMountSlewErrorInvalidDec,
    iEQMountSlewErrorInvalidLocation
};
- (void)startSlewToRA:(double)ra dec:(double)dec completion:(void (^)(iEQMountSlewError))completion;
- (void)halt;

typedef NS_ENUM(NSInteger, iEQMountTrackingRate) {
    iEQMountTrackingSiderealRate,
    iEQMountTrackingLunarRate,
    iEQMountTrackingSolarRate,
    iEQMountTrackingKingRate,
    iEQMountTrackingCustomRate
};

@end

@interface iEQMount (iEQSpecific)

- (void)dumpInfo;

typedef NS_ENUM(NSInteger, iEQMountDirection) {
    iEQMountDirectionNone,
    iEQMountDirectionNorth,
    iEQMountDirectionEast,
    iEQMountDirectionSouth,
    iEQMountDirectionWest
};
@property (nonatomic,readonly) iEQMountDirection direction;
- (void)startMoving:(iEQMountDirection)direction;
- (void)stopMoving;
- (void)pulseInDirection:(iEQMountDirection)direction ms:(NSInteger)ms;

@property (nonatomic,assign) NSInteger slewRate;

@end
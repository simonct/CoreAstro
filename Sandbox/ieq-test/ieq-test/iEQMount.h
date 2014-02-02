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
@property (nonatomic,readonly) NSNumber* ra;
@property (nonatomic,readonly) NSNumber* dec;

- (id)initWithSerialPort:(ORSSerialPort*)port;

- (void)connectWithCompletion:(void(^)(void))completion;
- (void)disconnect;

- (void)startSlewToRA:(double)ra dec:(double)dec completion:(void (^)(BOOL))completion;
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

@property (nonatomic,assign) NSInteger slewRate;

@end
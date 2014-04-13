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

@property (nonatomic,copy,readonly) NSString* name;

- (id)initWithSerialPort:(ORSSerialPort*)port;

- (void)connectWithCompletion:(void(^)(void))completion;
- (void)disconnect;

@end

@interface iEQMount (iEQSpecific)

typedef NS_ENUM(NSInteger, iEQMountTrackingRate) {
    iEQMountTrackingSiderealRate,
    iEQMountTrackingLunarRate,
    iEQMountTrackingSolarRate,
    iEQMountTrackingKingRate,
    iEQMountTrackingCustomRate
};

- (void)dumpInfo;

@property (nonatomic,assign) NSInteger slewRate;

@end
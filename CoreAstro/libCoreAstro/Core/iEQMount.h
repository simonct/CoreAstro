//
//  iEQMount.h
//  ieq-test
//
//  Created by Simon Taylor on 1/26/14.
//  Copyright (c) 2014 Simon Taylor. All rights reserved.
//

#import "CASLX200Mount.h"

@interface iEQMount : CASLX200Mount
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

@property (nonatomic) NSInteger movingRate;

@end